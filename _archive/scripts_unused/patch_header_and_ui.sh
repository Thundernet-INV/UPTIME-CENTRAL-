#!/bin/sh
# Parchea el header para mostrar totales de MONITORES (UP/DOWN/Total/Prom) según filtro
# y hace los cuadros clicables para aplicar filtro de estado (up/down/all).
# Además, añade estilos para mejorar cards y evitar desbordes.
# Uso:
#   chmod +x ./patch_header_and_ui.sh
#   ./patch_header_and_ui.sh
#   npm run dev

set -eu

TS=$(date +%Y%m%d%H%M%S)

need() { [ -f "$1" ] || { echo "[ERROR] Falta $1" >&2; exit 1; }; }

echo "== Validando entorno =="
need package.json
need src/App.jsx

CARDS_DIR="src/components"
mkdir -p "$CARDS_DIR"

###############################################################################
# 1) Reemplazar/crear src/components/Cards.jsx (header interactivo)
###############################################################################
CARDS="$CARDS_DIR/Cards.jsx"
if [ -f "$CARDS" ]; then
  cp "$CARDS" "$CARDS.bak.$TS"
  echo "[backup] $CARDS -> $CARDS.bak.$TS"
fi

cat > "$CARDS" <<'JSX'
// src/components/Cards.jsx
import React from "react";

export default function Cards({ counts, status, onSetStatus }) {
  const { up = 0, down = 0, total = 0, avgMs = null } = counts ?? {};

  const Box = ({ title, value, color, active, onClick, subtitle }) => (
    <button
      type="button"
      className={`k-card k-card--summary is-clickable ${active ? "is-active" : ""}`}
      style={{ borderLeftColor: color }}
      onClick={onClick}
    >
      <div className="k-card__title">{title}</div>
      <div className="k-card__content">
        <span className="k-metric">{value}</span>
        {subtitle ? <span className="k-label" style={{marginLeft:8}}>{subtitle}</span> : null}
      </div>
    </button>
  );

  return (
    <div className="k-cards">
      <Box
        title="UP"
        value={up}
        color="#16a34a"
        active={status === "up"}
        onClick={() => onSetStatus(status === "up" ? "all" : "up")}
        subtitle="monitores"
      />
      <Box
        title="DOWN"
        value={down}
        color="#dc2626"
        active={status === "down"}
        onClick={() => onSetStatus(status === "down" ? "all" : "down")}
        subtitle="monitores"
      />
      <Box
        title="Total"
        value={total}
        color="#3b82f6"
        active={status === "all"}
        onClick={() => onSetStatus("all")}
        subtitle="monitores"
      />
      <div className="k-card k-card--summary" style={{ borderLeftColor: "#6366f1" }}>
        <div className="k-card__title">Prom (ms)</div>
        <div className="k-card__content">
          <span className="k-metric">{avgMs != null ? avgMs : "—"}</span>
        </div>
      </div>
    </div>
  );
}
JSX

echo "✔ Cards.jsx actualizado"

###############################################################################
# 2) Parchar src/App.jsx (insertar baseMonitors, headerCounts, status y click handlers)
###############################################################################
APP="src/App.jsx"
cp "$APP" "$APP.bak.$TS"
echo "[backup] $APP -> $APP.bak.$TS"

# A) Asegurar que el estado filters tenga 'status: "all"'
if grep -q 'useState({[^}]*onlyDown[^}]*})' "$APP"; then
  # add status if missing
  sed -i 's/onlyDown: false[[:space:]]*}/onlyDown: false, status: "all" }/g' "$APP" || true
fi

# B) Insertar bloques: baseMonitors, headerCounts, effectiveStatus, setStatus
#   Se insertan antes de la primera aparición de 'const filteredAll = useMemo('
awk '
  BEGIN{printed=0}
  /const filteredAll = useMemo\(/ && printed==0 {
    print "// --- baseMonitors: aplica instance/type/q (NO estado) ---";
    print "const baseMonitors = useMemo(() => {";
    print "  return (monitors ?? []).filter(m => {";
    print "    if (filters.instance && m.instance !== filters.instance) return false;";
    print "    if (filters.type && m.info?.monitor_type !== filters.type) return false;";
    print "    if (filters.q) {";
    print "      const hay = `${m.info?.monitor_name ?? \"\"} ${m.info?.monitor_url ?? \"\"}`.toLowerCase();";
    print "      if (!hay.includes(filters.q.toLowerCase())) return false;";
    print "    }";
    print "    return true;";
    print "  });";
    print "}, [monitors, filters.instance, filters.type, filters.q]);";
    print "";
    print "// --- headerCounts: totales de MONITORES para el header ---";
    print "const headerCounts = useMemo(() => {";
    print "  const up    = baseMonitors.filter(m => m.latest?.status === 1).length;";
    print "  const down  = baseMonitors.filter(m => m.latest?.status === 0).length;";
    print "  const total = baseMonitors.length;";
    print "  const rts = baseMonitors.map(m => m.latest?.responseTime).filter(v => v != null);";
    print "  const avg = rts.length ? Math.round(rts.reduce((a,b)=>a+b,0)/rts.length) : null;";
    print "  return { up, down, total, avgMs: avg };";
    print "}, [baseMonitors]);";
    print "";
    print "// --- Estado efectivo y setter desde header ---";
    print "const effectiveStatus =";
    print "  filters.status !== \"all\" ? filters.status : (filters.onlyDown ? \"down\" : \"all\");";
    print "function setStatus(status) {";
    print "  setFilters(prev => ({ ...prev, status, onlyDown: status === \"down\" }));";
    print "}";
    print "";
    printed=1
  }
  {print}
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# C) Ajustar filtro por estado en filteredAll:
#    Reemplazar la línea del onlyDown por condiciones con effectiveStatus
sed -i 's/if (filters.onlyDown && m.latest?.status !== 0) return false;/if (effectiveStatus === "up" && m.latest?.status !== 1) return false;\n    if (effectiveStatus === "down" && m.latest?.status !== 0) return false;/' "$APP" || true

# D) Reemplazar el uso de <Cards .../> para pasar counts/status/onSetStatus
if grep -q '<Cards summary={summary}' "$APP"; then
  sed -i 's/<Cards summary={summary} \/>/<Cards counts={headerCounts} status={effectiveStatus} onSetStatus={setStatus} \/>/g' "$APP"
fi

echo "✔ App.jsx parcheado"

###############################################################################
# 3) Añadir estilos finales a styles.css (header clicable + cards robustas)
###############################################################################
STYLE_MAIN="src/styles.css"
if [ -f "$STYLE_MAIN" ]; then
  cp "$STYLE_MAIN" "$STYLE_MAIN.bak.$TS"
  echo "[backup] $STYLE_MAIN -> $STYLE_MAIN.bak.$TS"
else
  touch "$STYLE_MAIN"
fi

cat >> "$STYLE_MAIN" <<'CSS'

/* === Patch UI: header interactivo y cards robustas === */
.k-card.k-card--summary {
  border: 1px solid #e5e7eb;
  border-left: 6px solid #e5e7eb;
  border-radius: 10px;
  background: #fff;
  padding: 12px;
}
.k-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
  margin: 8px 0 16px;
}
.k-card__title { font-weight: 600; margin-bottom: 6px; }
.k-card__content { display: flex; align-items: center; }
.k-metric { font-size: 20px; font-weight: 700; margin-right: 6px; }
.k-label  { color: #6b7280; font-size: 12px; }
.is-clickable { cursor: pointer; transition: box-shadow .15s ease, transform .05s ease; }
.is-clickable:hover { box-shadow: 0 2px 10px rgba(0,0,0,.06); }
.is-active { outline: 2px solid #93c5fd; background: #f0f9ff; }

/* Cards de sede más robustas (si usas k-card--site) */
.k-card.k-card--site {
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  background: #fff;
  padding: 12px;
  display: flex; flex-direction: column; gap: 10px;
  min-height: 140px;
}
.k-card__head { display: flex; justify-content: space-between; align-items: center; }
.k-badge { font-size: 12px; font-weight: 600; color: #fff; padding: 3px 8px; border-radius: 999px; }
.k-badge--ok { background: #16a34a; }
.k-badge--danger { background: #dc2626; }
.k-stats { display: grid; grid-template-columns: repeat(4, minmax(0,1fr)); gap: 6px; }
.k-label { color: #6b7280; font-size: 12px; }
.k-val   { font-weight: 600; }
.k-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 4px; }
.k-btn { font-size: 12px; padding: 6px 10px; border-radius: 8px; cursor: pointer; border: 1px solid #e5e7eb; background: #f9fafb; }
.k-btn--primary { border-color: #2563eb; color: #2563eb; background: #eff6ff; }
.k-btn--danger  { border-color: #dc2626; color: #dc2626; background: #fef2f2; }
.k-btn--ghost   { border-color: #cbd5e1; color: #334155; background: #fff; }
.k-btn:hover    { filter: brightness(0.98); }

/* Ajuste general de grid para evitar desbordes */
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
CSS

echo "✔ styles.css actualizado"

echo
echo "✅ Patch aplicado. Ahora ejecuta:  npm run dev"
echo "• El header muestra totales de MONITORES (UP/DOWN/Total/Prom) según filtros (sede/tipo/buscar)."
echo "• Clic en 'UP' o 'DOWN' aplica/quita filtro de estado; clic en 'Total' vuelve a 'Todos'."
