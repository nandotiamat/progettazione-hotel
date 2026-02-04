# Infrastructure Testing Guide

This document outlines how to validate the deployed OpenStack infrastructure.
**Note:** Due to the use of the minimal `cirros-0.6.3-x86_64-disk` image, these tests focus on **Infrastructure Connectivity** (Network, Security Groups, Routing) rather than Application Functionality, as the application packages (Nginx, Postgres, Python) cannot be installed on CirrOS.

## 1. Retrieve Connection Details

First, get the IP addresses assigned by Terraform:

```bash
cd app-demo/openstack
terraform output
```

You should see output similar to:
*   `gateway_public_ip`: X.X.X.X (Public Floating IP)
*   `db_internal_ip`: 192.168.1.X
*   `app_internal_ips`: [192.168.1.Y, 192.168.1.Z]

## 2. Verify Public Access (SSH)

Test connectivity from your local machine to the **Gateway Node**.

*   **User:** `cirros`
*   **Password:** `cubswin:)`

```bash
ssh cirros@<GATEWAY_PUBLIC_IP>
```

**Success Criteria:**
*   You successfully log in and see the CirrOS shell prompt (`$`).
*   **Validates:** Public Router, Floating IP association, and the `sg_ssh` Security Group.

## 3. Verify Internal Connectivity

From the **Gateway Node's SSH session**, verify it can reach the other internal nodes on the private network.

### Test Database Node Reachability
```bash
ping -c 4 <DB_INTERNAL_IP>
```

### Test App Node Reachability
```bash
ping -c 4 <APP_INTERNAL_IP_1>
```

**Success Criteria:**
*   Pings receive responses (0% packet loss).
*   **Validates:** The private network `hotel-net` and the `sg_internal` Security Group (which allows internal traffic).

## 4. Why Application Tests Will Fail

If you attempt to access the web application, it will fail:

```bash
curl http://<GATEWAY_PUBLIC_IP>
# Output: curl: (7) Failed to connect to <IP> port 80: Connection refused
```

**Reason:**
*   The `cirros` image is a micro-OS (~15MB) used only for testing OpenStack clouds.
*   It does **not** support `apt-get`, so `nginx`, `postgresql`, and `python` were **not installed** despite being defined in the `user_data` scripts.
*   To enable the application, you must switch the `image_name` variable in `variables.tf` to a full `ubuntu-22.04` image when available in your cloud.
