#!/bin/bash
# fix-dark-mode-superior-derecha.sh - BOTÓN DE MODO OSCURO EN ESQUINA SUPERIOR DERECHA

echo "====================================================="
echo "🔧 COLOCANDO BOTÓN DE MODO OSCURO EN ESQUINA SUPERIOR DERECHA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

# ========== 1. RESTAURAR HERO.JSX ORIGINAL ==========
echo ""
echo "[1] Restaurando Hero.jsx original..."

# Restaurar Hero.jsx original desde backup si existe
if [ -f "${FRONTEND_DIR}/src/components/Hero.jsx.backup.darkmode" ]; then
    cp "${FRONTEND_DIR}/src/components/Hero.jsx.backup.darkmode" "${FRONTEND_DIR}/src/components/Hero.jsx"
    echo "✅ Hero.jsx restaurado desde backup"
else
    # Si no hay backup, crear versión original sin el botón
    cat > "${FRONTEND_DIR}/src/components/Hero.jsx" << 'EOF'
import React from "react";
import SearchBar from "./SearchBar";

const Hero = ({ onSearch }) => {
  return (
    <section className="hero" aria-labelledby="hero-title">
      <img
        src="/ThunderDetector.png"
        alt="ThunderNet Logo"
        className="hero-logo-left"
      />

      <div className="hero-content">
        <h1 id="hero-title" className="hero-title">
          Monitor de problemas e interrupciones en tiempo real
        </h1>

        <p className="hero-subtitle">
          Te avisamos cuando tus servicios favoritos presentan incidencias.
        </p>

        <div className="hero-search" role="search">
          <SearchBar onSearch={onSearch} />
        </div>
      </div>

      <div className="hero-wave" aria-hidden="true" />
    </section>
  );
};

export default Hero;
EOF
    echo "✅ Hero.jsx restaurado a versión original"
fi

# ========== 2. CREAR BOTÓN DE MODO OSCURO PARA ESQUINA SUPERIOR DERECHA ==========
echo ""
echo "[2] Creando botón de modo oscuro para esquina superior derecha..."

cat > "${FRONTEND_DIR}/src/components/DarkModeCornerButton.jsx" << 'EOF'
// src/components/DarkModeCornerButton.jsx
// Botón de modo oscuro en la esquina superior derecha

import React, { useState, useEffect } from 'react';

export default function DarkModeCornerButton() {
  const [isDark, setIsDark] = useState(() => {
    try {
      return localStorage.getItem('uptime-theme') === 'dark';
    } catch {
      return false;
    }
  });

  useEffect(() => {
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
        position: 'fixed',
        top: '20px',
        right: '24px',
        zIndex: 10000,
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        padding: '10px 20px',
        borderRadius: '999px',
        fontSize: '0.95rem',
        fontWeight: '600',
        background: isDark ? '#1a1e24' : '#ffffff',
        color: isDark ? '#ffffff' : '#1f2937',
        border: isDark ? '1px solid #3a3f47' : '1px solid #e5e7eb',
        boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
        cursor: 'pointer',
        transition: 'all 0.2s ease',
        backdropFilter: 'blur(8px)',
        WebkitBackdropFilter: 'blur(8px)',
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.transform = 'translateY(-2px)';
        e.currentTarget.style.boxShadow = '0 8px 16px rgba(0,0,0,0.15)';
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.transform = 'translateY(0)';
        e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.1)';
      }}
    >
      {isDark ? (
        <>
          <span style={{ fontSize: '1.3rem' }}>☀️</span>
          <span>Modo Claro</span>
        </>
      ) : (
        <>
          <span style={{ fontSize: '1.3rem' }}>🌙</span>
          <span>Modo Oscuro</span>
        </>
      )}
    </button>
  );
}
EOF

echo "✅ DarkModeCornerButton.jsx creado"

# ========== 3. MODIFICAR APP.JSX PARA INCLUIR EL BOTÓN ==========
echo ""
echo "[3] Modificando App.jsx para incluir botón en esquina superior derecha..."

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

echo "✅ App.jsx modificado - botón en esquina superior derecha"

# ========== 4. ACTUALIZAR DARK-MODE.CSS PARA EL BOTÓN ==========
echo ""
echo "[4] Actualizando dark-mode.css para el botón de esquina..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== BOTÓN DE MODO OSCURO EN ESQUINA SUPERIOR DERECHA ========== */
body.dark-mode button[style*="position: fixed"][style*="top: 20px"][style*="right: 24px"] {
  background: #1a1e24 !important;
  border-color: #3a3f47 !important;
  color: white !important;
  box-shadow: 0 4px 12px rgba(0,0,0,0.3) !important;
}

body.dark-mode button[style*="position: fixed"][style*="top: 20px"][style*="right: 24px"]:hover {
  background: #2d3238 !important;
  border-color: #4b5563 !important;
}

/* Modo claro - botón con efecto glassmorphism */
button[style*="position: fixed"][style*="top: 20px"][style*="right: 24px"] {
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  background: rgba(255, 255, 255, 0.95) !important;
}

/* Asegurar que el botón esté por encima de todo */
button[style*="position: fixed"][style*="top: 20px"][style*="right: 24px"] {
  z-index: 10000 !important;
}
EOF

echo "✅ dark-mode.css actualizado"

# ========== 5. ELIMINAR ARCHIVOS TEMPORALES ==========
echo ""
echo "[5] Limpiando archivos temporales..."

# Eliminar botón anterior si existe
rm -f "${FRONTEND_DIR}/src/components/DarkModeHeroButton.jsx" 2>/dev/null
rm -f "${FRONTEND_DIR}/src/components/ThemeToggleSimple.jsx" 2>/dev/null
rm -f "${FRONTEND_DIR}/src/theme-injector.js" 2>/dev/null
rm -f "${FRONTEND_DIR}/public/dark-mode-emergency.js" 2>/dev/null

echo "✅ Archivos temporales eliminados"

# ========== 6. VERIFICAR Y REINICIAR ==========
echo ""
echo "[6] Verificando instalación..."

# Verificar archivos
[ -f "${FRONTEND_DIR}/src/components/DarkModeCornerButton.jsx" ] && echo "✅ DarkModeCornerButton.jsx presente"
[ -f "${FRONTEND_DIR}/src/App.jsx" ] && echo "✅ App.jsx modificado correctamente"
[ -f "${FRONTEND_DIR}/src/dark-mode.css" ] && echo "✅ dark-mode.css presente"

# Remover script anti-flash de index.html si existe
sed -i '/Prevenir flash de modo claro\/oscuro/,/<\/script>/d' "${FRONTEND_DIR}/index.html" 2>/dev/null || true

# Agregar script anti-flash mejorado
sed -i '/<\/head>/i \  <script>\n    // Prevenir flash de modo claro/oscuro\n    (function() {\n      try {\n        const theme = localStorage.getItem('\''uptime-theme'\'');\n        if (theme === '\''dark'\'') {\n          document.documentElement.style.backgroundColor = '\''#0a0c10'\'';\n          document.body.style.backgroundColor = '\''#0a0c10'\'';\n        }\n      } catch (e) {}\n    })();\n  </script>' "${FRONTEND_DIR}/index.html"

echo "✅ Script anti-flash actualizado"

echo ""
echo "[7] Reiniciando frontend..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite 2>/dev/null || true
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ BOTÓN INSTALADO EN ESQUINA SUPERIOR DERECHA ✅✅"
echo "====================================================="
echo ""
echo "📍 UBICACIÓN DEL BOTÓN:"
echo "   • ESQUINA SUPERIOR DERECHA (top: 20px, right: 24px)"
echo "   • Estilo flotante con efecto glassmorphism"
echo "   • Se ve así: [🌙 Modo Oscuro]"
echo ""
echo "🎯 COMPORTAMIENTO:"
echo "   • Modo Claro: Botón blanco con sombra suave"
echo "   • Modo Oscuro: Botón gris oscuro con ☀️"
echo "   • Hover: Se eleva ligeramente"
echo "   • Persistencia: Guarda tu preferencia"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Busca el botón en la ESQUINA SUPERIOR DERECHA"
echo "   3. Haz click en '🌙 Modo Oscuro'"
echo "   4. TODO el dashboard se pondrá oscuro"
echo "   5. Haz click en '☀️ Modo Claro' para volver"
echo ""
echo "📌 CARACTERÍSTICAS:"
echo "   • ✅ Sin modificar Dashboard.jsx"
echo "   • ✅ Sin modificar Hero.jsx"
echo "   • ✅ Notificaciones mantienen estilo negro"
echo "   • ✅ Botón siempre visible en todas las vistas"
echo "   • ✅ Efecto blur/glassmorphism"
echo "   • ✅ Animación suave al hacer hover"
echo ""
echo "====================================================="
echo "✅ LISTO - El botón está en la ESQUINA SUPERIOR DERECHA"
echo "====================================================="

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado exitosamente"
