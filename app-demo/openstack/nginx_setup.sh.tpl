#cloud-config
package_update: true
package_upgrade: false

# 1. Nuclear Option: Disable Cloud-Init Network Config to prevent overrides
network:
  config: disabled

# 2. Write Static Netplan Config with Force MTU 1400
write_files:
  - path: /etc/netplan/01-netcfg.yaml
    permissions: '0600'
    content: |
      network:
        version: 2
        ethernets:
          ens3:
            match:
              name: ens3
            dhcp4: true
            dhcp4-overrides:
              use-mtu: false
            mtu: 1400
            nameservers:
              addresses: [8.8.8.8, 8.8.4.4]

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
