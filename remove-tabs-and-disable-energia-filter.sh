#!/bin/bash
# remove-tabs-and-disable-energia-filter.sh
# ------------------------------------------------------------
# Quita las pestañas superiores (Dashboard/Equipos) y
# desactiva temporalmente los filtros en la vista de Energía.
# Crea backups con timestamp y reinicia Vite.
# ------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIR="$ROOT_DIR"
SRC_DIR="$FRONTEND_DIR/src"
APP_FILE="$SRC_DIR/App.jsx"
ENERGIA_FILE="$SRC_DIR/views/Energia.jsx"
TS="$(date +%Y%m%d_%H%M%S)"

log(){ echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){ echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){ echo -e "\033[1;31m[ERR ]\033[0m $*"; }

ensure_file(){
  local f="$1"; if [ ! -f "$f" ]; then err "No existe: $f"; exit 1; fi
}

backup(){
  local f="$1"; local b="${f}.backup.${TS}"; cp "$f" "$b"; ok "Backup: $b";
}

latest_backup_tab(){
  # Devuelve el archivo de backup de App.jsx sin tabs si existe
  # p.ej. backup_tab_app.jsx.20260217_123232
  ls -1 "$FRONTEND_DIR"/backup_tab_app.jsx.* 2>/dev/null | sort -r | head -n1 || true
}

apply_app_without_tabs(){
  ensure_file "$APP_FILE"
  backup "$APP_FILE"

  local BKP
  BKP="$(latest_backup_tab)"
  if [ -n "$BKP" ] && [ -f "$BKP" ]; then
    log "Usando backup conocido sin pestañas: $BKP"
    cp "$BKP" "$APP_FILE"
    ok "App.jsx restaurado desde backup sin pestañas"
  else
    warn "No se encontró backup_tab_app.jsx.*; aplicaré un App.jsx mínimo sin Tabs"
    cat > "$APP_FILE" <<'EOF'
import React, { useEffect } from "react";
import Dashboard from "./views/Dashboard.jsx";
import DarkModeCornerButton from "./components/DarkModeCornerButton.jsx";
import "./styles.css";
import "./dark-mode.css";

export default function App() {
  useEffect(() => {
    try {
      const savedTheme = localStorage.getItem("uptime-theme");
      if (savedTheme === "dark") document.body.classList.add("dark-mode");
    } catch {}
  }, []);
  return (
    <>
      <DarkModeCornerButton />
      <Dashboard />
    </>
  );
}
EOF
    ok "App.jsx minimal aplicado (sin Tabs)"
  fi
}

comment_filters_ui(){
  # Comenta visualmente el bloque <Filters ... /> si existe
  # Reemplaza la apertura por {false && <Filters y deja el cierre igual
  if grep -q "<Filters" "$ENERGIA_FILE" 2>/dev/null; then
    sed -i 's/<Filters/{false && <Filters/g' "$ENERGIA_FILE"
    ok "UI de filtros en Energia.jsx ocultada"
  else
    warn "No se encontró <Filters ... /> en Energia.jsx; omitiendo ocultar UI"
  fi
}

inject_disable_flag(){
  # Inserta un flag al inicio tras los imports
  if ! grep -q "__DISABLE_FILTERS__" "$ENERGIA_FILE" 2>/dev/null; then
    # Inserta después de la última línea de import
    awk '
      BEGIN{inserted=0}
      {
        print $0;
        if ($0 ~ /^import[[:space:]]/){ last=NR }
      }
      END{
      }
    ' "$ENERGIA_FILE" > "$ENERGIA_FILE.__tmp__"

    # Encontrar última línea de import con awk y luego insertar flag con sed
    LAST_IMPORT_LINE=$(awk '/^import[[:space:]]/ {li=NR} END{print li+0}' "$ENERGIA_FILE")
    if [ "$LAST_IMPORT_LINE" -gt 0 ]; then
      sed -i "${LAST_IMPORT_LINE}a const __DISABLE_FILTERS__ = true; // 🔕 filtros desactivados temporalmente" "$ENERGIA_FILE"
      ok "Flag __DISABLE_FILTERS__ insertado"
    else
      # Si no hay imports, inserta al principio
      sed -i '1iconst __DISABLE_FILTERS__ = true; // 🔕 filtros desactivados temporalmente' "$ENERGIA_FILE"
      ok "Flag __DISABLE_FILTERS__ insertado al inicio"
    fi
    rm -f "$ENERGIA_FILE.__tmp__" 2>/dev/null || true
  else
    warn "Flag __DISABLE_FILTERS__ ya presente; no se duplica"
  fi
}

neutralize_filtering_logic(){
  # Si existe un patrón típico "const filtrados = useMemo( ... );"
  # lo sustituimos por un passthrough que devuelve el arreglo original disponible.
  if grep -q "const[[:space:]]\+filtrados[[:space:]]*=[[:space:]]*useMemo" "$ENERGIA_FILE" 2>/dev/null; then
    # Creamos un bloque seguro que no referencia símbolos inexistentes
    TMP_JS=$(mktemp)
    cat > "$TMP_JS" <<'EOT'
const filtrados = useMemo(() => {
  if (__DISABLE_FILTERS__) {
    const pick = (v) => (Array.isArray(v) ? v : null);
    const cand =
      (typeof data !== 'undefined' && pick(data)) ||
      (typeof items !== 'undefined' && pick(items)) ||
      (typeof monitors !== 'undefined' && pick(monitors)) ||
      (typeof lista !== 'undefined' && pick(lista)) ||
      (typeof catalog !== 'undefined' && pick(catalog)) ||
      (typeof services !== 'undefined' && pick(services)) ||
      [];
    return cand;
  }
  // (Lógica original removida temporalmente por el script)
  return [];
}, [__DISABLE_FILTERS__]);
EOT

    # Sustituir el bloque completo: desde la línea de declaración hasta el primer ")}\)" de cierre típico
    # Estrategia: usar perl para hacer reemplazo no codicioso.
    perl -0777 -pe "s/const\s+filtrados\s*=\s*useMemo\s*\([\s\S]*?\)\s*;/$((sed 's/[&/]/\\&/g' "$TMP_JS"; echo) | tr -d '\n')/e" "$ENERGIA_FILE" > "$ENERGIA_FILE.__patched__"
    mv "$ENERGIA_FILE.__patched__" "$ENERGIA_FILE"
    rm -f "$TMP_JS"
    ok "Lógica de filtrado reemplazada por passthrough en Energia.jsx"
  else
    warn "No se encontró declaración típica de 'filtrados'; aplicaré fallback genérico"
    # Fallback: si existe una variable 'filtrados' posterior, intenta forzar alias seguro
    if ! grep -q "__FILTRADOS_FALLBACK__" "$ENERGIA_FILE" 2>/dev/null; then
      cat >> "$ENERGIA_FILE" <<'EOT'

// Fallback inyectado por script (seguro y reversible)
// Forza un alias visible sin filtros cuando el flag está activo
// Nota: Solo se usa si tu componente define variables compatibles
try {
  if (typeof __DISABLE_FILTERS__ !== 'undefined' && __DISABLE_FILTERS__) {
    const pick = (v) => (Array.isArray(v) ? v : null);
    const __FILTRADOS_FALLBACK__ =
      (typeof filtrados !== 'undefined' && pick(filtrados)) ||
      (typeof data !== 'undefined' && pick(data)) ||
      (typeof items !== 'undefined' && pick(items)) ||
      (typeof monitors !== 'undefined' && pick(monitors)) ||
      (typeof lista !== 'undefined' && pick(lista)) ||
      (typeof catalog !== 'undefined' && pick(catalog)) ||
      [];
    if (typeof window !== 'undefined') {
      window.__ENERGIA_LISTA_VISIBLE__ = __FILTRADOS_FALLBACK__;
    }
  }
} catch (e) { /* noop */ }
EOT
      ok "Fallback genérico agregado al final de Energia.jsx"
    else
      warn "Fallback genérico ya estaba presente; sin cambios"
    fi
  fi
}

restart_vite(){
  log "Reiniciando Vite y limpiando caché..."
  (cd "$FRONTEND_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true)
  pkill -f "vite" 2>/dev/null || true
  (cd "$FRONTEND_DIR" && (npm run dev &))
  ok "Vite reiniciado"
}

main(){
  ensure_file "$APP_FILE"
  apply_app_without_tabs

  if [ -f "$ENERGIA_FILE" ]; then
    backup "$ENERGIA_FILE"
    comment_filters_ui || true
    inject_disable_flag || true
    neutralize_filtering_logic || true
  else
    warn "No existe $ENERGIA_FILE; solo se aplicaron cambios en App.jsx"
  fi

  restart_vite
  echo
  ok "Hecho. Las pestañas superiores se quitaron y los filtros de Energía quedaron desactivados."
  echo "👉 Si quieres revertir, usa los backups con suffijo .backup.${TS} en App.jsx y Energia.jsx"
}

main "$@"

