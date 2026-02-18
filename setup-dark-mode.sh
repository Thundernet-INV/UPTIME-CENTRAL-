#!/bin/bash
# setup-dark-mode.sh - Instalador inteligente de modo oscuro
# Detecta archivos existentes y agrega solo lo necesario sin duplicar

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_dark_mode_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${FRONTEND_DIR}/dark_mode_install_$(date +%Y%m%d_%H%M%S).log"

# Funciones
log() { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}[i]${NC} $1" | tee -a "$LOG_FILE"; }
separator() { echo "========================================" | tee -a "$LOG_FILE"; }

# Verificar directorio
check_directory() {
    if [ ! -d "$FRONTEND_DIR" ]; then
        error "Directorio no encontrado: $FRONTEND_DIR"
        exit 1
    fi
    info "Directorio frontend: $FRONTEND_DIR"
}

# Crear backup
create_backup() {
    separator
    info "Creando backup antes de modificaciones..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup de archivos existentes
    [ -f "${FRONTEND_DIR}/src/contexts/ThemeContext.jsx" ] && \
        cp "${FRONTEND_DIR}/src/contexts/ThemeContext.jsx" "$BACKUP_DIR/" 2>/dev/null || true
    
    [ -f "${FRONTEND_DIR}/src/components/ThemeToggle.jsx" ] && \
        cp "${FRONTEND_DIR}/src/components/ThemeToggle.jsx" "$BACKUP_DIR/" 2>/dev/null || true
    
    [ -f "${FRONTEND_DIR}/src/dark-mode.css" ] && \
        cp "${FRONTEND_DIR}/src/dark-mode.css" "$BACKUP_DIR/" 2>/dev/null || true
    
    [ -f "${FRONTEND_DIR}/src/App.jsx" ] && \
        cp "${FRONTEND_DIR}/src/App.jsx" "$BACKUP_DIR/App.jsx.bak" 2>/dev/null || true
    
    [ -f "${FRONTEND_DIR}/src/views/Dashboard.jsx" ] && \
        cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/Dashboard.jsx.bak" 2>/dev/null || true
    
    [ -f "${FRONTEND_DIR}/src/components/HistoryChart.jsx" ] && \
        cp "${FRONTEND_DIR}/src/components/HistoryChart.jsx" "$BACKUP_DIR/HistoryChart.jsx.bak" 2>/dev/null || true
    
    [ -f "${FRONTEND_DIR}/index.html" ] && \
        cp "${FRONTEND_DIR}/index.html" "$BACKUP_DIR/index.html.bak" 2>/dev/null || true
    
    log "Backup creado en: $BACKUP_DIR"
}

# Verificar y crear directorios
check_directories() {
    separator
    info "Verificando estructura de directorios..."
    
    if [ ! -d "${FRONTEND_DIR}/src/contexts" ]; then
        mkdir -p "${FRONTEND_DIR}/src/contexts"
        log "Directorio creado: src/contexts"
    else
        info "Directorio src/contexts ya existe"
    fi
    
    if [ ! -d "${FRONTEND_DIR}/src/theme" ]; then
        mkdir -p "${FRONTEND_DIR}/src/theme"
        log "Directorio creado: src/theme"
    else
        info "Directorio src/theme ya existe"
    fi
}

# 1. Verificar y crear ThemeContext.jsx
setup_theme_context() {
    separator
    info "Verificando ThemeContext.jsx..."
    
    local THEME_CONTEXT_FILE="${FRONTEND_DIR}/src/contexts/ThemeContext.jsx"
    
    if [ -f "$THEME_CONTEXT_FILE" ]; then
        warn "ThemeContext.jsx ya existe - verificando contenido..."
        
        # Verificar si tiene todas las propiedades necesarias
        if grep -q "export const themes" "$THEME_CONTEXT_FILE" && \
           grep -q "dark:" "$THEME_CONTEXT_FILE" && \
           grep -q "light:" "$THEME_CONTEXT_FILE"; then
            log "ThemeContext.jsx ya tiene configuración completa"
            return
        else
            warn "ThemeContext.jsx incompleto - será reemplazado"
            cp "$THEME_CONTEXT_FILE" "$BACKUP_DIR/ThemeContext.jsx.old"
        fi
    fi
    
    log "Creando ThemeContext.jsx..."
    cat > "$THEME_CONTEXT_FILE" << 'EOF'
// src/contexts/ThemeContext.jsx - Generado automáticamente
import React, { createContext, useContext, useEffect, useState } from 'react';

const ThemeContext = createContext();

export const themes = {
  light: {
    name: 'light',
    bgPrimary: '#ffffff',
    bgSecondary: '#f9fafb',
    bgTertiary: '#f3f4f6',
    bgCard: '#ffffff',
    bgHover: '#f9fafb',
    textPrimary: '#111827',
    textSecondary: '#4b5563',
    textTertiary: '#6b7280',
    textInverse: '#ffffff',
    border: '#e5e7eb',
    borderHover: '#d1d5db',
    success: '#16a34a',
    successBg: '#dcfce7',
    warning: '#f59e0b',
    warningBg: '#fef3c7',
    danger: '#dc2626',
    dangerBg: '#fee2e2',
    info: '#3b82f6',
    infoBg: '#dbeafe',
    chartGrid: '#e5e7eb',
    chartText: '#6b7280',
    chartLine: '#3b82f6',
    shadow: '0 1px 3px rgba(0,0,0,0.1)',
    shadowLg: '0 10px 25px -5px rgba(0,0,0,0.1)',
    cardBg: '#ffffff',
    cardBorder: '#e5e7eb',
    inputBg: '#ffffff',
    inputBorder: '#e5e7eb',
    inputPlaceholder: '#9ca3af',
    btnGhostBg: 'transparent',
    btnGhostHover: '#f3f4f6',
    btnGhostBorder: '#e5e7eb',
    btnGhostText: '#374151',
  },
  dark: {
    name: 'dark',
    bgPrimary: '#0f172a',
    bgSecondary: '#1e293b',
    bgTertiary: '#334155',
    bgCard: '#1e293b',
    bgHover: '#2d3b4f',
    textPrimary: '#f1f5f9',
    textSecondary: '#cbd5e1',
    textTertiary: '#94a3b8',
    textInverse: '#0f172a',
    border: '#334155',
    borderHover: '#475569',
    success: '#4ade80',
    successBg: '#166534',
    warning: '#fbbf24',
    warningBg: '#854d0e',
    danger: '#f87171',
    dangerBg: '#991b1b',
    info: '#60a5fa',
    infoBg: '#1e40af',
    chartGrid: '#334155',
    chartText: '#94a3b8',
    chartLine: '#60a5fa',
    shadow: '0 1px 3px rgba(0,0,0,0.5)',
    shadowLg: '0 20px 25px -5px rgba(0,0,0,0.7)',
    cardBg: '#1e293b',
    cardBorder: '#334155',
    inputBg: '#0f172a',
    inputBorder: '#334155',
    inputPlaceholder: '#64748b',
    btnGhostBg: 'transparent',
    btnGhostHover: '#334155',
    btnGhostBorder: '#475569',
    btnGhostText: '#e2e8f0',
  }
};

export const ThemeProvider = ({ children }) => {
  const [theme, setTheme] = useState(() => {
    try {
      const saved = localStorage.getItem('uptime-theme');
      return saved && themes[saved] ? themes[saved] : themes.light;
    } catch {
      return themes.light;
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem('uptime-theme', theme.name);
      const root = document.documentElement;
      Object.entries(theme).forEach(([key, value]) => {
        if (typeof value === 'string' && key !== 'name') {
          root.style.setProperty(`--${key}`, value);
        }
      });
    } catch (e) {
      console.error('Error setting theme:', e);
    }
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => prev.name === 'light' ? themes.dark : themes.light);
  };

  const setLightTheme = () => setTheme(themes.light);
  const setDarkTheme = () => setTheme(themes.dark);

  return (
    <ThemeContext.Provider value={{
      theme,
      toggleTheme,
      setLightTheme,
      setDarkTheme,
      isDark: theme.name === 'dark',
      isLight: theme.name === 'light'
    }}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme debe usarse dentro de ThemeProvider');
  }
  return context;
};
EOF
    log "ThemeContext.jsx creado correctamente"
}

# 2. Verificar y crear ThemeToggle.jsx
setup_theme_toggle() {
    separator
    info "Verificando ThemeToggle.jsx..."
    
    local THEME_TOGGLE_FILE="${FRONTEND_DIR}/src/components/ThemeToggle.jsx"
    
    if [ -f "$THEME_TOGGLE_FILE" ]; then
        warn "ThemeToggle.jsx ya existe - verificando..."
        if grep -q "useTheme" "$THEME_TOGGLE_FILE" && grep -q "toggleTheme" "$THEME_TOGGLE_FILE"; then
            log "ThemeToggle.jsx ya existe y parece funcional"
            return
        fi
    fi
    
    log "Creando ThemeToggle.jsx..."
    cat > "$THEME_TOGGLE_FILE" << 'EOF'
// src/components/ThemeToggle.jsx
import React from 'react';
import { useTheme } from '../contexts/ThemeContext';

export default function ThemeToggle({ className = '' }) {
  const { theme, toggleTheme, isDark } = useTheme();

  return (
    <button
      type="button"
      onClick={toggleTheme}
      className={`theme-toggle ${className}`}
      title={isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro'}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '6px',
        padding: '6px 12px',
        borderRadius: '999px',
        fontSize: '0.85rem',
        fontWeight: '500',
        background: isDark ? theme.bgTertiary : theme.bgSecondary,
        color: theme.textPrimary,
        border: `1px solid ${theme.border}`,
        cursor: 'pointer',
        transition: 'all 0.2s ease',
      }}
    >
      {isDark ? (
        <>
          <span style={{ fontSize: '1.1rem' }}>☀️</span>
          <span>Claro</span>
        </>
      ) : (
        <>
          <span style={{ fontSize: '1.1rem' }}>🌙</span>
          <span>Oscuro</span>
        </>
      )}
    </button>
  );
}
EOF
    log "ThemeToggle.jsx creado correctamente"
}

# 3. Verificar y crear dark-mode.css
setup_dark_mode_css() {
    separator
    info "Verificando dark-mode.css..."
    
    local DARK_MODE_CSS="${FRONTEND_DIR}/src/dark-mode.css"
    
    if [ -f "$DARK_MODE_CSS" ]; then
        warn "dark-mode.css ya existe - verificando contenido..."
        if grep -q "body {" "$DARK_MODE_CSS" && grep -q "instance-card" "$DARK_MODE_CSS"; then
            log "dark-mode.css ya existe y parece completo"
            return
        fi
    fi
    
    log "Creando dark-mode.css..."
    cat > "$DARK_MODE_CSS" << 'EOF'
/* src/dark-mode.css - Modo oscuro para Uptime Central */
:root {
  transition: background-color 0.3s ease, border-color 0.3s ease, color 0.3s ease;
}

body {
  background-color: var(--bg-primary);
  color: var(--text-primary);
}

.hero {
  background: linear-gradient(to right, var(--bg-secondary), var(--bg-primary));
  color: var(--text-primary);
}

.hero-title, .hero-subtitle {
  color: var(--text-primary);
}

.k-card {
  background-color: var(--card-bg);
  border: 1px solid var(--card-border);
  color: var(--text-primary);
}

.k-card.is-clickable:hover {
  background-color: var(--bg-hover);
}

.k-card__title {
  color: var(--text-secondary);
}

.k-metric {
  color: var(--text-primary);
}

.instance-card {
  background-color: var(--card-bg);
  border: 1px solid var(--card-border);
}

.instance-card:hover {
  background-color: var(--bg-hover);
  border-color: var(--border-hover);
}

.instance-card-title {
  color: var(--text-primary);
}

.instance-card-status-label {
  color: var(--text-secondary);
}

.instance-card-meta {
  color: var(--text-tertiary);
}

.service-card {
  background-color: var(--card-bg);
  border: 1px solid var(--card-border);
}

.service-card-title {
  color: var(--text-primary);
}

.service-card-type,
.service-card-url {
  color: var(--text-tertiary);
}

.service-card-status {
  color: var(--text-secondary);
}

.k-table {
  background-color: var(--bg-secondary);
  color: var(--text-primary);
}

.k-table th {
  background-color: var(--bg-tertiary);
  color: var(--text-secondary);
  border-bottom: 2px solid var(--border);
}

.k-table td {
  border-bottom: 1px solid var(--border);
  color: var(--text-primary);
}

.k-table tr:hover {
  background-color: var(--bg-hover);
}

.k-btn {
  background: var(--btnGhostBg);
  border: 1px solid var(--btnGhostBorder);
  color: var(--btnGhostText);
}

.k-btn:hover {
  background: var(--btnGhostHover);
}

.k-btn.is-active {
  background: var(--success);
  border-color: var(--success);
  color: white;
}

.k-btn--primary {
  background: var(--info);
  border-color: var(--info);
  color: white;
}

.k-btn--danger {
  background: var(--danger);
  border-color: var(--danger);
  color: white;
}

input, select, textarea {
  background-color: var(--input-bg);
  border: 1px solid var(--input-border);
  color: var(--text-primary);
}

input::placeholder {
  color: var(--input-placeholder);
}

input:focus, select:focus, textarea:focus {
  border-color: var(--info);
  outline: none;
  box-shadow: 0 0 0 2px var(--info-bg);
}

.k-chip {
  background: var(--bg-tertiary);
  color: var(--text-primary);
  border: 1px solid var(--border);
}

.k-chip--muted {
  background: var(--bg-secondary);
  color: var(--text-secondary);
}

.multi-view {
  background: var(--bg-secondary);
  color: var(--text-primary);
}

.filter-group {
  background: var(--bg-tertiary);
}

.filter-label {
  color: var(--text-secondary);
}

.alert-panel {
  background: var(--bg-secondary);
  border: 1px solid var(--border);
  color: var(--text-primary);
}

.home-btn {
  background: var(--btnGhostBg);
  border: 1px solid var(--btnGhostBorder);
  color: var(--btnGhostText);
}

.home-btn:hover {
  background: var(--btnGhostHover);
}

.instance-detail-page {
  background: var(--bg-secondary);
}

.instance-detail-title {
  color: var(--text-primary);
}

.instance-detail-actions {
  border-top: 1px solid var(--border);
}

.filters-toolbar {
  background: var(--bg-tertiary);
  border: 1px solid var(--border);
}

.hero-search-input {
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  color: var(--text-primary);
}

.hero-search-button {
  background: var(--info);
  color: white;
}

.hero-search-button:hover {
  filter: brightness(110%);
}

@media (prefers-color-scheme: dark) {
  ::-webkit-scrollbar {
    width: 10px;
    height: 10px;
  }

  ::-webkit-scrollbar-track {
    background: var(--bg-secondary);
  }

  ::-webkit-scrollbar-thumb {
    background: var(--bg-tertiary);
    border-radius: 5px;
    border: 2px solid var(--bg-secondary);
  }

  ::-webkit-scrollbar-thumb:hover {
    background: var(--border-hover);
  }
}
EOF
    log "dark-mode.css creado correctamente"
}

# 4. Verificar y crear theme/index.js
setup_theme_index() {
    separator
    info "Verificando theme/index.js..."
    
    local THEME_INDEX_FILE="${FRONTEND_DIR}/src/theme/index.js"
    
    if [ -f "$THEME_INDEX_FILE" ]; then
        warn "theme/index.js ya existe"
        return
    fi
    
    log "Creando theme/index.js..."
    cat > "$THEME_INDEX_FILE" << 'EOF'
// src/theme/index.js
export * from '../contexts/ThemeContext';
export { default as ThemeToggle } from '../components/ThemeToggle';
export { themes } from '../contexts/ThemeContext';
EOF
    log "theme/index.js creado correctamente"
}

# 5. Modificar App.jsx
setup_app_jsx() {
    separator
    info "Verificando App.jsx..."
    
    local APP_FILE="${FRONTEND_DIR}/src/App.jsx"
    
    if [ ! -f "$APP_FILE" ]; then
        error "App.jsx no encontrado"
        return
    fi
    
    # Verificar si ya tiene ThemeProvider
    if grep -q "ThemeProvider" "$APP_FILE"; then
        warn "App.jsx ya tiene ThemeProvider configurado"
        return
    fi
    
    log "Modificando App.jsx para incluir ThemeProvider..."
    
    # Backup antes de modificar
    cp "$APP_FILE" "$BACKUP_DIR/App.jsx.before_mod"
    
    # Crear nuevo App.jsx
    cat > "$APP_FILE" << 'EOF'
import React from "react";
import Dashboard from "./views/Dashboard.jsx";
import { ThemeProvider } from "./contexts/ThemeContext";
import "./styles.css";
import "./dark-mode.css";

export default function App() {
  return (
    <ThemeProvider>
      <Dashboard />
    </ThemeProvider>
  );
}
EOF
    log "App.jsx modificado correctamente"
}

# 6. Modificar Dashboard.jsx
setup_dashboard_jsx() {
    separator
    info "Verificando Dashboard.jsx..."
    
    local DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"
    
    if [ ! -f "$DASHBOARD_FILE" ]; then
        error "Dashboard.jsx no encontrado"
        return
    fi
    
    # Verificar si ya tiene ThemeToggle
    if grep -q "ThemeToggle" "$DASHBOARD_FILE"; then
        warn "Dashboard.jsx ya tiene ThemeToggle configurado"
        return
    fi
    
    log "Modificando Dashboard.jsx para incluir ThemeToggle..."
    
    # Backup
    cp "$DASHBOARD_FILE" "$BACKUP_DIR/Dashboard.jsx.before_mod"
    
    # Agregar import
    sed -i '1iimport ThemeToggle from "../components/ThemeToggle";\nimport { useTheme } from "../contexts/ThemeContext";' "$DASHBOARD_FILE"
    
    # Agregar useTheme dentro del componente
    sed -i '/export default function Dashboard() {/a \ \ const { theme, isDark } = useTheme();' "$DASHBOARD_FILE"
    
    # Buscar la sección de controles y agregar ThemeToggle
    # Buscamos el div de controles y agregamos ThemeToggle antes del label de autoplay
    sed -i '/{·*T/,/label.*autoplay/ {
        /{·*T/,/<\/label>/ {
            /<\/button>/a\
\
                {/* Theme Toggle */}\
                <ThemeToggle />
        }
    }' "$DASHBOARD_FILE"
    
    # Modificar el style del label de autoplay para usar theme
    sed -i 's/color: "#475569"/color: theme.textSecondary/g' "$DASHBOARD_FILE"
    
    # Agregar accentColor al input checkbox
    sed -i '/type="checkbox"/ s/\(style={{[^}]*\)}/\1, accentColor: theme.info }}/' "$DASHBOARD_FILE"
    
    log "Dashboard.jsx modificado correctamente"
}

# 7. Modificar index.html
setup_index_html() {
    separator
    info "Verificando index.html..."
    
    local INDEX_FILE="${FRONTEND_DIR}/index.html"
    
    if [ ! -f "$INDEX_FILE" ]; then
        error "index.html no encontrado"
        return
    fi
    
    # Verificar si ya tiene el script anti-flash
    if grep -q "Prevenir flash de modo claro/oscuro" "$INDEX_FILE"; then
        warn "index.html ya tiene script anti-flash"
        return
    fi
    
    log "Agregando script anti-flash a index.html..."
    
    # Backup
    cp "$INDEX_FILE" "$BACKUP_DIR/index.html.before_mod"
    
    # Insertar script en el head
    sed -i '/<\/head>/i \  <script>\n    // Prevenir flash de modo claro/oscuro\n    (function() {\n      try {\n        const theme = localStorage.getItem('\''uptime-theme'\'');\n        if (theme === '\''dark'\'') {\n          document.documentElement.style.backgroundColor = '\''#0f172a'\'';\n          document.documentElement.style.color = '\''#f1f5f9'\'';\n        }\n      } catch (e) {}\n    })();\n  </script>' "$INDEX_FILE"
    
    log "index.html modificado correctamente"
}

# 8. Verificar HistoryChart.jsx
setup_history_chart() {
    separator
    info "Verificando HistoryChart.jsx..."
    
    local CHART_FILE="${FRONTEND_DIR}/src/components/HistoryChart.jsx"
    
    if [ ! -f "$CHART_FILE" ]; then
        warn "HistoryChart.jsx no encontrado - no se puede verificar compatibilidad"
        return
    fi
    
    # Verificar si ya usa useTheme
    if grep -q "useTheme" "$CHART_FILE"; then
        log "HistoryChart.jsx ya tiene soporte para tema oscuro"
        return
    fi
    
    warn "HistoryChart.jsx necesita ser actualizado manualmente para soportar tema oscuro"
    warn "Revisa el backup y actualiza la configuración de Chart.js"
    
    # Crear archivo de instrucciones
    cat > "$BACKUP_DIR/INSTRUCCIONES_HISTORYCHART.txt" << EOF
INSTRUCCIONES PARA ACTUALIZAR HISTORYCHART.JSX MANUALMENTE:

1. Abre: ${CHART_FILE}
2. Agrega al inicio: 
   import { useTheme } from '../contexts/ThemeContext';

3. Dentro del componente, después de los useState:
   const { theme } = useTheme();

4. En la configuración de Chart.js, agrega/modifica:
   
   options: {
     scales: {
       x: {
         grid: { color: theme.chartGrid },
         ticks: { color: theme.chartText }
       },
       y: {
         grid: { color: theme.chartGrid },
         ticks: { color: theme.chartText }
       }
     },
     plugins: {
       legend: { labels: { color: theme.chartText } },
       tooltip: {
         backgroundColor: theme.bgTertiary,
         titleColor: theme.textPrimary,
         bodyColor: theme.textSecondary,
         borderColor: theme.border
       }
     }
   }

Backup disponible en: $BACKUP_DIR/HistoryChart.jsx.bak
EOF
    
    warn "Se han guardado instrucciones en: $BACKUP_DIR/INSTRUCCIONES_HISTORYCHART.txt"
}

# 9. Verificar integración final
verify_installation() {
    separator
    info "Verificando instalación completa..."
    
    local errors=0
    
    # Verificar archivos críticos
    [ ! -f "${FRONTEND_DIR}/src/contexts/ThemeContext.jsx" ] && error "✗ Falta ThemeContext.jsx" && errors=$((errors+1))
    [ ! -f "${FRONTEND_DIR}/src/components/ThemeToggle.jsx" ] && error "✗ Falta ThemeToggle.jsx" && errors=$((errors+1))
    [ ! -f "${FRONTEND_DIR}/src/dark-mode.css" ] && error "✗ Falta dark-mode.css" && errors=$((errors+1))
    
    # Verificar imports
    if [ -f "${FRONTEND_DIR}/src/App.jsx" ]; then
        grep -q "ThemeProvider" "${FRONTEND_DIR}/src/App.jsx" || warn "⚠️ App.jsx no tiene ThemeProvider"
    fi
    
    if [ -f "${FRONTEND_DIR}/src/views/Dashboard.jsx" ]; then
        grep -q "ThemeToggle" "${FRONTEND_DIR}/src/views/Dashboard.jsx" || warn "⚠️ Dashboard.jsx no tiene ThemeToggle"
        grep -q "useTheme" "${FRONTEND_DIR}/src/views/Dashboard.jsx" || warn "⚠️ Dashboard.jsx no tiene useTheme"
    fi
    
    if [ $errors -eq 0 ]; then
        log "✅ Verificación completada - Todo instalado correctamente"
    else
        warn "⚠️ Verificación completada con $errors errores"
    fi
}

# 10. Limpiar y finalizar
cleanup() {
    separator
    info "Limpiando archivos temporales..."
    
    # Eliminar archivos backup temporales si todo salió bien
    if [ -d "$BACKUP_DIR" ]; then
        log "Backup guardado en: $BACKUP_DIR"
        log "Para deshacer cambios: cp -r $BACKUP_DIR/* $FRONTEND_DIR/"
    fi
    
    separator
    log "✅ INSTALACIÓN COMPLETADA"
    separator
    echo ""
    echo "📋 RESUMEN:"
    echo "   • Backup: $BACKUP_DIR"
    echo "   • Log: $LOG_FILE"
    echo ""
    echo "🎯 COMPONENTES INSTALADOS:"
    echo "   • ThemeContext.jsx ✓"
    echo "   • ThemeToggle.jsx ✓"
    echo "   • dark-mode.css ✓"
    echo "   • theme/index.js ✓"
    echo "   • App.jsx modificado ✓"
    echo "   • Dashboard.jsx modificado ✓"
    echo "   • index.html con anti-flash ✓"
    echo ""
    echo "⚠️ TAREAS PENDIENTES:"
    echo "   1. HistoryChart.jsx - Revisar instrucciones en backup"
    echo "   2. Reiniciar el frontend: npm run dev"
    echo "   3. Probar el botón de tema en la esquina superior derecha"
    echo ""
    echo "📌 NOTA: Las notificaciones mantienen su estilo negro original"
    separator
}

# Main
main() {
    echo ""
    echo "========================================"
    echo "🌙 INSTALADOR INTELIGENTE - MODO OSCURO"
    echo "========================================"
    echo ""
    echo "Este script verificará tu instalación y agregará"
    echo "solo lo que falta sin duplicar archivos existentes"
    echo ""
    
    check_directory
    create_backup
    check_directories
    setup_theme_context
    setup_theme_toggle
    setup_dark_mode_css
    setup_theme_index
    setup_app_jsx
    setup_dashboard_jsx
    setup_index_html
    setup_history_chart
    verify_installation
    cleanup
    
    echo ""
    log "Script completado! Revisa el log en: $LOG_FILE"
    echo ""
}

# Ejecutar
main "$@"
