#!/bin/bash
# eliminar-tabs.sh - ELIMINA LA BARRA DE PESTAÑAS DEL DASHBOARD

echo "====================================================="
echo "🗑️ ELIMINANDO BARRA DE PESTAÑAS (TABS)"
echo "====================================================="
echo ""

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_FILE="${FRONTEND_DIR}/src/App.jsx.backup.$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo "📦 Creando backup de App.jsx..."
cp "${FRONTEND_DIR}/src/App.jsx" "$BACKUP_FILE"
echo "✅ Backup creado en: $BACKUP_FILE"
echo ""

# ========== 2. MODIFICAR APP.JSX ==========
echo "🔧 Modificando App.jsx para eliminar los tabs..."

cat > "${FRONTEND_DIR}/src/App.jsx" << 'EOF'
import React, { useEffect } from "react";
import Dashboard from "./views/Dashboard.jsx";
import DarkModeCornerButton from "./components/DarkModeCornerButton.jsx";
import "./styles.css";
import "./dark-mode.css";

export default function App() {
  useEffect(() => {
    // Restaurar tema guardado
    try {
      const savedTheme = localStorage.getItem('uptime-theme');
      if (savedTheme === 'dark') {
        document.body.classList.add('dark-mode');
      }
    } catch (e) {
      console.error('Error al restaurar tema:', e);
    }
  }, []);

  return (
    <>
      <DarkModeCornerButton />
      <Dashboard />
    </>
  );
}
EOF

echo "✅ App.jsx modificado - Tabs eliminados"
echo ""

# ========== 3. REINICIAR FRONTEND ==========
echo "🔄 Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null
npm run dev &
sleep 3

echo ""
echo "====================================================="
echo "✅✅ TABS ELIMINADOS CORRECTAMENTE ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo "   • Eliminado componente Tabs de App.jsx"
echo "   • Eliminada la lógica de enrutamiento por hash"
echo "   • El dashboard ahora carga directamente sin pestañas"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ Ya no deberías ver los botones 'Dashboard' y 'Equipos' arriba"
echo "   3. ✅ El dashboard carga directamente"
echo ""
echo "🔙 PARA RESTAURAR (si es necesario):"
echo "   cp $BACKUP_FILE ${FRONTEND_DIR}/src/App.jsx"
echo ""
echo "====================================================="

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado"
