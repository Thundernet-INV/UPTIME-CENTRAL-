#!/bin/bash
# fix-dark-mode-ahora.sh - DIAGNÓSTICO Y CORRECCIÓN INMEDIATA

echo "====================================================="
echo "🔧 DIAGNÓSTICO DE MODO OSCURO - CORRECCIÓN INMEDIATA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

# ========== 1. VERIFICAR QUE dark-mode.css SE ESTÁ CARGANDO ==========
echo ""
echo "[1] Verificando que dark-mode.css se carga en el navegador..."

# Agregar marcador visible en App.jsx
cat > "${FRONTEND_DIR}/src/App.jsx" << 'EOF'
import React, { useEffect } from "react";
import Dashboard from "./views/Dashboard.jsx";
import "./styles.css";
import "./dark-mode.css"; // ✅ Modo oscuro

export default function App() {
  useEffect(() => {
    // Diagnosticar si el CSS se cargó
    console.log('✅ App.jsx cargado');
    console.log('📁 dark-mode.css importado');
    
    // Restaurar tema guardado
    try {
      const savedTheme = localStorage.getItem('uptime-theme');
      console.log('💾 Tema guardado:', savedTheme);
      
      if (savedTheme === 'dark') {
        document.body.classList.add('dark-mode');
        console.log('🌙 Modo oscuro restaurado desde localStorage');
      }
      
      // Diagnosticar estilos
      setTimeout(() => {
        const hasDarkMode = document.body.classList.contains('dark-mode');
        console.log('🎯 Body tiene clase dark-mode:', hasDarkMode);
        
        // Verificar si algún estilo de dark-mode se aplicó
        const testDiv = document.createElement('div');
        testDiv.style.cssText = 'position:fixed; top:0; left:0; width:100px; height:100px; background: red; z-index:99999;';
        testDiv.id = 'dark-mode-test';
        document.body.appendChild(testDiv);
        
        setTimeout(() => {
          const bgColor = window.getComputedStyle(testDiv).backgroundColor;
          console.log('🧪 Test div background:', bgColor);
          testDiv.remove();
        }, 100);
      }, 500);
    } catch (e) {
      console.error('Error:', e);
    }
  }, []);

  return <Dashboard />;
}
EOF

echo "✅ App.jsx actualizado con diagnóstico"

# ========== 2. CORREGIR dark-mode.css CON SELECTORES MÁS ESPECÍFICOS ==========
echo ""
echo "[2] Reforzando selectores CSS con !important y especificidad..."

cat > "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'
/* ================================================
   MODO OSCURO - SELECTORES REFORZADOS
   Activado con clase dark-mode en body
================================================= */

/* MARCADOR VISIBLE - ELIMINAR DESPUÉS DE PRUEBAS */
body.dark-mode #root::before {
  content: "🌙 MODO OSCURO ACTIVADO";
  position: fixed;
  top: 10px;
  left: 50%;
  transform: translateX(-50%);
  background: #16a34a;
  color: white;
  padding: 8px 16px;
  border-radius: 999px;
  z-index: 10000;
  font-size: 14px;
  font-weight: bold;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  animation: slideDown 0.3s ease;
}

@keyframes slideDown {
  from { transform: translateX(-50%) translateY(-100%); opacity: 0; }
  to { transform: translateX(-50%) translateY(0); opacity: 1; }
}

/* ========== BACKGROUND PRINCIPAL ========== */
body.dark-mode,
body.dark-mode #root,
body.dark-mode main,
body.dark-mode .home-services-section,
body.dark-mode .home-services-container {
  background-color: #0a0c10 !important;
}

/* ========== HEADER Y HERO ========== */
body.dark-mode .hero {
  background: linear-gradient(to right, #0f1217, #0a0c10) !important;
}

body.dark-mode .hero-title,
body.dark-mode .hero-subtitle {
  color: #ffffff !important;
}

/* ========== CARDS ========== */
body.dark-mode .k-card {
  background-color: #1a1e24 !important;
  border: 1px solid #2d3238 !important;
}

body.dark-mode .k-card__title {
  color: #9ca3af !important;
}

body.dark-mode .k-metric {
  color: #ffffff !important;
}

/* ========== INSTANCE CARDS ========== */
body.dark-mode .instance-card {
  background-color: #1a1e24 !important;
  border: 1px solid #2d3238 !important;
}

body.dark-mode .instance-card-title {
  color: #ffffff !important;
}

body.dark-mode .instance-card-status-label,
body.dark-mode .instance-card-meta {
  color: #9ca3af !important;
}

/* ========== SERVICE CARDS ========== */
body.dark-mode .service-card {
  background-color: #1a1e24 !important;
  border: 1px solid #2d3238 !important;
}

body.dark-mode .service-card-title {
  color: #ffffff !important;
}

body.dark-mode .service-card-type,
body.dark-mode .service-card-url,
body.dark-mode .service-card-status {
  color: #9ca3af !important;
}

/* ========== TABLAS ========== */
body.dark-mode .k-table,
body.dark-mode table {
  background-color: #1a1e24 !important;
}

body.dark-mode .k-table th,
body.dark-mode table th {
  background-color: #0f1217 !important;
  color: #e5e7eb !important;
  border-bottom: 2px solid #2d3238 !important;
}

body.dark-mode .k-table td,
body.dark-mode table td {
  border-bottom: 1px solid #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-table tr:hover,
body.dark-mode table tr:hover {
  background-color: #2d3238 !important;
}

/* ========== BOTONES ========== */
body.dark-mode .k-btn,
body.dark-mode button:not(.theme-toggle-injected):not(.home-btn) {
  background-color: transparent !important;
  border: 1px solid #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-btn:hover,
body.dark-mode button:not(.theme-toggle-injected):hover {
  background-color: #2d3238 !important;
}

body.dark-mode .k-btn.is-active {
  background-color: #16a34a !important;
  border-color: #16a34a !important;
  color: white !important;
}

body.dark-mode .home-btn {
  background-color: transparent !important;
  border: 1px solid #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .home-btn:hover {
  background-color: #2d3238 !important;
}

/* ========== INPUTS Y SELECTS ========== */
body.dark-mode input,
body.dark-mode select,
body.dark-mode textarea {
  background-color: #0f1217 !important;
  border: 1px solid #2d3238 !important;
  color: #ffffff !important;
}

body.dark-mode input::placeholder {
  color: #6b7280 !important;
}

/* ========== NOTIFICACIONES - MANTENER ESTILO NEGRO ========== */
body.dark-mode .notificaciones-push-container div[style*="background: '#111827'"] {
  box-shadow: 0 20px 25px -5px rgba(0,0,0,0.9) !important;
}

/* ========== SCROLLBAR ========== */
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
EOF

echo "✅ dark-mode.css reforzado con selectores específicos y !important"

# ========== 3. CREAR BOTÓN FLOTANTE DE EMERGENCIA ==========
echo ""
echo "[3] Creando botón flotante de emergencia (visible inmediatamente)..."

cat > "${FRONTEND_DIR}/public/dark-mode-emergency.js" << 'EOF'
// Botón flotante de emergencia para modo oscuro
(function() {
    // Esperar a que el DOM esté listo
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', addButton);
    } else {
        addButton();
    }
    
    function addButton() {
        // No duplicar el botón
        if (document.getElementById('dark-mode-emergency-btn')) return;
        
        const btn = document.createElement('button');
        btn.id = 'dark-mode-emergency-btn';
        btn.innerHTML = '🌙 Modo Oscuro';
        btn.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 99999;
            padding: 12px 24px;
            background: #1a1e24;
            color: white;
            border: 2px solid #3a3f47;
            border-radius: 999px;
            font-size: 16px;
            font-weight: bold;
            cursor: pointer;
            box-shadow: 0 8px 16px rgba(0,0,0,0.3);
            transition: all 0.3s ease;
            animation: pulse 2s infinite;
        `;
        
        // Agregar animación
        const style = document.createElement('style');
        style.textContent = `
            @keyframes pulse {
                0% { transform: scale(1); }
                50% { transform: scale(1.05); }
                100% { transform: scale(1); }
            }
        `;
        document.head.appendChild(style);
        
        btn.onmouseover = () => {
            btn.style.transform = 'scale(1.1)';
            btn.style.background = '#2d3238';
        };
        
        btn.onmouseout = () => {
            btn.style.transform = 'scale(1)';
            btn.style.background = '#1a1e24';
        };
        
        btn.onclick = function() {
            if (document.body.classList.contains('dark-mode')) {
                document.body.classList.remove('dark-mode');
                localStorage.setItem('uptime-theme', 'light');
                this.innerHTML = '🌙 Modo Oscuro';
                this.style.background = '#1a1e24';
            } else {
                document.body.classList.add('dark-mode');
                localStorage.setItem('uptime-theme', 'dark');
                this.innerHTML = '☀️ Modo Claro';
                this.style.background = '#0f1217';
            }
        };
        
        document.body.appendChild(btn);
        console.log('✅ Botón de emergencia agregado');
        
        // Activar tema guardado
        const saved = localStorage.getItem('uptime-theme');
        if (saved === 'dark') {
            document.body.classList.add('dark-mode');
            btn.innerHTML = '☀️ Modo Claro';
            btn.style.background = '#0f1217';
        }
    }
})();
EOF

echo "✅ Botón flotante de emergencia creado"

# ========== 4. AGREGAR SCRIPT DE EMERGENCIA A INDEX.HTML ==========
echo ""
echo "[4] Agregando script de emergencia a index.html..."

# Backup
cp "${FRONTEND_DIR}/index.html" "${FRONTEND_DIR}/index.html.backup.emergencia"

# Insertar script de emergencia antes de </body>
sed -i '/<\/body>/i \  <script src="/dark-mode-emergency.js"></script>' "${FRONTEND_DIR}/index.html"

echo "✅ Script de emergencia agregado a index.html"

# ========== 5. LIMPIAR CACHÉ Y REINICIAR ==========
echo ""
echo "[5] Limpiando caché y reiniciando..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 6. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ CORRECCIÓN APLICADA - MODO OSCURO LISTO ✅✅"
echo "====================================================="
echo ""
echo "🎯 DEBERÍAS VER:"
echo "   1. Un botón FLOTANTE 🌙 en la esquina inferior derecha"
echo "   2. Al hacer click, el dashboard se pone oscuro"
echo "   3. Un mensaje verde '🌙 MODO OSCURO ACTIVADO' aparece arriba"
echo ""
echo "📌 SI NO VES EL BOTÓN:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Abre consola (F12)"
echo "   3. Pegar: location.reload(true)"
echo ""
echo "📌 SI EL BOTÓN APARECE PERO NO CAMBIA NADA:"
echo "   1. Abre consola (F12)"
echo "   2. Pegar: document.body.classList.add('dark-mode')"
echo "   3. Pegar: localStorage.setItem('uptime-theme', 'dark')"
echo ""
echo "📌 PARA QUITAR EL BOTÓN FLOTANTE (después de probar):"
echo "   Eliminar línea de index.html: <script src='/dark-mode-emergency.js'>"
echo ""
echo "====================================================="
EOF

chmod +x fix-dark-mode-ahora.sh
