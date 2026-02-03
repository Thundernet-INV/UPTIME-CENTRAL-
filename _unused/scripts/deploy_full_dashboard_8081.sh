#!/bin/sh
set -eu

# Ruta del proyecto ACTUALIZADO
APP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

# Carpeta de producción
DOCROOT="/var/www/uptime8081/dist"

# Configuración NGINX
SITE_CONF="/etc/nginx/sites-available/uptime8081.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/uptime8081.conf"

SERVER_IP="10.10.31.31"
PORT="8081"

echo "=============================================="
echo "    🚀 DEPLOY DE UPTIME-DASHBOARD (8081)"
echo "=============================================="

echo "== 1) Entrando en carpeta del proyecto =="
cd "$APP_DIR"

echo "== 2) Instalando dependencias =="
npm ci >/dev/null 2>&1 || npm install

echo "== 3) Build de producción del frontend actualizado =="
npm run build

echo "== 4) Instalando build en $DOCROOT =="
sudo mkdir -p "$DOCROOT"
sudo rsync -av --delete "$APP_DIR/dist/" "$DOCROOT/"

echo "== 5) Creando configuración Nginx para producción =="
sudo tee "$SITE_CONF" >/dev/null <<NGX
server {
    listen $PORT;
    server_name $SERVER_IP;

    root $DOCROOT;
    index index.html;

    # HTML actualizado SIEMPRE
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        expires -1;
        try_files \$uri =404;
    }

    # Rutas SPA
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Assets con hash: caché permanente
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, max-age=31536000, immutable";
        try_files \$uri =404;
    }
}
NGX

echo "== 6) Activando NGINX =="
sudo ln -sf "$SITE_CONF" "$SITE_ENABLED"

echo "== 7) Probando configuración =="
sudo nginx -t

echo "== 8) Recargando NGINX =="
sudo systemctl reload nginx

echo ""
echo "========================================================"
echo " ✔ DEPLOY COMPLETADO"
echo " ✔ Dashboard listo en:  http://$SERVER_IP:$PORT/"
echo " ========================================================"
echo " Si no lo ves actualizado: presiona CTRL+F5 o abre incógnito."
echo " (Nginx usa HTML sin caché ahora)"
echo "========================================================"
