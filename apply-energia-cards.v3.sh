#!/bin/bash
# apply-energia-cards.v3.sh
# -------------------------------------------------------------------
# Qué hace (TODO EN UNO):
#  1) Implementa la pantalla **Energía** con 4 cards: AVR / PLANTAS /
#     CORPOELEC / INVERSOR, mostrando: total, UP/DOWN y SLA (uptime).
#     Al hacer click, navega a #/energia/<categoria> y abre detalle
#     con lista UP/DOWN y (si existe) gráficas vía MultiServiceView.jsx.
#  2) Asegura el **routing real**: cuando el hash es #/energia o
#     #/energia/<slug>, Dashboard.jsx **retorna** la vista de Energía.
#  3) Ajusta el link de navegación "Energía" para que apunte a #/energia.
#  4) Crea backups con timestamp y reinicia Vite (limpiando caché).
#
# Ejecuta este script desde la raíz del frontend (donde está la carpeta src/).
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
CSS_FILE="$VIEWS_DIR/energia-cards-v3.css"

TS="$(date +%Y%m%d_%H%M%S)"

log(){  echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){   echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

need_file(){
  local f="$1"
  if [ ! -f "$f" ]; then
    err "No existe: $f"
    exit 1
  fi
}

backup(){
  local f="$1"
  local b="${f}.backup.${TS}"
  cp "$f" "$b"
  ok "Backup: $b"
}

# -------------------------------------------------------------------
# 0) Pre-chequeos
# -------------------------------------------------------------------
need_file "$DASHBOARD_FILE"
if [ -f "$ENERGIA_FILE" ]; then
  backup "$ENERGIA_FILE"
fi
backup "$DASHBOARD_FILE"

# -------------------------------------------------------------------
# 1) Helpers de métricas y categorización
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

// Categorización por TAG principal
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
# 2) Vista principal (cards estilo instancias): AVR/PLANTAS/CORPOELEC/INVERSOR
# -------------------------------------------------------------------
cat > "$OVERVIEW_FILE" <<'EOF'
// src/views/EnergiaOverviewCards.jsx
import React from 'react';
import { belongsToInstance, categoryOf, CATEGORY_LABEL, computeMetrics } from './Energia.metrics.helpers.js';
import './energia-cards-v3.css';

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
          const slug = c; // avr|corpoelec|plantas|inversor
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
# 3) Detalle por categoría (lista UP/DOWN + gráficas si MultiServiceView existe)
# -------------------------------------------------------------------
cat > "$DETAIL_FILE" <<'EOF'
// src/views/EnergiaCategoryDetail.jsx
import React, { useMemo } from 'react';
import { belongsToInstance, categoryOf, CATEGORY_LABEL, computeMetrics, getStatus } from './Energia.metrics.helpers.js';
import './energia-cards-v3.css';

let MultiServiceView = null;
try {
  // Carga condicional si existe en el proyecto
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
# 4) CSS siguiendo el estilo de cards de instancias (clases nuevas)
# -------------------------------------------------------------------
cat > "$CSS_FILE" <<'EOF'
/* src/views/energia-cards-v3.css */
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
# 5) Contenedor Energia.jsx que orquesta overview/detalle
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
ok "Energia.jsx escrito: $ENERGIA_FILE"

# -------------------------------------------------------------------
# 6) WIRING DURO en Dashboard.jsx:
#     - Importa Energia desde ./Energia.jsx
#     - Si hash empieza por #/energia, retorna <Energia monitorsAll={monitors} />
#     - Asegura que el link/navegación 'Energía' apunte a #/energia
# -------------------------------------------------------------------
TMP_DASH="${DASHBOARD_FILE}.tmp.${TS}"

# a) Insertar import default de Energia si no existe
if ! grep -Eq 'import[[:space:]]+Energia[[:space:]]+from[[:space:]]*([\"\x27])\./Energia\.jsx\1' "$DASHBOARD_FILE"; then
  FIRST_IMPORT_LINE=$(awk '/^import[[:space:]]/ {print NR; exit}' "$DASHBOARD_FILE" || true)
  if [ -n "${FIRST_IMPORT_LINE:-}" ]; then
    awk -v n="$((FIRST_IMPORT_LINE))" '
      NR==n { print; print "import Energia from \"./Energia.jsx\";" ; next } { print }
    ' "$DASHBOARD_FILE" > "$TMP_DASH" && mv "$TMP_DASH" "$DASHBOARD_FILE"
    ok "Import default de Energia insertado en Dashboard.jsx"
  else
    { echo 'import Energia from "./Energia.jsx";'; cat "$DASHBOARD_FILE"; } > "$TMP_DASH" && mv "$TMP_DASH" "$DASHBOARD_FILE"
    ok "Import default de Energia añadido al inicio de Dashboard.jsx"
  fi
else
  ok "Dashboard.jsx ya importaba Energia (default)"
fi

# b) Inyectar gate de render (si hash es #/energia ...) al inicio del componente
#    Intentamos detectar la declaración del componente principal.
inject_gate(){
  local file="$1"
  local marker="__ENERGIA_GATE_INSERTED__"
  if grep -q "$marker" "$file"; then
    ok "Gate de Energía ya estaba insertado"
    return
  fi

  # Encontrar la línea donde comienza el cuerpo de la función principal
  local line_num
  line_num=$(awk '
    /export[[:space:]]+default[[:space:]]+function[[:space:]]+Dashboard[[:space:]]*\(/ {print NR; exit}
    /function[[:space:]]+Dashboard[[:space:]]*\(/ {print NR; exit}
    /const[[:space:]]+Dashboard[[:space:]]*=[[:space:]]*\(/ {print NR; exit}
  ' "$file")

  if [ -n "$line_num" ]; then
    # Insertamos justo después de esa línea (asumiendo { en la misma o siguiente)
    # Buscamos la primera llave de apertura '{' después de la declaración y metemos el gate tras esa llave.
    local body_start
    body_start=$(awk -v start="$line_num" 'NR>=start{ if(index($0,"{")){print NR; exit} }' "$file")
    if [ -z "$body_start" ]; then
      warn "No pude ubicar la llave de apertura del componente; inserto gate en la línea siguiente a la declaración."
      body_start="$line_num"
    fi

    awk -v ins_line="$body_start" '
      NR==ins_line {
        print $0
        print "  // " "'"$marker"'"
        print "  try {"
        print "    const h = window.location.hash || \"\";"
        print "    if (h.startsWith(\"#/energia\")) {"
        print "      return <Energia monitorsAll={typeof monitors !== \"undefined\" ? monitors : (typeof props !== \"undefined\" ? (props.monitorsAll || props.monitors) : undefined)} />;"
        print "    }"
        print "  } catch (e) {}"
        next
      }
      { print }
    ' "$file" > "$TMP_DASH" && mv "$TMP_DASH" "$file"
    ok "Gate de Energía inyectado en Dashboard.jsx"
  else
    warn "No se detectó la función Dashboard; no pude inyectar el gate automáticamente."
  fi
}

inject_gate "$DASHBOARD_FILE"

# c) Asegurar que el link/tab de navegación a 'Energía' apunte a #/energia
#    Sustituye href existentes que contengan 'Energia' o 'Energía' por el hash correcto.
sed -E -i \
  "s#(href=)[\"\x27][^\"\x27]*([Ee]nergia|[Ee]nergía)[^\"\x27]*[\"\x27]#\1\"#/energia\"#g" \
  "$DASHBOARD_FILE" || true
ok "Link de navegación a Energía apuntando a #/energia (si existía)"

# -------------------------------------------------------------------
# 7) Limpiar caché y reiniciar Vite
# -------------------------------------------------------------------
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Listo. Entra a la pestaña 'Energía' o visita #/energia para ver las 4 cards (AVR/PLANTAS/CORPOELEC/INVERSOR) y su detalle con UP/DOWN y SLA."
echo "Backups: Dashboard.jsx.backup.${TS} y (si existía) Energia.jsx.backup.${TS}"
