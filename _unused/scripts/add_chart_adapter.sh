#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
ADP="$ROOT/src/chartAdapter.js"
APP="$ROOT/src/App.jsx"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$ADP" ] && cp "$ADP" "$ADP.bak_$ts" || true

cat > "$ADP" <<'JS'
import History from './historyEngine';

// Adaptador para series de "promedio por sede"
export async function getInstanceAvgXY(instance, minutes=15) {
  const arr = await History.getAvgSeriesByInstance(instance, minutes*60*1000);
  // Aseguramos pares [x,y] en segundos y un objeto 'dataset' con llaves comunes
  const xy = (arr || []).map(p => [p.x ?? p.ts, (p.y ?? (p.ms/1000) ?? p.sec ?? 0)]);
  const ds = (arr || []).map(p => ({
    x: p.x ?? p.ts,
    y: p.y ?? ((p.ms ?? p.avgMs) / 1000) ?? p.sec ?? 0,
    ms: p.ms ?? p.avgMs ?? (p.y*1000) ?? null,
  }));
  // Exponer para depuración rápida
  try { if (typeof window !== 'undefined') window.__chartData = { xy, ds, len: ds.length }; } catch {}
  console.log('[ADAPTER] getInstanceAvgXY', instance, '->', ds.length, 'points');
  return { xy, ds };
}
JS

# Aseguramos que App.jsx cargue el adaptador (por side-effect expone window.__chartData)
grep -q "from \"./chartAdapter\"" "$APP" || \
  sed -i '1i import * as ChartAdapter from "./chartAdapter";' "$APP"

cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx
echo "✓ ChartAdapter disponible como window.__chartData y via import ChartAdapter"
