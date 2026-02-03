#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"
STUB="$ROOT/src/components/AlertsBanner.jsx"

echo "== 1) Crear/reescribir stub de AlertsBanner (no pinta nada) =="
mkdir -p "$ROOT/src/components"
tee "$STUB" >/dev/null <<'JSX'
import React from "react";
/** AlertsBanner (stub): no renderiza nada. Mantiene compat sin romper el UI. */
export default function AlertsBanner(){ return null; }
JSX

echo "== 2) Reinsertar import en App.jsx si falta (no dañará si no se usa) =="
grep -q 'import AlertsBanner from "./components/AlertsBanner.jsx";' "$APP" || \
  sed -i '1i import AlertsBanner from "./components/AlertsBanner.jsx";' "$APP"

echo "== 3) (Opcional) Comprobar si hay otros archivos que usan <AlertsBanner .../> =="
# Si existiesen, este stub también los cubre al build time, no hace falta tocar nada más.
grep -RIn "<AlertsBanner" "$ROOT/src" || echo "No hay más usos explícitos de <AlertsBanner .../>"

echo "== 4) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Listo: AlertsBanner (stub) disponible. No muestra banner y evita el runtime error."
