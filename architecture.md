# Ansible Pi Cluster - Architecture & Documentation
# =================================================

## 🏗️ System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    RASPBERRY PI CLUSTER                       │
│              (4 Nodes: 1 Controller + 3 Workers)               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                        NETWORK LAYER                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │ LOAD BALANCER│───▶│  PI-HOLE     │───▶│   DNS SERVER  │   │
│  │ (Port 53)    │    │ (Ad-blocking)│    │ (Cluster.local)│  │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    MONITORING STACK                           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  PROMETHEUS  │◀──▶│ NODE EXPORTER│◀──▶│  BLACKBOX    │   │
│  │ (Port 9090)  │    │ (Port 9100)  │    │  EXPORTER    │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
│         │                    │                   │           │
│         ▼                    ▼                   ▼           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   GRAFANA    │◀──▶│  TSDB        │◀──▶│  ALERTMANAGER│   │
│  │ (Port 3000)  │    │ (Time Series)│    └──────────────┘   │
│  └──────────────┘    └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    JOB PROCESSING                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   REDIS      │◀──▶│  CELERY      │◀──▶│  WORKERS     │   │
│  │ (Job Queue)  │    │  Worker      │    │  (Port 5000)  │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    SHARED STORAGE                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │ NFS SERVER   │◀──▶│  BACKUP      │◀──▶│  MONITORING  │   │
│  │ (Port 2049)  │    │  System      │    │  Scripts      │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Component Breakdown

### Node Roles & Responsibilities

| Role | IP Address | Primary Function |
|------|------------|------------------|
| **Controller** | rk01.local | Monitoring hub, orchestration, DNS load balancer |
| **Storage Controller** | rk01.local | NFS server, shared storage management |
| **Worker-1** | rpi02.local | Job processing + Pi-hole integration |
| **Worker-2** | rpi03.local | Pure compute job processing |
| **Worker-3** | rpi04.local | Pure compute job processing |

### Service Ports Reference

| Port | Protocol | Service | Description |
|------|----------|---------|-------------|
| 53 | TCP/UDP | BIND9 | DNS queries (load balancer) |
| 80/443 | HTTP/HTTPS | Web services | Load balancer termination |
| 22 | TCP | SSH | Secure remote access |
| 2049 | NFS | Network File System | Shared storage |
| 6379 | TCP | Redis | Job queue management |
| 81 | HTTP | Pi-hole API | Ad-blocking control |
| 9090 | HTTP | Prometheus | Metrics collection |
| 3000 | HTTP | Grafana | Visualization dashboard |

## 🚀 Deployment Phases

### Phase 1: Base Installation (All Nodes)
- Common role → System hardening, SSH config, UFW firewall
- Network configuration, hostname setup

### Phase 2: Role-Specific Configuration
- Controller → Monitoring stack installation
- Workers → Job processing utilities
- Storage → NFS/ZFS configuration
- Pi-hole → Ad blocking setup
- Load Balancer → DNS server configuration

### Phase 3: Integration & Verification
- Service health checks
- Cross-node communication tests
- Failover scenario testing

## 📁 Project Structure

```
ansible-pi-cluster-opencode/
├── deploy.sh                    # Main deployment script
├── inventory.ini                # Node definitions
├── README.md                    # This documentation
└── roles/
    ├── common/                  # Base configuration for all nodes
    │   ├── tasks/main.yml
    │   └── templates/
    ├── controller/              # Monitoring stack (Prometheus, Grafana)
    │   ├── tasks/main.yml
    │   └── templates/
    ├── worker/                  # Job processing workers
    │   ├── tasks/main.yml
    │   └── templates/
    ├── storage-controller/      # Shared NFS storage server
    │   ├── tasks/main.yml
    │   └── templates/
    └── loadbalancer/            # DNS + Pi-hole integration
        ├── tasks/main.yml
        └── templates/
```

## 🔧 Quick Start Guide

### 1. Initial Setup (On Each Node)
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Ansible prerequisites
sudo apt install ansible python3-pip -y

# Clone this repository
git clone <repository-url>
cd ansible-pi-cluster-opencode

# Edit inventory.ini with your actual IP addresses
nano inventory.ini
```

### 2. Deploy All Roles
```bash
# Full deployment (default)
./deploy.sh

# Preview changes without applying
./deploy.sh --dry-run

# Deploy specific roles only
./deploy.sh --roles=common,controller
```

### 3. Verify Deployment
```bash
# Check all services are running
systemctl list-units --all | grep -E "prometheus|grafana|redis|bind9"

# Test DNS resolution
dig @rpi02.local cluster.local

# View Grafana dashboard
open http://rk01.local:3000  # Default credentials: admin/admin
```

## 📊 Monitoring & Maintenance

### Access Dashboards
- **Grafana**: `http://<controller-ip>:3000` (default: admin/admin)
- **Prometheus UI**: `http://<controller-ip>:9090`
- **Flower Worker Monitor**: `http://<worker-ip>:5555`

### Log Locations
| Service | Log File |
|---------|----------|
| Prometheus | `/var/log/prometheus/prometheus.log` |
| Grafana | `/var/log/grafana/grafana.log` |
| BIND9 | `/var/log/named/default.log` |
| Redis | `/var/log/redis/redis-server.log` |

### Backup Commands
```bash
# Full cluster backup
rsync -av /data/shared/ root@<backup-node>:/backups/

# Export Prometheus metrics
curl http://localhost:9090/api/v1/query_range?query=up&interval=5m > prometheus_export.json
```

## 🛠️ Troubleshooting

### Common Issues & Solutions

**Issue**: DNS not resolving cluster.local
```bash
# Check zone file exists
ls -la /var/lib/bind/cluster.local.zone

# Reload BIND9 configuration
sudo systemctl reload bind9

# Verify zone is loaded
named-checkzone cluster.local /var/lib/bind/cluster.local.zone
```

**Issue**: NFS exports not accessible
```bash
# Check export configuration
cat /etc/nfs/exports.conf

# Restart NFS service
sudo systemctl restart nfs-kernel-server

# Verify exports are active
showmount -e <storage-ip>
```

**Issue**: High memory usage on workers
```bash
# Check memory consumption
free -h
top -o %MEM

# Adjust Redis maxmemory in /etc/redis/redis-cluster.conf
sudo systemctl restart redis-server
```

## 📝 Configuration Reference

### Inventory Variables (inventory.ini)
| Variable | Default | Description |
|----------|---------|-------------|
| `controller_ip` | rk01.local | Monitoring hub address |
| `storage_controller_ip` | rk01.local | NFS server address |
| `pihole_ip` | rpi02.local | Pi-hole DNS server |
| `loadbalancer_ip` | rpi02.local | Front-end DNS load balancer |

### Role-Specific Variables

**Controller Role:**
- `grafana_admin_password`: Grafana admin password (default: 'admin')
- `prometheus_retention`: Data retention period (default: 15d)

**Worker Role:**
- `redis_password`: Redis authentication password (default: 'cluster_queue')
- `celery_worker_concurrency`: Number of concurrent tasks (default: 4)

**Storage Controller:**
- `nfs_export_path`: Shared data directory path (default: /data/shared)
- `backup_retention_days`: How many days to keep backups (default: 7)

## 🔒 Security Considerations

1. **SSH Key Authentication**: Disable password authentication after deployment
2. **Firewall Rules**: UFW configured with default deny policy
3. **Network Segmentation**: Internal cluster network only
4. **Regular Updates**: Automated security patches via apt
5. **Audit Logging**: All services log to centralized location

## 📈 Performance Tuning

### Recommended Settings
- **NFS**: Use ZFS for better I/O performance on SSD storage
- **Redis**: Set maxmemory-policy to 'allkeys-lru' for efficient caching
- **Prometheus**: Adjust scrape_interval based on hardware capabilities
- **Grafana**: Enable caching for dashboard queries

## 📚 Additional Resources

- [Ansible Documentation](https://docs.ansible.com/ansible/latest/)
- [Prometheus Official Docs](https://prometheus.io/docs/introduction/overview/)
- [BIND9 Configuration Guide](https://www.isc.org/bind/)
- [Celery Best Practices](https://docs.celeryq.dev/en/stable/getting-started/best-practices.html)