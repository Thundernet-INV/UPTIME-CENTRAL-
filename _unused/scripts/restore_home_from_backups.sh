#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
SG="$ROOT/src/components/ServiceGrid.jsx"
MT="$ROOT/src/components/MonitorsTable.jsx"

echo "== Buscar backups de ServiceGrid.jsx y MonitorsTable.jsx =="
SG_BAKS=$(ls -1t "$SG".bak_* 2>/dev/null || true)
MT_BAKS=$(ls -1t "$MT".bak_* 2>/dev/null || true)

pick_backup() {
  target="$1"    # ruta actual del componente
  list="$2"      # lista de backups (ordenados por fecha)
  what="$3"      # etiqueta para logs

  if [ -z "$list" ]; then
    echo "⚠ No hay backups para $what"
    return 1
  fi

  # Heurística: elegimos el primer backup que tenga alguno de estos tokens de estilo dinámico.
  TOKENS='service-card__head|status-badge|monitor-card|service-card__badge|monitor-card__head'
  for f in $list; do
    if grep -Eq "$TOKENS" "$f"; then
      echo "→ Restaurando $what desde: $f"
      cp "$f" "$target"
      return 0
    fi
  done

  # Si no hubo match, tomamos el backup más reciente para al menos revertir cambios
  FIRST=$(printf "%s\n" $list | head -1)
  echo "→ Restaurando $what con el backup más reciente (sin token): $FIRST"
  cp "$FIRST" "$target"
  return 0
}

REST_SG=0
REST_MT=0

pick_backup "$SG" "$SG_BAKS" "ServiceGrid.jsx" && REST_SG=1 || true
pick_backup "$MT" "$MT_BAKS" "MonitorsTable.jsx" && REST_MT=1 || true

if [ "$REST_SG" -eq 0 ] && [ "$REST_MT" -eq 0 ]; then
  echo "⚠ No se restauró ningún archivo porque no se hallaron backups. Saliendo sin cambios."
  exit 0
fi

echo "== Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx
echo "✓ Home restaurado al estilo original (clases y colores dinámicos)."
