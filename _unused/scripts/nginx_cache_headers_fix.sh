#!/bin/sh
set -eu
SERVER_IP="10.10.31.31"
DOCROOT="/var/www/uptime/dist"    # ajusta si tu root es otra ruta
CONF="/etc/nginx/sites-available/uptime.conf"
ENABLED="/etc/nginx/sites-enabled/uptime.conf"

sudo mkdir -p "$DOCROOT"

sudo tee "$CONF" >/dev/null <<NGX
server {
  listen 80;
  server_name $SERVER_IP;

  root $DOCROOT;
  index index.html;

  # Index SIEMPRE fresco
  location = /index.html {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    expires -1;
    try_files \$uri =404;
  }

  # App SPA
  location / {
    try_files \$uri \$uri/ /index.html;
  }

  # Assets hasheados: caché larga e inmutable
  location /assets/ {
    expires 1y;
    add_header Cache-Control "public, max-age=31536000, immutable";
    try_files \$uri =404;
  }
}
NGX

sudo ln -sf "$CONF" "$ENABLED"
sudo nginx -t && sudo systemctl reload nginx
echo "OK: cabeceras listas. Abre en incógnito o Ctrl+F5 para verlo."
