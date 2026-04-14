# Ansible Pi Cluster Deployment

> A modular, production-ready deployment system for a 4-node Raspberry Pi cluster with integrated monitoring, job processing, shared storage, and DNS load balancing.

## 🎯 Features

- **Modular Architecture**: Add/remove services by deploying specific roles
- **Production-Ready**: Hardened security configurations out of the box
- **Monitoring Stack**: Prometheus + Grafana for comprehensive observability
- **Job Processing**: Redis-backed Celery workers with Flower monitoring
- **Shared Storage**: NFS server with automated backups
- **DNS Load Balancing**: BIND9 with Pi-hole integration
- **Easy Extensibility**: Simple role-based architecture for adding new services

## 📋 Prerequisites

- Raspberry Pi OS (Raspbian) on all 4 nodes
- SSH access to each node
- Network connectivity between all nodes
- Ansible installed on the controller machine

## 🚀 Quick Start

### 1. Clone and Configure

```bash
git clone <repository-url>
cd ansible-pi-cluster-opencode

# Edit inventory.ini with your actual IP addresses
nano inventory.ini
```

### 2. Deploy the Cluster

```bash
# Full deployment (all roles)
./deploy.sh

# Preview changes first
./deploy.sh --dry-run

# Deploy specific roles only
./deploy.sh --roles=common,controller
```

## 🏗️ Architecture

The cluster consists of:

- **1 Controller Node**: Monitoring hub, orchestration center
- **3 Worker Nodes**: Job processing compute nodes
- **Shared Storage**: NFS-backed shared filesystem
- **DNS Load Balancer**: BIND9 with Pi-hole integration

See `architecture.md` for detailed diagrams and component breakdown.

## 📁 Project Structure

```
ansible-pi-cluster-opencode/
├── deploy.sh                    # Main deployment script
├── inventory.ini                # Node definitions (edit this!)
├── architecture.md              # Detailed documentation
└── roles/
    ├── common/                  # Base configuration for all nodes
    │   └── tasks/main.yml
    ├── controller/              # Monitoring stack (Prometheus, Grafana)
    │   └── tasks/main.yml
    ├── worker/                  # Job processing workers
    │   └── tasks/main.yml
    ├── storage-controller/      # Shared NFS storage server
    │   └── tasks/main.yml
    └── loadbalancer/            # DNS + Pi-hole integration
        └── tasks/main.yml
```

## 📖 Documentation

- **README.md** (this file) - Quick start guide
- **architecture.md** - Detailed system design and component breakdown

## 🔧 Configuration

### Edit `inventory.ini` to set your network topology:

```ini
[all:vars]
cluster_name="Raspberry-Pi-Cluster"
controller_ip=rk01.local
storage_controller_ip=rk01.local
pihole_ip=rpi02.local
loadbalancer_ip=rpi02.local
```

### Role-Specific Variables

Variables can be set in `inventory.ini` or role-specific variable files:

- **Controller**: `grafana_admin_password`, `prometheus_retention`
- **Worker**: `redis_password`, `celery_worker_concurrency`
- **Storage**: `nfs_export_path`, `backup_retention_days`

## 🛠️ Deployment Commands

| Command | Description |
|---------|-------------|
| `./deploy.sh` | Deploy all roles (default) |
| `./deploy.sh --dry-run` | Preview changes without applying |
| `./deploy.sh --roles=common,controller` | Deploy specific roles only |
| `./deploy.sh --skip-roles=worker` | Skip certain roles during deployment |

## 📊 Monitoring Access

After deployment:

- **Grafana Dashboard**: http://<controller-ip>:3000 (default: admin/admin)
- **Prometheus UI**: http://<controller-ip>:9090
- **Flower Worker Monitor**: http://<worker-ip>:5555

## 📝 License

MIT License - See LICENSE file for details.

## 👨‍💻 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request