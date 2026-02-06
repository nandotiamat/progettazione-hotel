#cloud-config
package_update: false
package_upgrade: false

# Fix MTU immediately on boot for ALL interfaces
bootcmd:
  - [ sh, -c, "for dev in $(ls /sys/class/net/ | grep -v lo); do ip link set dev $dev mtu 1400; done" ]

# Write the installation script
write_files:
  - path: /opt/install_nginx.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -e

      # Update manually now that MTU is fixed
      apt-get update
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

# Run the script
runcmd:
  - [ bash, /opt/install_nginx.sh ]
