#!/bin/sh
set -eu

PORT="8081"
SERVER_IP="10.10.31.31"
DOCROOT="/var/www/uptime8081/dist"
CONF="/etc/nginx/sites-available/uptime8081.conf"
ENABLED="/etc/nginx/sites-enabled/uptime8081.conf"

# Cambia aquí si tu backend bueno está en otro puerto
BACKEND="${BACKEND:-http://10.10.31.31}"

echo "== Reescribiendo Nginx 8081 con default_server y proxy /api -> $BACKEND =="

sudo mkdir -p "$DOCROOT"

sudo tee "$CONF" >/dev/null <<NGX
server {
  listen $PORT default_server;
  server_name _;

  root $DOCROOT;
  index index.html;

  # HTML sin caché
  location = /index.html {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    expires -1;
    try_files \$uri =404;
  }

  # SPA (front)
  location / {
    try_files \$uri \$uri/ /index.html;
  }

  # API: pasar tal cual la ruta /api/...
  location ^~ /api/ {
    proxy_pass $BACKEND;  # <<-- SIN /api/ aquí: /api/summary -> /api/summary
    proxy_http_version 1.1;

    proxy_set_header Host              \$host;
    proxy_set_header X-Real-IP         \$remote_addr;
    proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;

    # No-cache para API
    add_header Cache-Control "no-store";
    expires off;
  }
}
NGX

sudo ln -sf "$CONF" "$ENABLED"
sudo nginx -t
sudo systemctl reload nginx

echo "== Probando /api/summary via 8081 =="
set +e
curl -sS "http://$SERVER_IP:$PORT/api/summary" | head -c 600; echo
set -e

echo "Listo. Si ves JSON arriba, el frontend ya podrá poblar datos. Si no, revisamos el backend."
