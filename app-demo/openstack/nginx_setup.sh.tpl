#cloud-config
package_update: true
package_upgrade: false

# 1. Early Boot: Write Netplan config to force MTU 1400 BEFORE network starts
bootcmd:
  - |
    cat <<EOF > /etc/netplan/99-hotel-mtu.yaml
    network:
      version: 2
      ethernets:
        ens3:
          match:
            name: ens3
          mtu: 1400
          dhcp4: true
        eth0:
          match:
            name: eth0
          mtu: 1400
          dhcp4: true
    EOF
  - chmod 600 /etc/netplan/99-hotel-mtu.yaml
  - netplan apply || true

# 2. Write the installation script (Standard Logic)
write_files:
  - path: /opt/install_nginx.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -e

      # Fallback: Double-check MTU
      IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
      if [ ! -z "$IFACE" ]; then
        ip link set dev "$IFACE" mtu 1400
      fi

      # Install Nginx
      apt-get install -y nginx

      # Create Web Root
      mkdir -p /var/www/html
      mkdir -p /var/www/html/media
      chown -R www-data:www-data /var/www/html
      chmod -R 755 /var/www/html

      # Write Nginx Config
      cat <<EOF > /etc/nginx/sites-available/default
      upstream backend {
      %{ for ip in app_ips ~}
        server ${ip}:8000;
      %{ endfor ~}
      }

      upstream auth {
        server ${auth_ip}:8080;
      }

      server {
          listen 80;
          server_name _;

          root /var/www/html;
          index index.html;

          # Frontend Static Files
          location / {
              try_files \$uri \$uri/ /index.html;
          }

          # API Backend
          location /api/ {
              proxy_pass http://backend;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          }

          # Auth Service
          location /auth/ {
              proxy_pass http://auth/;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          }

          # Media Storage (Local Fallback)
          location /media/ {
              alias /var/www/html/media/;
              autoindex on;
          }
      }
      EOF

      # Restart Nginx
      systemctl restart nginx

# 3. Run the script
runcmd:
  - [ bash, /opt/install_nginx.sh ]
