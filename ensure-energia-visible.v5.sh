#!/bin/bash
# ensure-energia-visible.v5.sh
# -------------------------------------------------------------------
# ¿Qué hace?
# 1) Crea/actualiza la vista ENERGÍA (4 cards: AVR/PLANTAS/CORPOELEC/INVERSOR)
#    + detalle por categoría (lista UP/DOWN y, si existe, gráficas).
# 2) Garantiza que **Dashboard.jsx** RENDERICE esa vista cuando el hash
#    sea "#/energia" o "#/energia/<slug>" (avr|corpoelec|plantas|inversor),
#    con un "gate" al INICIO del componente (early return).
# 3) Sanea imports duplicados (quita cualquier referencia a Energia.default.jsx)
#    y deja UN SOLO:  import Energia from "./Energia.jsx";
# 4) Fuerza que cualquier enlace que diga "Energia" o "Energía"
#    use href="#/energia".
# 5) Limpia caché de Vite y reinicia el dev server.
#
# Uso:
#   chmod +x ./ensure-energia-visible.v5.sh
#   ./ensure-energia-visible.v5.sh
# -------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$ROOT_DIR/src"
VIEWS_DIR="$SRC_DIR/views"

DASHBOARD_FILE="$VIEWS_DIR/Dashboard.jsx"
ENERGIA_FILE="$VIEWS_DIR/Energia.jsx"
HELPERS_FILE="$VIEWS_DIR/Energia.metrics.helpers.js"
OVERVIEW_FILE="$VIEWS_DIR/EnergiaOverviewCards.jsx"
DETAIL_FILE="$VIEWS_DIR/EnergiaCategoryDetail.jsx"
CSS_FILE="$VIEWS_DIR/energia-cards-v5.css"

TS="$(date +%Y%m%d_%H%M%S)"

log(){  echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){   echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

need(){
  local f="$1"
  if [ ! -f "$f" ]; then err "No existe: $f"; exit 1; fi
}
backup(){
  local f="$1"
  local b="${f}.backup.${TS}"
  cp "$f" "$b"
  ok "Backup: $b"
}

need "$DASHBOARD_FILE"
[ -f "$ENERGIA_FILE" ] && backup "$ENERGIA_FILE"
backup "$DASHBOARD_FILE"

# -------------------------------------------------------------------
# 1) Helpers de métricas/categorías (energía)
# -------------------------------------------------------------------
cat > "$HELPERS_FILE" <<'EOF'
// src/views/Energia.metrics.helpers.js
export const ONLY_INSTANCE = 'energia';

export function normalizeTags(m) {
  const arr = Array.isArray(m?.tags)
    ? m.tags
    : (typeof m?.tag === 'string' ? [m.tag] : []);
  return (arr || [])
    .filter(Boolean)
    .map(x => String(x).trim())
    .map(x => x.toUpperCase());
}

export function getStatus(m) {
  try {
    const raw =
      (m?.status ?? m?.state ?? (m?.online === true ? 'up' : (m?.online === false ? 'down' : undefined)) ?? (m?.up ? 'up' : undefined));
    const s = String(raw).toLowerCase();
    if (raw === true) return 'up';
    if (raw === false) return 'down';
    if (['up', 'online', 'ok', 'green'].includes(s)) return 'up';
    return 'down';
  } catch {
    return 'down';
  }
}

export function belongsToInstance(m) {
  try {
    const iname = (m?.instance ?? m?.instanceName ?? m?.service ?? '').toString().toLowerCase();
    if (iname === ONLY_INSTANCE) return true;
    const tags = normalizeTags(m);
    return tags.includes(ONLY_INSTANCE.toUpperCase());
  } catch {
    return false;
  }
}

export function categoryOf(m) {
  const tags = normalizeTags(m);
  const has = (x) => tags.includes(x);
  if (has('AVR')) return 'avr';
  if (has('PLANTAS') || has('PLANTAS AP') || has('PLANTAS_AP') || has('PLANTA')) return 'plantas';
  if (has('CORPOELEC')) return 'corpoelec';
  if (has('INVERSOR') || has('INVERTER')) return 'inversor';
  return 'otros';
}

export const CATEGORY_LABEL = {
  avr: 'AVR',
  plantas: 'PLANTAS',
  corpoelec: 'CORPOELEC',
  inversor: 'INVERSOR',
  otros: 'OTROS'
};

export function computeMetrics(items = []) {
  const total = items.length;
  let up = 0, down = 0;
  for (const m of items) {
    const s = getStatus(m);
    if (s === 'up') up++; else down++;
  }
  const uptime = total > 0 ? Math.round((up / total) * 100) : 0;
  return { total, up, down, uptime };
}
EOF
ok "Helpers creados: $HELPERS_FILE"

# -------------------------------------------------------------------
# 2) Overview (4 cards) estilo instancias
# -------------------------------------------------------------------
cat > "$OVERVIEW_FILE" <<'EOF'
// src/views/EnergiaOverviewCards.jsx
import React from 'react';
import { belongsToInstance, categoryOf, CATEGORY_LABEL, computeMetrics } from './Energia.metrics.helpers.js';
import './energia-cards-v5.css';

const ORDER = ['avr','corpoelec','plantas','inversor'];

function Badge({ down }) {
  if (down > 0) return <span className="badge danger">{down} DOWN</span>;
  return <span className="badge ok">Sin incidencias</span>;
}

export default function EnergiaOverviewCards({ items = [] }) {
  const filtered = (items || []).filter(belongsToInstance);
  const byCat = {};
  for (const m of filtered) {
    const c = categoryOf(m);
    if (!['avr','corpoelec','plantas','inversor'].includes(c)) continue;
    (byCat[c] ||= []).push(m);
  }
  const categories = ORDER.filter(c => Array.isArray(byCat[c]));

  return (
    <div className="instances-grid energia">
      {categories.map(c => {
        const metrics = computeMetrics(byCat[c]);
        const go = () => {
          const slug = c;
          const base = '#/energia';
          if (location.hash.startsWith(base)) {
            location.hash = `${base}/${slug}`;
          } else {
            location.hash = `${base}`;
            setTimeout(() => { location.hash = `${base}/${slug}`; }, 0);
          }
        };
        return (
          <div key={c}
               className="instance-card energia-card"
               onClick={go}
               role="button"
               tabIndex={0}
               onKeyDown={(e)=> (e.key==='Enter'||e.key===' ') && go()}>
            <div className="inst-head">
              <div className="inst-avatar">{CATEGORY_LABEL[c][0]}</div>
              <div className="inst-title">{CATEGORY_LABEL[c]}</div>
              <div className="inst-subtitle">Instancia: energía</div>
            </div>
            <div className="inst-body">
              <div className="inst-metric">{metrics.total} sensores · {metrics.up} UP · {metrics.down} DOWN</div>
              <div className="inst-uptime">Uptime estimado: <b>{metrics.uptime}%</b></div>
            </div>
            <div className="inst-footer">
              <Badge down={metrics.down} />
            </div>
          </div>
        );
      })}
    </div>
  );
}
EOF
ok "Overview creado: $OVERVIEW_FILE"

# -------------------------------------------------------------------
# 3) Detalle de categoría (lista y gráficas si existen)
# -------------------------------------------------------------------
cat > "$DETAIL_FILE" <<'EOF'
// src/views/EnergiaCategoryDetail.jsx
import React, { useMemo } from 'react';
import { belongsToInstance, categoryOf, CATEGORY_LABEL, computeMetrics, getStatus } from './Energia.metrics.helpers.js';
import './energia-cards-v5.css';

let MultiServiceView = null;
try {
  MultiServiceView = require('./MultiServiceView.jsx').default || null;
} catch (e) { /* noop */ }

export default function EnergiaCategoryDetail({ items = [], slug }) {
  const filtered = useMemo(() => {
    const base = (items || []).filter(belongsToInstance);
    return base.filter(m => categoryOf(m) === slug);
  }, [items, slug]);

  const metrics = computeMetrics(filtered);
  const goBack = () => { location.hash = '#/energia'; };

  return (
    <div className="energia-detail">
      <div className="detail-header">
        <button className="btn" onClick={goBack}>← Volver</button>
        <h2>{CATEGORY_LABEL[slug]} · <small>Instancia: energía</small></h2>
        <div className="detail-stats">{metrics.total} sensores · {metrics.up} UP · {metrics.down} DOWN · SLA: <b>{metrics.uptime}%</b></div>
      </div>

      {MultiServiceView ? (
        <div className="detail-charts">
          <MultiServiceView monitors={filtered} title={`${CATEGORY_LABEL[slug]} · Gráficas`} />
        </div>
      ) : null}

      <div className="detail-list">
        <ul>
          {filtered.map((m, i) => {
            const id = m?.id ?? m?.key ?? `${m?.name || 'item'}-${i}`;
            const label = m?.name || m?.displayName || m?.title || m?.host || String(id);
            const st = getStatus(m);
            return (
              <li key={id} className={`eq-item ${st}`}>
                <span className={`dot ${st}`} />
                <span className="label">{label}</span>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
EOF
ok "Detalle creado: $DETAIL_FILE"

# -------------------------------------------------------------------
# 4) CSS (estilo similar a cards de instancias)
# -------------------------------------------------------------------
cat > "$CSS_FILE" <<'EOF'
/* src/views/energia-cards-v5.css */
.instances-grid.energia {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 16px;
}
.instance-card.energia-card {
  background: #fff;
  border: 1px solid rgba(125,125,125,.2);
  border-radius: 14px;
  padding: 12px 14px;
  cursor: pointer;
  box-shadow: 0 10px 16px rgba(0,0,0,.04);
  transition: transform .08s ease, box-shadow .12s ease;
}
body.dark-mode .instance-card.energia-card{ background: rgba(17,20,26,.6); border-color:#374151; }
.instance-card.energia-card:hover{ transform: translateY(-2px); box-shadow: 0 12px 20px rgba(0,0,0,.08); }
.inst-head{ display:flex; align-items:center; gap:10px; margin-bottom:6px; }
.inst-avatar{ width:28px; height:28px; border-radius:50%; background:#eef2ff; color:#4f46e5; display:flex; align-items:center; justify-content:center; font-weight:700; }
.inst-title{ font-weight:700; }
.inst-subtitle{ margin-left:auto; font-size:.8rem; opacity:.8; }
.inst-body{ font-size:.95rem; margin:8px 0; }
.inst-footer{ margin-top:6px; }
.badge{ display:inline-block; padding:4px 8px; border-radius:10px; font-size:.78rem; font-weight:600; }
.badge.ok{ background:#d1fae5; color:#065f46; }
.badge.danger{ background:#fee2e2; color:#991b1b; }

.energia-detail .detail-header{ display:flex; align-items:center; gap:12px; margin-bottom:10px; }
.energia-detail .btn{ border:1px solid rgba(125,125,125,.3); background:transparent; padding:6px 10px; border-radius:8px; }
.energia-detail .detail-stats{ margin-left:auto; opacity:.9; }
.energia-detail .detail-charts{ margin:10px 0 16px; }
.energia-detail .detail-list ul{ list-style:none; margin:0; padding:0; }
.energia-detail .detail-list .eq-item{ display:flex; gap:8px; align-items:center; padding:8px 0; border-bottom:1px dashed rgba(125,125,125,.25); }
.energia-detail .dot{ width:10px; height:10px; border-radius:50%; display:inline-block; }
.energia-detail .dot.up{ background:#16a34a; box-shadow:0 0 0 2px rgba(22,163,74,.15); }
.energia-detail .dot.down{ background:#dc2626; box-shadow:0 0 0 2px rgba(220,38,38,.15); }
EOF
ok "CSS creado: $CSS_FILE"

# -------------------------------------------------------------------
# 5) Contenedor Energia.jsx
# -------------------------------------------------------------------
cat > "$ENERGIA_FILE" <<'EOF'
// src/views/Energia.jsx
import React, { useEffect, useMemo, useState } from 'react';
import EnergiaOverviewCards from './EnergiaOverviewCards.jsx';
import EnergiaCategoryDetail from './EnergiaCategoryDetail.jsx';

export default function Energia(props = {}) {
  const { monitorsAll, monitors, items, data } = props;
  const source = useMemo(() => (
    (Array.isArray(monitorsAll) && monitorsAll) ||
    (Array.isArray(monitors) && monitors) ||
    (Array.isArray(items) && items) ||
    (Array.isArray(data) && data) ||
    []
  ), [monitorsAll, monitors, items, data]);

  const [slug, setSlug] = useState(null);

  useEffect(() => {
    const base = '#/energia';
    const sync = () => {
      const h = (location.hash || '').toLowerCase();
      if (h.startsWith((base + '/').toLowerCase())) {
        const s = h.slice((base + '/').length).split(/[?#]/)[0].trim();
        setSlug(s || null);
      } else if (h === base.toLowerCase()) {
        setSlug(null);
      }
    };
    sync();
    window.addEventListener('hashchange', sync);
    return () => window.removeEventListener('hashchange', sync);
  }, []);

  if (slug && ['avr','corpoelec','plantas','inversor'].includes(slug)) {
    return <EnergiaCategoryDetail items={source} slug={slug} />;
  }
  return <EnergiaOverviewCards items={source} />;
}
EOF
ok "Energia.jsx actualizado"

# -------------------------------------------------------------------
# 6) Saneado de imports y GATE robusto en Dashboard.jsx
# -------------------------------------------------------------------

# 6a) Eliminar cualquier import de Energia.default.jsx
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'\''"]\.[\.\/]*Energia\.default\.jsx["'\''"][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"

# 6b) Eliminar TODOS los imports de Energia desde Energia.jsx (para reinsertar uno único limpio)
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'\''"]\.[\.\/]*Energia\.jsx["'\''"][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"
sed -E -i '/^[[:space:]]*import[[:space:]]*\{[[:space:]]*Energia[[:space:]]*\}[[:space:]]*from[[:space:]]*["'\''"]\.[\.\/]*Energia\.jsx["'\''"][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"

# 6c) Insertar UN SOLO import default de Energia
FIRST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {print NR; exit}' "$DASHBOARD_FILE" || true)"
if [ -n "${FIRST_IMPORT_LINE:-}" ]; then
  sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"./Energia.jsx\";" "$DASHBOARD_FILE" || \
  sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"../views/Energia.jsx\";" "$DASHBOARD_FILE"
else
  { echo 'import Energia from "./Energia.jsx";'; cat "$DASHBOARD_FILE"; } > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
fi
ok "Import único de Energia en Dashboard.jsx"

# 6d) Inyectar función isEnergiaRoute y EARLY RETURN una sola vez
if ! grep -q "__ENERGIA_GATE_V5__" "$DASHBOARD_FILE"; then
  # Insertar util isEnergiaRoute arriba del archivo (después de imports)
  LAST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {li=NR} END{print li+0}' "$DASHBOARD_FILE")"
  if [ "$LAST_IMPORT_LINE" -gt 0 ]; then
    sed -i "$((LAST_IMPORT_LINE+1))i \
const __ENERGIA_GATE_V5__ = true;\\n\
const isEnergiaRoute = () => {\\n\
  try {\\n\
    const h = (typeof window !== 'undefined' ? window.location.hash : '') || '';\\n\
    return /^#\\/energia(?:\\/(avr|corpoelec|plantas|inversor))?$/i.test(h);\\n\
  } catch { return false; }\\n\
};" "$DASHBOARD_FILE"
  fi

  # Localizar declaración del componente Dashboard
  LINE_DECL="$(awk '
    /export[[:space:]]+default[[:space:]]+function[[:space:]]+Dashboard[[:space:]]*\(/ {print NR; exit}
    /function[[:space:]]+Dashboard[[:space:]]*\(/ {print NR; exit}
    /const[[:space:]]+Dashboard[[:space:]]*=[[:space:]]*\(/ {print NR; exit}
  ' "$DASHBOARD_FILE")"

  if [ -n "$LINE_DECL" ]; then
    BODY_START="$(awk -v s="$LINE_DECL" 'NR>=s { if (index($0,"{")) {print NR; exit} }' "$DASHBOARD_FILE")"
    [ -z "$BODY_START" ] && BODY_START="$LINE_DECL"

    awk -v ins="$BODY_START" '
      NR==ins {
        print $0
        print "  // EARLY RETURN para ruta de Energía"
        print "  if (typeof isEnergiaRoute === \"function\" && isEnergiaRoute()) {"
        print "    // monitors puede llamarse diferente en tu archivo; intentamos con varias props"
        print "    const cand = (typeof monitors !== \"undefined\" ? monitors : (typeof props !== \"undefined\" ? (props.monitorsAll || props.monitors || []) : []));"
        print "    console.debug(\"[ENERGIA] Ruta detectada. Renderizando <Energia> (v5)\");"
        print "    return <Energia monitorsAll={cand} />;"
        print "  }"
        next
      }
      { print }
    ' "$DASHBOARD_FILE" > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
    ok "Gate de Energía insertado (early return) en Dashboard.jsx"
  else
    warn "No pude detectar la función Dashboard; omito gate."
  fi
else
  ok "Gate v5 ya presente; no se duplica"
fi

# 6e) Forzar que cualquier link visible a Energía use href="#/energia"
sed -E -i "s#(href=)[\"'][^\"']*([Ee]nergia|[Ee]nergía)[^\"']*[\"']#\\1\"#/energia\"#g" "$DASHBOARD_FILE" || true

# -------------------------------------------------------------------
# 7) Reiniciar Vite
# -------------------------------------------------------------------
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Listo. Abre/recarga la app y navega a #/energia (o haz clic en 'Energía'). Deberías ver las 4 cards y el detalle al hacer clic."
echo "Si algo falla, revierte con los backups: Dashboard.jsx.backup.${TS} y (si existía) Energia.jsx.backup.${TS}"
