#!/bin/bash
# apply-energia-cards.sh
# -------------------------------------------------------------------
# Objetivo:
#  - En la pantalla "Energía" mostrar SOLO la instancia "energia".
#  - Renderizar **cards** separadas por categorías:
#       * AVR UP / AVR DOWN
#       * CORPOELEC UP / CORPOELEC DOWN
#       * PLANTAS AP DOWN  (si están UP también se muestra como "PLANTAS AP UP")
#  - Dentro de cada card, dividir los ítems por **etiquetas** (tags),
#    ya que cada etiqueta representa el origen/ubicación.
#
# Cómo lo hace:
#  1) Crea helpers para normalizar tags, detectar estado UP/DOWN y
#     agrupar por categorías y etiqueta.
#  2) Crea un componente presentacional `EnergiaCards.jsx`.
#  3) Reemplaza `src/views/Energia.jsx` por un contenedor simple que:
#       - Recibe datos (monitorsAll / monitors / items / data)
#       - Filtra a la instancia "energia"
#       - Renderiza <EnergiaCards items={...} />
#  4) Agrega estilos mínimos para cards y listas.
#  5) Limpia caché de Vite y reinicia el dev server.
#
# Seguro y reversible: hace backups con timestamp.
# -------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$ROOT_DIR/src"
VIEWS_DIR="$SRC_DIR/views"
STYLES_MAIN="$ROOT_DIR/src/styles.css"
ENERGIA_FILE="$VIEWS_DIR/Energia.jsx"
DASHBOARD_FILE="$VIEWS_DIR/Dashboard.jsx"
HELPERS_FILE="$VIEWS_DIR/Energia.cards.helpers.js"
CARDS_FILE="$VIEWS_DIR/EnergiaCards.jsx"
CSS_FILE="$VIEWS_DIR/energia-cards.css"
TS="$(date +%Y%m%d_%H%M%S)"

log(){  echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){   echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

ensure(){
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

ensure "$ENERGIA_FILE"
[ -f "$DASHBOARD_FILE" ] || warn "No se encontró Dashboard.jsx (continuo de todas formas)"

# 1) Helpers
cat > "$HELPERS_FILE" <<'EOF'
// src/views/Energia.cards.helpers.js
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
    // Detectores comunes de estado
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
  const status = getStatus(m); // 'up' | 'down'
  const has = (x) => tags.includes(x);

  if (has('AVR')) return `AVR ${status.toUpperCase()}`;
  if (has('CORPOELEC')) return `CORPOELEC ${status.toUpperCase()}`;
  if (has('PLANTAS AP') || has('PLANTAS_AP') || has('PLANTAS-AP') || has('PLANTAS')) {
    return status === 'down' ? 'PLANTAS AP DOWN' : 'PLANTAS AP UP';
  }
  return `OTROS ${status.toUpperCase()}`;
}

export function firstNonEnergiaTag(tags) {
  const t = (tags || []).filter(x => x !== 'ENERGIA');
  return t[0] || 'SIN_ETIQUETA';
}

export function groupByTag(items) {
  const g = {};
  for (const m of (items || [])) {
    const tag = firstNonEnergiaTag(normalizeTags(m));
    (g[tag] ||= []).push(m);
  }
  return g;
}

export const ORDER = [
  'AVR UP',
  'AVR DOWN',
  'CORPOELEC UP',
  'CORPOELEC DOWN',
  'PLANTAS AP DOWN',
  'PLANTAS AP UP',
  'OTROS UP',
  'OTROS DOWN'
];
EOF
ok "Creado helpers: $HELPERS_FILE"

# 2) Componente de cards
cat > "$CARDS_FILE" <<'EOF'
// src/views/EnergiaCards.jsx
import React from 'react';
import { belongsToInstance, categoryOf, groupByTag, ORDER, getStatus } from './Energia.cards.helpers.js';
import './energia-cards.css';

function StatusDot({ status }) {
  const st = (status || '').toLowerCase();
  const cls = st === 'up' ? 'dot up' : 'dot down';
  return <span className={cls} title={st.toUpperCase()} />;
}

export default function EnergiaCards({ items = [] }) {
  const filtered = (items || []).filter(belongsToInstance);

  // Bucket por categoría
  const buckets = {};
  for (const m of filtered) {
    const cat = categoryOf(m);
    (buckets[cat] ||= []).push(m);
  }

  // Ordenar categorías con ORDER y luego las desconocidas
  const categories = [
    ...ORDER.filter(k => Array.isArray(buckets[k]) && buckets[k].length > 0),
    ...Object.keys(buckets).filter(k => !ORDER.includes(k))
  ];

  if (categories.length === 0) {
    return <div className="energia-cards"><div className="empty">No hay datos para la instancia ENERGIA.</div></div>;
  }

  return (
    <div className="energia-cards">
      {categories.map(cat => {
        const byTag = groupByTag(buckets[cat]);
        return (
          <div key={cat} className="card">
            <div className="card-header">{cat}</div>
            <div className="card-body">
              {Object.entries(byTag).map(([tag, list]) => (
                <div key={tag} className="tag-block">
                  <div className="tag-title">{tag}</div>
                  <ul className="tag-list">
                    {list.map((m, i) => {
                      const id = m?.id ?? m?.key ?? `${m?.name || m?.displayName || 'item'}-${i}`;
                      const label = m?.name || m?.displayName || m?.title || m?.host || String(id);
                      const status = getStatus(m);
                      return (
                        <li key={id} className="item">
                          <StatusDot status={status} />
                          <span className="label">{label}</span>
                        </li>
                      );
                    })}
                  </ul>
                </div>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}
EOF
ok "Creado componente: $CARDS_FILE"

# 3) CSS para las cards
cat > "$CSS_FILE" <<'EOF'
/* src/views/energia-cards.css */
.energia-cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 16px;
  padding: 8px 0;
}
.energia-cards .card {
  border: 1px solid rgba(125,125,125,.25);
  border-radius: 12px;
  background: rgba(255,255,255,.04);
  overflow: hidden;
}
body.dark-mode .energia-cards .card {
  background: rgba(17,20,26,.6);
  border-color: #374151;
}
.energia-cards .card-header {
  font-weight: 700;
  padding: 12px 14px;
  border-bottom: 1px solid rgba(125,125,125,.25);
}
.energia-cards .card-body {
  padding: 10px 14px;
}
.energia-cards .tag-block + .tag-block {
  margin-top: 10px;
}
.energia-cards .tag-title {
  font-weight: 600;
  font-size: 0.9rem;
  opacity: 0.9;
  margin: 6px 0;
}
.energia-cards .tag-list {
  list-style: none;
  margin: 0;
  padding: 0;
}
.energia-cards .item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 0;
  border-bottom: 1px dashed rgba(125,125,125,.2);
}
.energia-cards .item:last-child {
  border-bottom: 0;
}
.energia-cards .dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
}
.energia-cards .dot.up {
  background: #16a34a; /* verde */
  box-shadow: 0 0 0 2px rgba(22,163,74,.2);
}
.energia-cards .dot.down {
  background: #dc2626; /* rojo */
  box-shadow: 0 0 0 2px rgba(220,38,38,.2);
}
.energia-cards .label {
  font-size: 0.95rem;
}
.energia-cards .empty {
  padding: 12px;
  opacity: .8;
}
EOF
ok "Creado estilos: $CSS_FILE"

# 4) Reemplazar Energia.jsx por un contenedor simple que renderiza las cards
backup "$ENERGIA_FILE"
cat > "$ENERGIA_FILE" <<'EOF'
// src/views/Energia.jsx
import React from 'react';
import EnergiaCards from './EnergiaCards.jsx';
import './energia-cards.css';

// Contenedor simple que acepta diferentes props de datos
// y muestra SOLO la instancia 'energia' en forma de cards.
export default function Energia(props = {}) {
  const { monitorsAll, monitors, items, data } = props;
  const source =
    (Array.isArray(monitorsAll) && monitorsAll) ||
    (Array.isArray(monitors) && monitors) ||
    (Array.isArray(items) && items) ||
    (Array.isArray(data) && data) ||
    [];

  return (
    <div className="energia-view">
      <EnergiaCards items={source} />
    </div>
  );
}
EOF
ok "Reescrito contenedor: $ENERGIA_FILE"

# 5) Asegurar que el estilo principal no choque (opcional, no obligatorio)
if [ -f "$STYLES_MAIN" ]; then
  # nada crítico que tocar; dejamos los estilos locales
  :
fi

# 6) Limpiar caché y reiniciar Vite
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Hecho. En 'Energía' ahora verás SOLO la instancia 'energia' en cards por categorías y etiquetas."
echo "Si quieres revertir, usa el backup: ${ENERGIA_FILE}.backup.${TS}"
