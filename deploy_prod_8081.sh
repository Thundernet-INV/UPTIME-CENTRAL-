#!/bin/sh
set -eu

APP_DIR=$(pwd)
DOCROOT="/var/www/uptime8081/dist"
SITE_CONF="/etc/nginx/sites-available/uptime8081.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/uptime8081.conf"
SERVER_IP="10.10.31.31"
PORT="8081"

echo "=============================================="
echo " 🚀 INICIANDO DEPLOY A PRODUCCIÓN (puerto $PORT)"
echo "=============================================="

echo "== 1) Construyendo proyecto =="
npm ci >/dev/null 2>&1 || npm i
npm run build

echo "== 2) Copiando dist/ a $DOCROOT =="
sudo mkdir -p "$DOCROOT"
sudo rsync -av --delete "$APP_DIR/dist/" "$DOCROOT/"

echo "== 3) Escribiendo configuración Nginx =="
sudo tee "$SITE_CONF" >/dev/null <<NGX
server {
    listen $PORT;
    server_name $SERVER_IP;

    root $DOCROOT;
    index index.html;

    # HTML fresco - sin caché
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        expires -1;
        try_files \$uri =404;
    }

    # Enrutamiento SPA
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Assets con caché largo (hash)
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, max-age=31536000, immutable";
        try_files \$uri =404;
    }
}
NGX

echo "== 4) Activando site en Nginx =="
sudo ln -sf "$SITE_CONF" "$SITE_ENABLED"

echo "== 5) Probando Nginx =="
sudo nginx -t

echo "== 6) Recargando Nginx =="
sudo systemctl reload nginx

echo ""
echo "======================================================"
echo " ✔ PROYECTO LEVANTADO EN PRODUCCIÓN"
echo "     👉 http://$SERVER_IP:$PORT/"
echo "======================================================"
