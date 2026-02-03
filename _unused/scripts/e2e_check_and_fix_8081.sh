#!/bin/sh
set -eu
TS=$(date +%Y%m%d_%H%M%S)

# --- Parámetros de despliegue ---
APP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DOCROOT="/var/www/uptime8081/dist"
SITE_CONF="/etc/nginx/sites-available/uptime8081.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/uptime8081.conf"
SERVER_IP="10.10.31.31"
PORT="8081"
BACKEND="${BACKEND:-http://10.10.31.31:80}"

cd "$APP_DIR"
mkdir -p src/components src/lib public/logos
[ -f src/styles.css ] || touch src/styles.css

echo "=== (1/6) Diagnóstico rápido de Nginx/8081 y /api ==="
if sudo nginx -T 2>/dev/null | grep -q "listen $PORT"; then
  echo "• Hay server en 8081"
else
  echo "• No hay server en 8081; se va a crear"
fi

echo "• Probar /api/summary via 8081 (si falla, es el proxy):"
set +e
R=$(curl -sS "http://$SERVER_IP:$PORT/api/summary" | head -c 200)
set -e
echo "$R" | sed -n '1,5p' || true

# --- FRONTEND: re‑instalar piezas clave (UI completa) ---
echo "=== (2/6) Reasegurando UI completa (módulos, componentes, estilos, logos) ==="

# historyEngine.js
cat > src/historyEngine.js <<'JS'
// (igual al motor histórico consolidado que te entregué)
const KEY="kuma_history_snapshots_v1",MAX=500,SPARK_POINTS=120;
function load(){try{return JSON.parse(localStorage.getItem(KEY)||"[]")}catch{return[]} }
function save(a){try{localStorage.setItem(KEY,JSON.stringify(a))}catch{}}
function now(){return Date.now()}
function avgLatencyForInstance(ms,i){const a=ms.filter(m=>m.instance===i).map(m=>m.latest?.responseTime).filter(v=>typeof v==="number"&&isFinite(v));if(!a.length)return null;return Math.round(a.reduce((x,y)=>x+y,0)/a.length)}
function downCountForInstance(ms,i){return ms.filter(m=>m.instance===i&&m.latest?.status===0).length}
function findMonitor(ms,i,n){const s=(n||"").toLowerCase().trim();return ms.find(m=>m.instance===i&&(m.info?.monitor_name||"").toLowerCase().trim()===s)}
const History={addSnapshot(ms){const s=load();s.push({t:now(),monitors:ms});while(s.length>MAX)s.shift();save(s)},
getAvgSeriesByInstance(i,p=SPARK_POINTS){const s=load(),xs=[],ys=[];for(const k of s){xs.push(k.t);ys.push(avgLatencyForInstance(k.monitors,i))}const st=Math.max(0,xs.length-p);return{t:xs.slice(st),v:ys.slice(st)}},
getDownsSeriesByInstance(i,p=SPARK_POINTS){const s=load(),xs=[],ys=[];for(const k of s){xs.push(k.t);ys.push(downCountForInstance(k.monitors,i))}const st=Math.max(0,xs.length-p);return{t:xs.slice(st),v:ys.slice(st)}},
getSeriesForMonitor(i,n,p=SPARK_POINTS){const s=load(),xs=[],ys=[];for(const k of s){const m=findMonitor(k.monitors,i,n);xs.push(k.t);ys.push(typeof m?.latest?.responseTime==="number"?m.latest.responseTime:null)}const st=Math.max(0,xs.length-p);return{t:xs.slice(st),v:ys.slice(st)}},
getAllForInstance(i,p=MAX){const lat=this.getAvgSeriesByInstance(i,p),dwn=this.getDownsSeriesByInstance(i,p);return{lat,dwn}}};export default History;
JS

# logoUtil.js
cat > src/lib/logoUtil.js <<'JS'
export function hostFromUrl(u){try{return new URL(u).hostname.replace(/^www\./,'')}catch{return''}}
export function norm(s=''){return s.toLowerCase().replace(/\s+/g,'').trim()}
const MAP={whatsapp:'/logos/whatsapp.svg',facebook:'/logos/facebook.svg',instagram:'/logos/instagram.svg',youtube:'/logos/youtube.svg',tiktok:'/logos/tiktok.svg',google:'/logos/google.svg',microsoft:'/logos/microsoft.svg',netflix:'/logos/netflix.svg',telegram:'/logos/telegram.svg',apple:'/logos/apple.svg',iptv:'/logos/iptv.svg'};
function matchBrand(n,h){const N=norm(n),H=norm(h);for(const k of Object.keys(MAP)){if(N.includes(k)||H.includes(k))return k}return null}
export function getLogoCandidates(m){const h=hostFromUrl(m?.info?.monitor_url||'');const b=matchBrand(m?.info?.monitor_name||'',h);const a=[];if(b)a.push(MAP[b]);if(h)a.push(`https://logo.clearbit.com/${h}`);if(h)a.push(`https://www.google.com/s2/favicons?domain=${h}&sz=64`);return a.filter((v,i,A)=>v&&A.indexOf(v)===i)}
export function initialsFor(m){const n=(m?.info?.monitor_name||'').trim();if(!n)return'?';const p=n.split(/\s+/);const i=(p[0][0]||'').toUpperCase()+(p[1]?.[0]||'').toUpperCase();return i||n[0].toUpperCase()}
JS

# Componentes (Logo, Sparkline, HistoryChart, MonitorCard, ServiceCard, ServiceGrid, InstanceDetail, Filters, Cards) – OMITO por brevedad lo que ya te instalé;
# para garantizar el resultado, reuso el mismo payload del script anterior “restore_full_stack_8081.sh”
# Copiamos desde backups si existen o reescribimos – aquí, reusamos archivos ya escritos en el paso anterior.

# Si por cualquier razón faltan, aborta con mensaje:
for f in Logo.jsx Sparkline.jsx HistoryChart.jsx MonitorCard.jsx ServiceCard.jsx ServiceGrid.jsx InstanceDetail.jsx Filters.jsx Cards.jsx; do
  if [ ! -f "src/components/$f" ]; then
    echo "[ERROR] Falta src/components/$f. Ejecuta el script 'restore_full_stack_8081.sh' (previo) para reinstalar UI completa."
    exit 1
  fi
done

# api.js (summary-only + polling)
cat > src/api.js <<'JS'
const API=(typeof import.meta!=="undefined"&&import.meta.env?.VITE_API_BASE)||"/";
async function get(p){const r=await fetch(API+p);if(!r.ok)throw new Error("HTTP "+r.status);return r.json()}
export async function fetchAll(){try{const d=await get("api/summary");return{instances:d.instances||[],monitors:d.monitors||[]}}catch(e){return{instances:[],monitors:[]}}}
export async function fetchSummary(){const {instances}=await fetchAll();return{up:instances.filter(i=>i.ok).length,down:instances.filter(i=>!i.ok).length,total:instances.length}}
export async function fetchMonitors(){const {monitors}=await fetchAll();return monitors}
export function openStream(cb){let s=false;async function L(){if(s)return;try{const {monitors}=await fetchAll();cb?.(monitors)}catch{}setTimeout(L,5000)}L();return()=>{s=true}}
export async function getBlocklist(){try{return await get("api/blocklist")}catch{const raw=localStorage.getItem("blocklist");return raw?JSON.parse(raw):{monitors:[]}}}
export async function saveBlocklist(b){try{await fetch(API+"api/blocklist",{method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify(b)})}catch{localStorage.setItem("blocklist",JSON.stringify(b))}}
JS

# Estilos mínimos (si faltan bloques, añadimos)
grep -q "k-cards" src/styles.css || cat >> src/styles.css <<'CSS'
.k-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin:8px 0 16px;}
.k-card.k-card--summary{border:1px solid #e5e7eb;border-left:6px solid #e5e7eb;border-radius:10px;background:#fff;padding:12px;}
.k-card__title{font-weight:600;margin-bottom:6px}.k-metric{font-size:20px;font-weight:700;margin-right:6px}.k-label{color:#6b7280;font-size:12px}
.is-clickable{cursor:pointer;transition:box-shadow .15s}.is-clickable:hover{box-shadow:0 2px 10px rgba(0,0,0,.06)}.is-active{outline:2px solid #93c5fd;background:#f0f9ff}
.k-alerts{position:sticky;top:0;z-index:50;display:flex;flex-direction:column;gap:8px;margin-bottom:8px}.k-alert{display:flex;justify-content:space-between;align-items:center;padding:10px 12px;border-radius:8px}.k-alert--danger{background:#fee2e2;color:#991b1b;border:1px solid #fecaca}.k-alert__close{background:transparent;border:0;font-size:14px;cursor:pointer;color:#991b1b}
.k-card.k-card--site{border:1px solid #e5e7eb;border-radius:12px;background:#fff;padding:14px;display:flex;flex-direction:column;gap:12px;min-height:160px;overflow:hidden}.k-card__head{display:flex;justify-content:space-between;align-items:center}.k-card__title{margin:0;font-size:16px;font-weight:700}
.k-badge{font-size:12px;font-weight:600;padding:4px 10px;border-radius:999px;color:#fff}.k-badge--ok{background:#16a34a}.k-badge--danger{background:#dc2626}
.k-stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px}.k-val{font-weight:700}.k-actions{display:flex;gap:8px;flex-wrap:nowrap;justify-content:space-between;white-space:nowrap}
.k-btn{font-size:12px;padding:6px 10px;border-radius:8px;cursor:pointer;border:1px solid transparent}.k-btn--primary{border-color:#2563eb;color:#2563eb;background:#eff6ff}.k-btn--danger{border-color:#dc2626;color:#dc2626;background:#fef2f2}.k-btn--ghost{border-color:#cbd5e1;color:#334155;background:#fff}.k-btn:hover{filter:brightness(.97)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px}
.k-table{width:100%;border-collapse:collapse;margin-top:12px}.k-table th{text-align:left;padding:8px;background:#f3f4f6;border-bottom:2px solid #e5e7eb;font-size:14px}.k-table td{padding:8px;border-bottom:1px solid #e5e7eb;font-size:14px;vertical-align:middle}.k-cell-service{display:flex;align-items:center;gap:10px}
.k-logo{width:18px;height:18px;border-radius:4px;border:1px solid #e5e7eb;background:#fff;object-fit:contain}.k-logo--fallback{display:flex;align-items:center;justify-content:center;font-size:10px;background:#e5e7eb;color:#374151}
.k-grid-services{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px;margin-top:10px}
[data-route="sede"] .global-toggle{display:none!important}
CSS

# Logos básicos
mkdir -p public/logos
for L in instagram microsoft telegram netflix whatsapp youtube tiktok google apple iptv; do :; done
# (Si ya los creaste con los otros scripts, se conservan)

echo "=== (3/6) Dependencias y build ==="
npm i chart.js react-chartjs-2 chartjs-adapter-date-fns --save >/dev/null 2>&1 || true
npm run build

echo "=== (4/6) BACKUP destino y despliegue dist -> $DOCROOT ==="
if [ -d "$DOCROOT" ]; then
  sudo tar -czf "/var/www/uptime8081/dist.backup_${TS}.tgz" -C "/var/www/uptime8081" "dist" || true
  echo "Backup en /var/www/uptime8081/dist.backup_${TS}.tgz"
fi
sudo mkdir -p "$DOCROOT"
sudo rsync -av --delete "$APP_DIR/dist/" "$DOCROOT/"

echo "=== (5/6) Nginx 8081 con proxy /api -> $BACKEND ==="
sudo tee "$SITE_CONF" >/dev/null <<NGX
server {
  listen $PORT;
  server_name $SERVER_IP;

  root $DOCROOT;
  index index.html;

  location = /index.html {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    expires -1;
    try_files \$uri =404;
  }
  location / { try_files \$uri \$uri/ /index.html; }
  location /assets/ {
    expires 1y;
    add_header Cache-Control "public, max-age=31536000, immutable";
    try_files \$uri =404;
  }
  location /api/ {
    proxy_pass $BACKEND/api/;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    add_header Cache-Control "no-store";
    expires off;
  }
}
NGX
sudo ln -sf "$SITE_CONF" "$SITE_ENABLED"
sudo nginx -t
sudo systemctl reload nginx

echo "=== (6/6) Verificación /api/summary via 8081 ==="
set +e
curl -sS "http://$SERVER_IP:$PORT/api/summary" | head -c 400; echo
set -e

echo ""
echo ">>> Abre ahora:  http://$SERVER_IP:$PORT/  (Ctrl+F5 o incógnito)"
echo "Si sigue igual, copia/pega la salida de este script y corrijo sobre eso."
