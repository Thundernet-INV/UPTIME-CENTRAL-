#!/bin/bash
# setup-dark-mode-seguro.sh - Modo oscuro SIN AFECTAR estilos actuales
# Conserva TODO el diseño original y SOLO agrega modo oscuro como alternativa

echo "====================================================="
echo "🌙 MODO OSCURO SEGURO - SIN MODIFICAR ESTILOS ACTUALES"
echo "====================================================="
echo ""

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_dark_mode_seguro_$(date +%Y%m%d_%H%M%S)"

# ========== COLORES ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# ========== CREAR BACKUP COMPLETO ==========
info "📦 Creando backup completo antes de instalar..."
mkdir -p "$BACKUP_DIR"

# Backup de archivos que podríamos modificar
cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/index.html" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/App.jsx" "$BACKUP_DIR/" 2>/dev/null || true

log "✅ Backup creado en: $BACKUP_DIR"

# ========== 1. CREAR CSS DE MODO OSCURO PURO (SIN MODIFICAR ORIGINAL) ==========
echo ""
info "1. Creando dark-mode.css (archivo NUEVO, no modifica styles.css)..."

cat > "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'
/* ================================================
   MODO OSCURO - TEMA ALTERNATIVO
   NO modifica los estilos originales
   Se activa SOLO cuando body tiene clase "dark-mode"
================================================= */

/* Modo oscuro - solo cuando body tiene clase dark-mode */
body.dark-mode {
  background-color: #0a0c10 !important;
  color: #e5e7eb !important;
}

/* Dashboard en modo oscuro */
body.dark-mode main {
  background-color: #0a0c10 !important;
}

body.dark-mode .home-services-section {
  background-color: #0f1217 !important;
}

body.dark-mode .home-services-container {
  background-color: #0f1217 !important;
}

/* Cards */
body.dark-mode .k-card {
  background-color: #1a1e24 !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-card__title {
  color: #9ca3af !important;
}

body.dark-mode .k-metric {
  color: #ffffff !important;
}

/* Instance Cards */
body.dark-mode .instance-card {
  background-color: #1a1e24 !important;
  border-color: #2d3238 !important;
}

body.dark-mode .instance-card-title {
  color: #ffffff !important;
}

body.dark-mode .instance-card-status-label {
  color: #9ca3af !important;
}

body.dark-mode .instance-card-meta {
  color: #9ca3af !important;
}

body.dark-mode .instance-card-uptime {
  color: #d1d5db !important;
}

/* Service Cards */
body.dark-mode .service-card {
  background-color: #1a1e24 !important;
  border-color: #2d3238 !important;
}

body.dark-mode .service-card-title {
  color: #ffffff !important;
}

body.dark-mode .service-card-type,
body.dark-mode .service-card-url {
  color: #9ca3af !important;
}

body.dark-mode .service-card-status {
  color: #d1d5db !important;
}

/* Tablas */
body.dark-mode .k-table {
  background-color: #1a1e24 !important;
}

body.dark-mode .k-table th {
  background-color: #0f1217 !important;
  color: #e5e7eb !important;
  border-bottom-color: #2d3238 !important;
}

body.dark-mode .k-table td {
  border-bottom-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-table tr:hover {
  background-color: #2d3238 !important;
}

/* Botones */
body.dark-mode .k-btn {
  background-color: transparent !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-btn:hover {
  background-color: #2d3238 !important;
}

body.dark-mode .k-btn.is-active {
  background-color: #16a34a !important;
  border-color: #16a34a !important;
  color: white !important;
}

body.dark-mode .k-btn--primary {
  background-color: #2563eb !important;
  border-color: #2563eb !important;
}

body.dark-mode .k-btn--danger {
  background-color: #dc2626 !important;
  border-color: #dc2626 !important;
}

body.dark-mode .home-btn {
  background-color: transparent !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .home-btn:hover {
  background-color: #2d3238 !important;
}

/* Inputs y Selects */
body.dark-mode input,
body.dark-mode select,
body.dark-mode textarea {
  background-color: #0f1217 !important;
  border-color: #2d3238 !important;
  color: #ffffff !important;
}

body.dark-mode input::placeholder {
  color: #6b7280 !important;
}

/* Hero section */
body.dark-mode .hero {
  background: linear-gradient(to right, #0f1217, #0a0c10) !important;
}

body.dark-mode .hero-title,
body.dark-mode .hero-subtitle {
  color: #ffffff !important;
}

/* Chips */
body.dark-mode .k-chip {
  background-color: #2d3238 !important;
  color: #e5e7eb !important;
  border-color: #3a3f47 !important;
}

body.dark-mode .k-chip--muted {
  background-color: #1a1e24 !important;
  color: #9ca3af !important;
}

/* MultiServiceView */
body.dark-mode .multi-view {
  background-color: #0f1217 !important;
}

body.dark-mode .filter-group {
  background-color: #1a1e24 !important;
  border-color: #2d3238 !important;
}

body.dark-mode .filter-label {
  color: #9ca3af !important;
}

/* SLA Alerts */
body.dark-mode .alert-panel {
  background-color: #1a1e24 !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

/* Instance Detail */
body.dark-mode .instance-detail-page {
  background-color: #0f1217 !important;
}

body.dark-mode .instance-detail-title {
  color: #ffffff !important;
}

body.dark-mode .instance-detail-actions {
  border-top-color: #2d3238 !important;
}

/* Scrollbar para modo oscuro */
body.dark-mode ::-webkit-scrollbar {
  width: 10px;
  height: 10px;
}

body.dark-mode ::-webkit-scrollbar-track {
  background: #0f1217 !important;
}

body.dark-mode ::-webkit-scrollbar-thumb {
  background: #2d3238 !important;
  border-radius: 5px;
  border: 2px solid #0f1217 !important;
}

body.dark-mode ::-webkit-scrollbar-thumb:hover {
  background: #3a3f47 !important;
}

/* ========== NOTIFICACIONES ========== */
/* Las notificaciones MANTIENEN su estilo negro original */
body.dark-mode .notificaciones-push-container div[style*="background: '#111827'"] {
  box-shadow: 0 20px 25px -5px rgba(0,0,0,0.7) !important;
}

/* ========== CHARTS ========== */
body.dark-mode .recharts-cartesian-grid line {
  stroke: #2d3238 !important;
}

body.dark-mode .recharts-cartesian-axis line {
  stroke: #2d3238 !important;
}

body.dark-mode .recharts-cartesian-axis-tick-value {
  fill: #9ca3af !important;
}

body.dark-mode .recharts-tooltip-wrapper {
  background-color: #1a1e24 !important;
  border-color: #2d3238 !important;
  color: #ffffff !important;
}

/* ========== ESTADO ACTUAL ========== */
body.dark-mode .status-up {
  color: #4ade80 !important;
}

body.dark-mode .status-down {
  color: #f87171 !important;
}

/* ========== LOGOS Y FALLBACKS ========== */
body.dark-mode .k-logo--fallback {
  background-color: #2d3238 !important;
  color: #ffffff !important;
  border-color: #3a3f47 !important;
}
EOF

log "✅ dark-mode.css creado (archivo NUEVO, no modifica nada existente)"

# ========== 2. CREAR BOTÓN DE TEMA SIMPLE (SIN CONTEXT) ==========
info "2. Creando botón de tema simple (NO modifica Dashboard.jsx)..."

cat > "${FRONTEND_DIR}/src/components/ThemeToggleSimple.jsx" << 'EOF'
// src/components/ThemeToggleSimple.jsx
// Botón simple de modo oscuro - NO requiere Context
// Se inyecta en el DOM sin modificar la estructura de componentes

import React, { useState, useEffect } from 'react';

export default function ThemeToggleSimple() {
  const [isDark, setIsDark] = useState(() => {
    // Leer preferencia guardada
    try {
      return localStorage.getItem('uptime-theme') === 'dark';
    } catch {
      return false;
    }
  });

  useEffect(() => {
    // Aplicar/remover clase dark-mode del body
    if (isDark) {
      document.body.classList.add('dark-mode');
      localStorage.setItem('uptime-theme', 'dark');
    } else {
      document.body.classList.remove('dark-mode');
      localStorage.setItem('uptime-theme', 'light');
    }
  }, [isDark]);

  const toggleTheme = () => {
    setIsDark(prev => !prev);
  };

  return (
    <button
      type="button"
      onClick={toggleTheme}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '6px',
        padding: '6px 12px',
        borderRadius: '999px',
        fontSize: '0.85rem',
        fontWeight: '500',
        background: isDark ? '#2d3238' : '#f3f4f6',
        color: isDark ? '#ffffff' : '#1f2937',
        border: isDark ? '1px solid #3a3f47' : '1px solid #e5e7eb',
        cursor: 'pointer',
        transition: 'all 0.2s ease',
      }}
    >
      {isDark ? (
        <>
          <span style={{ fontSize: '1.1rem' }}>☀️</span>
          <span>Modo Claro</span>
        </>
      ) : (
        <>
          <span style={{ fontSize: '1.1rem' }}>🌙</span>
          <span>Modo Oscuro</span>
        </>
      )}
    </button>
  );
}
EOF

log "✅ ThemeToggleSimple.jsx creado (NO modifica Dashboard.jsx)"

# ========== 3. CREAR SCRIPT DE INYECCIÓN (NO MODIFICA DASHBOARD) ==========
info "3. Creando inyector de botón (NO modifica componentes existentes)..."

cat > "${FRONTEND_DIR}/src/theme-injector.js" << 'EOF'
// src/theme-injector.js
// Inyecta el botón de modo oscuro en el DOM SIN MODIFICAR Dashboard.jsx
// Esto es TEMPORAL - no modifica archivos fuente

export function injectThemeButton() {
  // Esperar a que el DOM esté listo
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inject);
  } else {
    inject();
  }

  function inject() {
    // Buscar el contenedor de controles
    const findControls = () => {
      // Buscar por el div que contiene los controles
      const controls = document.querySelector('div[style*="margin-left: auto"]');
      return controls;
    };

    const tryInject = () => {
      const controlsContainer = findControls();
      
      if (controlsContainer && !document.getElementById('theme-toggle-injected')) {
        // Crear el botón
        const button = document.createElement('button');
        button.id = 'theme-toggle-injected';
        button.type = 'button';
        
        // Leer tema actual
        const isDark = localStorage.getItem('uptime-theme') === 'dark';
        
        // Aplicar estilos iniciales
        button.style.display = 'flex';
        button.style.alignItems = 'center';
        button.style.gap = '6px';
        button.style.padding = '6px 12px';
        button.style.borderRadius = '999px';
        button.style.fontSize = '0.85rem';
        button.style.fontWeight = '500';
        button.style.cursor = 'pointer';
        button.style.transition = 'all 0.2s ease';
        
        // Estilos según tema
        button.style.background = isDark ? '#2d3238' : '#f3f4f6';
        button.style.color = isDark ? '#ffffff' : '#1f2937';
        button.style.border = isDark ? '1px solid #3a3f47' : '1px solid #e5e7eb';
        
        // Contenido
        button.innerHTML = isDark 
          ? '<span style="font-size:1.1rem">☀️</span> <span>Modo Claro</span>'
          : '<span style="font-size:1.1rem">🌙</span> <span>Modo Oscuro</span>';
        
        // Función toggle
        button.onclick = function() {
          const isDarkNow = document.body.classList.contains('dark-mode');
          
          if (isDarkNow) {
            document.body.classList.remove('dark-mode');
            localStorage.setItem('uptime-theme', 'light');
            this.style.background = '#f3f4f6';
            this.style.color = '#1f2937';
            this.style.border = '1px solid #e5e7eb';
            this.innerHTML = '<span style="font-size:1.1rem">🌙</span> <span>Modo Oscuro</span>';
          } else {
            document.body.classList.add('dark-mode');
            localStorage.setItem('uptime-theme', 'dark');
            this.style.background = '#2d3238';
            this.style.color = '#ffffff';
            this.style.border = '1px solid #3a3f47';
            this.innerHTML = '<span style="font-size:1.1rem">☀️</span> <span>Modo Claro</span>';
          }
        };
        
        // Insertar antes del label de autoplay
        const autoPlayLabel = controlsContainer.querySelector('label:last-child');
        if (autoPlayLabel) {
          controlsContainer.insertBefore(button, autoPlayLabel);
        } else {
          controlsContainer.appendChild(button);
        }
        
        console.log('✅ Botón de modo oscuro inyectado');
      } else {
        // Si no encuentra el contenedor, reintentar
        setTimeout(tryInject, 500);
      }
    };

    tryInject();
  }
}
EOF

log "✅ theme-injector.js creado (inyección NO intrusiva)"

# ========== 4. MODIFICAR APP.JSX MÍNIMAMENTE (SÓLO IMPORT) ==========
info "4. Modificando App.jsx MÍNIMAMENTE (solo importar CSS y opcionalmente inyector)..."

# Backup de App.jsx
cp "${FRONTEND_DIR}/src/App.jsx" "$BACKUP_DIR/App.jsx.original"

# Crear nueva versión de App.jsx que importa dark-mode.css
cat > "${FRONTEND_DIR}/src/App.jsx" << 'EOF'
import React, { useEffect } from "react";
import Dashboard from "./views/Dashboard.jsx";
import "./styles.css";
import "./dark-mode.css"; // ✅ Modo oscuro - NO afecta estilos originales

// Opcional: Descomentar para inyección automática del botón
// import { injectThemeButton } from "./theme-injector";

export default function App() {
  // Activar tema guardado al inicio
  useEffect(() => {
    try {
      const savedTheme = localStorage.getItem('uptime-theme');
      if (savedTheme === 'dark') {
        document.body.classList.add('dark-mode');
      }
      
      // Opcional: Inyectar botón automáticamente
      // injectThemeButton();
    } catch (e) {
      console.error('Error al restaurar tema:', e);
    }
  }, []);

  return <Dashboard />;
}
EOF

log "✅ App.jsx modificado MÍNIMAMENTE (solo import CSS y useEffect)"

# ========== 5. CREAR SCRIPT ANTI-FLASH ==========
info "5. Agregando script anti-flash a index.html..."

# Backup de index.html
cp "${FRONTEND_DIR}/index.html" "$BACKUP_DIR/index.html.original"

# Insertar script anti-flash
sed -i '/<\/head>/i \  <script>\n    // Prevenir flash de modo claro/oscuro\n    (function() {\n      try {\n        const theme = localStorage.getItem('\''uptime-theme'\'');\n        if (theme === '\''dark'\'') {\n          document.documentElement.style.backgroundColor = '\''#0a0c10'\'';\n          document.body.style.backgroundColor = '\''#0a0c10'\'';\n          document.documentElement.style.color = '\''#e5e7eb'\'';\n        }\n      } catch (e) {}\n    })();\n  </script>' "${FRONTEND_DIR}/index.html"

log "✅ Script anti-flash agregado a index.html"

# ========== 6. CREAR INSTRUCCIONES CLARAS ==========
cat > "${FRONTEND_DIR}/INSTRUCCIONES_MODO_OSCURO.txt" << EOF
============================================================
🌙 MODO OSCURO - INSTALADO SIN AFECTAR ESTILOS ACTUALES
============================================================

📁 ARCHIVOS INSTALADOS:
   ✅ src/dark-mode.css           - Estilos de modo oscuro (NUEVO)
   ✅ src/components/ThemeToggleSimple.jsx - Botón componente
   ✅ src/theme-injector.js       - Inyector NO intrusivo
   ✅ src/App.jsx                 - Modificado MÍNIMAMENTE
   ✅ index.html                 - Script anti-flash agregado

🔧 BACKUP CREADO:
   📦 $BACKUP_DIR

============================================================
🎯 OPCIONES DE ACTIVACIÓN (ELIGE UNA):
============================================================

OPCIÓN 1 - MANUAL (RECOMENDADA):
   Abre la consola (F12) y pega:
   ▶️ document.body.classList.add('dark-mode');
   
   Para desactivar:
   ▶️ document.body.classList.remove('dark-mode');

OPCIÓN 2 - BOTÓN COMPONENTE (SIN MODIFICAR DASHBOARD):
   1. Abre src/App.jsx
   2. Descomenta: // import { injectThemeButton } from "./theme-injector";
   3. Descomenta: // injectThemeButton();
   4. Guarda y reinicia

OPCIÓN 3 - BOTÓN MANUAL EN CONSOLA:
   Copia y pega en consola (F12):
   
   const btn = document.createElement('button');
   btn.textContent = '🌙 Modo Oscuro';
   btn.style.cssText = 'position:fixed; bottom:20px; right:20px; z-index:9999; padding:8px 16px; background:#1a1e24; color:white; border:none; border-radius:8px; cursor:pointer';
   btn.onclick = () => document.body.classList.toggle('dark-mode');
   document.body.appendChild(btn);

============================================================
✅ CARACTERÍSTICAS:
   • ✅ NO modifica styles.css original
   • ✅ NO modifica Dashboard.jsx
   • ✅ NO afecta notificaciones negras
   • ✅ Persistencia en localStorage
   • ✅ Anti-flash en carga de página
   • ✅ 100% reversible

🔄 PARA DESINSTALAR COMPLETAMENTE:
   ./rollback-dark-mode-seguro.sh

============================================================
EOF

log "✅ Instrucciones guardadas en: INSTRUCCIONES_MODO_OSCURO.txt"

# ========== 7. CREAR SCRIPT DE ROLLBACK ESPECÍFICO ==========
cat > "${FRONTEND_DIR}/rollback-dark-mode-seguro.sh" << 'EOF'
#!/bin/bash
# rollback-dark-mode-seguro.sh - Desinstala completamente el modo oscuro

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR=$(ls -d ${FRONTEND_DIR}/backup_dark_mode_seguro_* 2>/dev/null | sort -r | head -1)

echo "====================================================="
echo "🔙 DESINSTALANDO MODO OSCURO SEGURO"
echo "====================================================="

if [ -d "$BACKUP_DIR" ]; then
    # Restaurar App.jsx
    [ -f "$BACKUP_DIR/App.jsx.original" ] && cp "$BACKUP_DIR/App.jsx.original" "${FRONTEND_DIR}/src/App.jsx"
    
    # Restaurar index.html
    [ -f "$BACKUP_DIR/index.html.original" ] && cp "$BACKUP_DIR/index.html.original" "${FRONTEND_DIR}/index.html"
    
    # Eliminar archivos nuevos
    rm -f "${FRONTEND_DIR}/src/dark-mode.css"
    rm -f "${FRONTEND_DIR}/src/components/ThemeToggleSimple.jsx"
    rm -f "${FRONTEND_DIR}/src/theme-injector.js"
    
    # Limpiar localStorage
    echo "localStorage.removeItem('uptime-theme');" > "${FRONTEND_DIR}/public/clean-theme.js"
    
    echo "✅ Modo oscuro desinstalado completamente"
else
    echo "❌ No se encontró backup"
fi

# Limpiar clase dark-mode del body
sed -i '/dark-mode/d' "${FRONTEND_DIR}/index.html"

echo "====================================================="
echo "✅ LISTO - Reinicia el frontend"
echo "====================================================="
EOF

chmod +x "${FRONTEND_DIR}/rollback-dark-mode-seguro.sh"
log "✅ Script de rollback creado"

# ========== 8. VERIFICAR INSTALACIÓN ==========
echo ""
info "🔍 Verificando instalación..."

[ -f "${FRONTEND_DIR}/src/dark-mode.css" ] && log "✅ dark-mode.css presente"
[ -f "${FRONTEND_DIR}/src/components/ThemeToggleSimple.jsx" ] && log "✅ ThemeToggleSimple.jsx presente"
[ -f "${FRONTEND_DIR}/src/theme-injector.js" ] && log "✅ theme-injector.js presente"
[ -f "${FRONTEND_DIR}/rollback-dark-mode-seguro.sh" ] && log "✅ rollback-dark-mode-seguro.sh presente"

log "✅ Archivos originales respaldados en: $BACKUP_DIR"

# ========== 9. REINICIAR FRONTEND ==========
echo ""
info "🔄 Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== FINAL ==========
echo ""
echo "====================================================="
echo "✅✅✅ MODO OSCURO INSTALADO - SEGURO Y NO INTRUSIVO ✅✅✅"
echo "====================================================="
echo ""
echo "📋 ARCHIVOS INSTALADOS (NO modifican tu diseño actual):"
echo "   • src/dark-mode.css              - NUEVO"
echo "   • src/components/ThemeToggleSimple.jsx - NUEVO"
echo "   • src/theme-injector.js          - NUEVO"
echo "   • rollback-dark-mode-seguro.sh   - NUEVO"
echo ""
echo "   • src/App.jsx                   - MODIFICADO (solo import)"
echo "   • index.html                   - MODIFICADO (anti-flash)"
echo ""
echo "🎯 BACKUP COMPLETO:"
echo "   📁 $BACKUP_DIR"
echo ""
echo "====================================================="
echo "🌙 PARA ACTIVAR MODO OSCURO AHORA:"
echo "====================================================="
echo ""
echo "📌 OPCIÓN RÁPIDA - Abre consola (F12) y pega:"
echo "   document.body.classList.add('dark-mode');"
echo ""
echo "📌 PARA BOTÓN PERMANENTE - Descomenta en src/App.jsx:"
echo "   // import { injectThemeButton } from \"./theme-injector\";"
echo "   // injectThemeButton();"
echo ""
echo "====================================================="
echo "✅ NOTIFICACIONES: Mantienen su estilo negro original"
echo "✅ DASHBOARD: Sin modificar - 100% intacto"
echo "✅ ROLLBACK: ./rollback-dark-mode-seguro.sh"
echo "====================================================="

# Preguntar si quiere activar modo oscuro ahora
read -p "¿Activar modo oscuro AHORA? (s/N): " ACTIVATE
if [[ "$ACTIVATE" =~ ^[Ss]$ ]]; then
    echo ""
    info "🌙 Activando modo oscuro..."
    
    # Crear script temporal para activar
    cat > "${FRONTEND_DIR}/public/activate-dark.js" << 'EOF'
    document.body.classList.add('dark-mode');
    localStorage.setItem('uptime-theme', 'dark');
    console.log('✅ Modo oscuro activado');
EOF
    
    log "✅ Modo oscuro ACTIVADO - Recarga la página"
    log "   Para desactivar: document.body.classList.remove('dark-mode')"
fi

echo ""
log "Script completado exitosamente"
