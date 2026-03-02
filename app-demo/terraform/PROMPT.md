# Role
You are a Senior DevOps Engineer. 

# Objective
Your goal is to translate the provided AWS Terraform scripts into an equivalent OpenStack Terraform configuration.

# Context & Source Environment
The original AWS Terraform scripts were designed, tested, and deployed on a local LocalStack installation. These scripts are the one you read initially while visiting this repository.

# Target Environment Constraints
The target OpenStack environment is heavily constrained. It runs in a nested virtualized environment with the following architecture and specifications:
* **Host:** Windows
* **Guest VM:** Linux (75GB Storage, 6 vCPU, 32GB RAM)
* **OpenStack Deployment:** DevStack installed locally inside the Linux Guest VM.

# DevStack Configuration
The DevStack environment is based on the `stable/2025.1` branch (https://opendev.org/openstack/devstack/src/branch/stable/2025.1/). 

It is deployed using the following `local.conf` configuration file. Pay close attention to the enabled components when writing the terraform code. 

```
[[local|localrc]]

ADMIN_PASSWORD=secret
DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD

# Host IP
HOST_IP=192.168.1.13

# Logging
LOGFILE=$DEST/logs/stack.sh.log
LOGDAYS=2
LOG_COLOR=False

# --- ASSICURAZIONE SULLA VITA ---
disable_service o-hm o-hk
disable_service etcd3

# Swift
SWIFT_HASH=66a3d6b56c1f479c8b4e70ab5c2000f5
SWIFT_REPLICAS=1
SWIFT_DATA_DIR=$DEST/data

# MTU (nested virtualization)
PUBLIC_BRIDGE_MTU=1450
GLOBAL_PHYSNET_MTU=1450

# =========================
# 🔧 REQUIRED FIX (OVN)
# =========================

# Neutron + OVN
enable_service neutron
enable_service ovn-northd
enable_service ovn-controller
enable_service ovn-metadata-agent

# =========================
# 📦 ENABLE SWIFT
# =========================
enable_service s-proxy s-object s-container s-account

# Optional: If you want the Swift UI in Horizon (Dashboard)
enable_service swift-dashboard

# =========================
# 📦 ENABLE OCTAVIA
# =========================

enable_plugin neutron https://opendev.org/openstack/neutron stable/2025.1
enable_plugin octavia https://opendev.org/openstack/octavia stable/2025.1
enable_plugin octavia-dashboard https://opendev.org/openstack/octavia-dashboard stable/2025.1
enable_plugin ovn-octavia-provider https://opendev.org/openstack/ovn-octavia-provider stable/2025.1

enable_service octavia o-api o-cw o-da
OCTAVIA_USE_AMPHORA_PROVIDER=False
OCTAVIA_CONTROLLER_WORKER_NETWORK_DRIVER=noop_driver
```
