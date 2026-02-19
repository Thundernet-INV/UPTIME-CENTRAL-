#!/bin/bash
# recuperar-boton-editar.sh
# RECUPERA EL BOTÓN DE EDITAR EN EL PANEL DE ADMIN

echo "====================================================="
echo "🔧 RECUPERANDO BOTÓN DE EDITAR"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ADMIN_FILE="$FRONTEND_DIR/src/components/AdminPlantas.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$ADMIN_FILE" "$ADMIN_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. AGREGAR BOTÓN DE EDITAR ==========
echo ""
echo "[2] Agregando botón de editar..."

# Buscar la sección de acciones y reemplazar
sed -i '/<td>/,/<\/td>/ {
  /Acciones/! {
    /<button/ {
      s/<button.*<\/button>/<div style={{ display: "\''flex\''", gap: 4 }}>\n                    <button\n                      className="btn-agregar"\n                      onClick={() => window.location.hash = `#\/admin-plantas\/editar\/${encodeURIComponent(planta.nombre_monitor)}`}\n                      style={{ background: "\''#3b82f6\''" }}\n                    >\n                      Editar\n                    </button>\n                    <button\n                      className="btn-reset"\n                      onClick={() => resetearPlanta(planta.nombre_monitor)}\n                      disabled={isUp}\n                      title={isUp ? "\''No se puede resetear mientras está encendida\''" : "\''Resetear contador\''"}\n                    >\n                      Resetear\n                    </button>\n                  <\/div>/g
    }
  }
}' "$ADMIN_FILE"

echo "✅ Botón de editar agregado"

# ========== 3. REINICIAR FRONTEND ==========
echo ""
echo "[3] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ BOTÓN DE EDITAR RECUPERADO ✅✅"
echo "====================================================="
echo ""
