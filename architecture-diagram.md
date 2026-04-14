# Ansible Pi Cluster - Architecture Diagram
# ===========================================

## Network Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EXTERNAL NETWORK                               │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │                    INTERNET                                     │   │
│  │              (8.8.8.8, 1.1.1.1 - Upstream DNS)                  │   │
│  └───────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LOAD BALANCER (rpi02.local)                       │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │  BIND9 DNS Server                                             │   │
│  │  ├─ Primary Zone: cluster.local                               │   │
│  │  ├─ Forwarders: Pi-hole (127.0.0.1) + Upstream               │   │
│  │  └─ Failover: Automatic retry to upstream servers             │   │
│  └───────────────────────────────────────────────────────────────┘   │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │  HTTPS Termination Layer                                       │   │
│  │  ├─ Port 443 → Internal services                              │   │
│  │  └─ SSL/TLS Offloading                                        │   │
│  └───────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
    ┌─────────────────────────┼─────────────────────────┐
    ▼                         ▼                         ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   CONTROLLER    │  │ STORAGE         │  │   WORKER-1      │
│   (rk01.local)│  │   SERVER        │  │   (rpi02.local)│
│                  │  │   (rk01.local)│  │                  │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ ┌───────────────┤  │ ┌───────────────┤  │ ┌───────────────┤
│ │ Monitoring Hub│  │ │ NFS Server    │  │ │ Job Processor  │
│ │ ┌───────────┐ │  │ │ Shared Data   │  │ │ + Pi-hole      │
│ │ │ Prometheus │  │ │ /data/shared   │  │ │ Integration    │
│ │ │ Grafana   │  │ │ /data/backup   │  │ │                 │
│ │ └───────────┘ │  │ └───────────────┘  │ │ Redis Queue    │
│ │ ┌───────────┐ │  │ ┌───────────────┐  │ │                │
│ │ │ Blackbox  │  │  │ │ ZFS Pool     │  │ │ Flower Monitor │
│ │ │ Exporter  │  │  │ │ /storage-pool│  │ │                 │
│ │ └───────────┘ │  │ │               │  │ └───────────────┘
│ └───────────────┘  │ └───────────────┘  │                  │
└────────────────────┴────────────────────┴──────────────────┘
    │                 │                     │
    ▼                 ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   WORKER-2      │  │   WORKER-3      │  │   REDIS         │
│   (rpi03.local)│  │   (rpi04.local)│  │   QUEUE         │
├─────────────────┤  ├─────────────────┤  │                  │
│ ┌───────────────┤  │ ┌───────────────┤  │ ┌───────────────┤
│ │ Job Processor │  │ │ Job Processor │  │ │ Celery Worker  │
│ │ + Node Exporter│  │ │ + Node Exporter│  │ │ (Port 6379)   │
│ └───────────────┘  │ └───────────────┘  │ │                 │
└────────────────────┴────────────────────┴ │ Max Memory: 256MB
                                            │ Policy: allkeys-lru
                                            └─────────────────┘
```

## Data Flow Diagrams

### DNS Resolution Flow

```
Client Request
      │
      ▼
┌───────────────────────┐
│  Load Balancer (53)   │◄───┐
│  ┌─────────────────┐  │    │
│  │ BIND9 DNS       │  │    │
│  ├─ Check cache    │  │    │
│  ├─ Query Pi-hole  │────┼──► Ad-blocking filter
│  ├─ Forward to     │    │
│  │   Upstream      │    │
│  └─ Failover       │    │
└─────────────────────┘    │
                           ▼
                    DNS Response
```

### Job Processing Flow

```
Job Submission
      │
      ▼
┌───────────────────────┐
│  Worker Node          │
│  ┌─────────────────┐  │
│  │ Celery Worker   │  │
│  ├─ Receive job    │  │
│  ├─ Execute task   │  │
│  └─ Store result   │──►
└─────────────────────┘    │
                           ▼
                    Redis Result Backend
```

### Shared Storage Flow

```
Write Operation
      │
      ▼
┌───────────────────────┐
│  NFS Server           │
│  ┌─────────────────┐  │
│  ├─ Write to ZFS   │  │
│  ├─ Sync to disk   │  │
│  └─ Update metadata │  │
└───────────────────────┘
      │
      ▼
┌───────────────────────┐
│  Backup System        │
│  ┌─────────────────┐  │
│  ├─ rsync to       │  │
│  │   backup dir    │  │
│  ├─ Rotate old     │  │
│  │   backups       │  │
│  └─ Keep N days    │  │
└───────────────────────┘
```

## Service Dependencies

```
                    ┌─────────────────┐
                    │   Common Role   │
                    │ (All Nodes)     │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Controller  │  │   Worker      │  │ Storage       │
│   Role        │  │   Role        │  │ Controller    │
└───────┬───────┘  └───────┬───────┘  └───────┬────────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ Prometheus     │  │ Redis         │  │ NFS Server    │
│ Grafana       │  │ Celery Worker │  │ ZFS Pool      │
│ Blackbox Exp. │  │ Flower        │  │ Backup System  │
└───────────────┘  └───────────────┘  └───────────────┘

                    ┌───────────────┐
                    │ Load Balancer │
                    │   Role        │
                    └───────┬───────┘
                            ▼
                    ┌───────────────┐
                    │ BIND9 DNS     │
                    │ Health Monitor│
                    └───────────────┘
```

## Port Allocation Table

| Port | Protocol | Service | Description |
|------|----------|---------|-------------|
| 22 | TCP | SSH | Secure remote access |
| 53 | TCP/UDP | BIND9 | DNS queries (load balancer) |
| 80/443 | HTTP/HTTPS | Web | Load balancer termination |
| 2049 | NFS | Network File System | Shared storage |
| 6379 | TCP | Redis | Job queue management |
| 81 | HTTP | Pi-hole API | Ad-blocking control |
| 9090 | HTTP | Prometheus | Metrics collection |
| 3000 | HTTP | Grafana | Visualization dashboard |
| 5555 | HTTP | Flower | Celery monitoring (optional) |

## Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                            │
├─────────────────────────────────────────────────────────────┤
│ 1. Network Layer                                            │
│    └── UFW Firewall (default deny)                          │
│    └── SSH Key Authentication Only                         │
│    └── Network Segmentation                                 │
├─────────────────────────────────────────────────────────────┤
│ 2. Host Layer                                               │
│    └── Minimal Package Installation                         │
│    └── Regular Security Updates                             │
│    └── File Integrity Monitoring                            │
├─────────────────────────────────────────────────────────────┤
│ 3. Application Layer                                        │
│    └── Service Isolation                                    │
│    └── Least Privilege Principle                            │
│    └── Audit Logging                                        │
└─────────────────────────────────────────────────────────────┘
```

## Monitoring Stack Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MONITORING STACK                           │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  Node        │    │ Blackbox     │    │ Alertmanager  │   │
│  │ Exporter     │    │ Exporter     │    │ (Optional)    │   │
│  │ :9100        │    │ :9115        │    │                │   │
│  └──────┬───────┘    └──────┬───────┘    └────────────────┘   │
│         │                   │                                  │
│         ▼                   ▼                                  │
│  ┌──────────────┐    ┌──────────────┐                         │
│  │ Prometheus   │◀──▶│ TSDB Storage │                         │
│  │ :9090        │    │              │                         │
│  └──────┬───────┘    └──────────────┘                         │
│         │                                                     │
│         ▼                                                     │
│  ┌──────────────┐    ┌──────────────┐                        │
│  │ Grafana      │◀──▶│ Alert Rules  │                        │
│  │ :3000        │    │              │                        │
│  └──────────────┘    └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Phases

```
Phase 1: Base Installation (All Nodes)
├─ Common Role
│  ├─ SSH Configuration
│  ├─ Firewall Setup (UFW)
│  └─ System Hardening

Phase 2: Role-Specific Configuration
├─ Controller → Monitoring Stack
├─ Workers → Job Processing
├─ Storage → NFS/ZFS Setup
└─ Load Balancer → DNS + Pi-hole

Phase 3: Integration & Verification
├─ Service Health Checks
├─ Cross-Node Communication Tests
└─ Failover Scenario Testing
```

## Configuration Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    DEFAULT VALUES                            │
│  (Defined in role templates)                                │
├─────────────────────────────────────────────────────────────┤
│                    ROLE VARIABLES                            │
│  (Set in inventory.ini or role-specific files)              │
├─────────────────────────────────────────────────────────────┤
│                    COMMAND LINE OVERRIDES                    │
│  (--roles, --skip-roles, etc.)                              │
└─────────────────────────────────────────────────────────────┘
```

## Recovery Procedures

### Single Node Failure
1. Identify failed node via monitoring alerts
2. Reboot or replace hardware
3. Ansible will reconfigure on next deployment
4. Services auto-recover with failover

### Complete Cluster Reset
```bash
# Backup current configuration
tar -czf cluster-backup-$(date +%Y%m%d).tar.gz \
    /etc/bind/ /etc/nfs/ /opt/monitoring/

# Reboot all nodes
# for ip in 192.168.1.{5,10,20,30,31,32}; do
#     ssh root@$ip "sudo reboot"
# done
for name in rpi0{02,03,04}.local; do
    ssh root@$ip "sudo reboot"
done
ssh root@rk01.local "sudo reboot"
```

### Disaster Recovery
```bash
# Restore from backup
tar -xzf cluster-backup-YYYYMMDD.tar.gz \
    --directory=/

# Re-run deployment
./deploy.sh
```

---

*Generated by Ansible Pi Cluster Deployment System*
