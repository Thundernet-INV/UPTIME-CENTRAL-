#!/bin/bash
# apply-energia-cards.v2.sh
# -------------------------------------------------------------------
# Objetivo:
#  - En la pantalla "Energía" mostrar SOLO la instancia "energia".
#  - Vista principal: 4 cards (AVR / PLANTAS / CORPOELEC / INVERSOR)
#    con estilo similar a las cards de instancias: cantidad de sensores,
#    conteo UP/DOWN, uptime estimado (SLA) y badge de estado.
#  - Al hacer click en una card, navegar a un detalle que lista los
#    equipos de esa categoría y (si existe MultiServiceView.jsx) muestra
#    sus gráficas.
#  - Navegación basada en hash: "#/energia/<slug>".
#  - No altera tu router principal; sólo reemplaza/actualiza Energia.jsx
#    y añade componentes auxiliares + CSS, dejando backups.
# -------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$ROOT_DIR/src"
VIEWS_DIR="$SRC_DIR/views"
STYLES_MAIN="$SRC_DIR/styles.css"
ENERGIA_FILE="$VIEWS_DIR/Energia.jsx"
DASHBOARD_FILE="$VIEWS_DIR/Dashboard.jsx"
HELPERS_FILE="$VIEWS_DIR/Energia.metrics.helpers.js"
OVERVIEW_FILE="$VIEWS_DIR/EnergiaOverviewCards.jsx"
DETAIL_FILE="$VIEWS_DIR/EnergiaCategoryDetail.jsx"
CSS_FILE="$VIEWS_DIR/energia-cards-v2.css"
TS="$(date +%Y%m%d_%H%M%S)"

log(){  echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){   echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

ensure(){ local f="$1"; if [ ! -f "$f" ]; then err "No existe: $f"; exit 1; fi }
backup(){ local f="$1"; local b="${f}.backup.${TS}"; cp "$f" "$b"; ok "Backup: $b"; }

ensure "$ENERGIA_FILE"
[ -f "$DASHBOARD_FILE" ] || warn "No se encontró Dashboard.jsx; continuo de todas formas."

# 1) Helpers de métricas y categorización
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

# 2) Componente de vista principal (cards)
cat > "$OVERVIEW_FILE" <<'EOF'
// src/views/EnergiaOverviewCards.jsx
import React from 'react';
import { belongsToInstance, categoryOf, CATEGORY_LABEL, computeMetrics } from './Energia.metrics.helpers.js';
import './energia-cards-v2.css';

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
    if (!['avr','corpoelec','plantas','inversor'].includes(c)) continue; // sólo 4 categorías pedidas
    (byCat[c] ||= []).push(m);
  }

  const categories = ORDER.filter(c => Array.isArray(byCat[c]));

  return (
    <div className="instances-grid energia">
      {categories.map(c => {
        const metrics = computeMetrics(byCat[c]);
        const go = () => {
          const slug = c; // avr|corpoelec|plantas|inversor
          const base = '#/energia';
          if (location.hash.startsWith(base)) {
            location.hash = `${base}/${slug}`;
          } else {
            location.hash = `${base}`; setTimeout(() => { location.hash = `${base}/${slug}`; }, 0);
          }
        };
        return (
          <div key={c} className="instance-card energia-card" onClick={go} role="button" tabIndex={0}
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
ok "Vista principal creada: $OVERVIEW_FILE"

# 3) Detalle por categoría (lista + charts si está MultiServiceView)
cat > "$DETAIL_FILE" <<'EOF'
// src/views/EnergiaCategoryDetail.jsx
import React, { useMemo } from 'react';
import { belongsToInstance, categoryOf, CATEGORY_LABEL, computeMetrics, getStatus } from './Energia.metrics.helpers.js';
import './energia-cards-v2.css';

let MultiServiceView = null;
try {
  // Carga condicional (si existe el archivo en el proyecto)
  MultiServiceView = require('./MultiServiceView.jsx').default || null;
} catch (e) { /* opcional */ }

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
ok "Detalle por categoría creado: $DETAIL_FILE"

# 4) CSS que intenta seguir el estilo de las cards de instancias
cat > "$CSS_FILE" <<'EOF'
/* src/views/energia-cards-v2.css */
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

# 5) Reescribir Energia.jsx para orquestar overview/detalle
backup "$ENERGIA_FILE"
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
      const h = location.hash || '';
      if (h.startsWith(base + '/')) {
        const s = h.slice((base + '/').length).split(/[?#]/)[0].trim();
        setSlug(s || null);
      } else if (h === base) {
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

# 6) Limpiar caché y reiniciar Vite
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Listo. Vista de energía con 4 cards (AVR/PLANTAS/CORPOELEC/INVERSOR) y detalle navegable por hash. Backups creados con sufijo .backup.${TS}"

