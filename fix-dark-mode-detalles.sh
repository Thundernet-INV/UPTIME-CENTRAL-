#!/bin/bash
# fix-dark-mode-detalles.sh - CORREGIR MODO OSCURO PARA CHIPS Y SEARCHBAR

echo "====================================================="
echo "🌙 CORRIGIENDO MODO OSCURO - CHIPS Y SEARCHBAR"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_dark_detalles_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/dark-mode.css" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/SearchBar.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/Hero.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. ACTUALIZAR DARK-MODE.CSS ==========
echo "[2] Actualizando dark-mode.css con estilos corregidos..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== CHIPS - MODO OSCURO CORREGIDO ========== */
body.dark-mode .k-chip {
  background: transparent !important;
  border: 1px solid #e5e7eb !important;  /* Borde blanco */
  color: #ffffff !important;  /* Texto blanco */
}

body.dark-mode .k-chip--muted {
  background: transparent !important;
  border: 1px solid #e5e7eb !important;
  color: #ffffff !important;
}

body.dark-mode .k-chip strong {
  color: #ffffff !important;
  font-weight: 600;
}

body.dark-mode .k-chip .k-chip-action {
  color: #3b82f6 !important;  /* Botón azul */
  border-left: 1px solid #e5e7eb !important;
}

body.dark-mode .k-chip .k-chip-action:hover {
  color: #60a5fa !important;
  background: rgba(59, 130, 246, 0.1) !important;
}

/* ========== SEARCHBAR - MODO OSCURO CORREGIDO ========== */
body.dark-mode .hero-search-input {
  background: transparent !important;
  border: 1px solid #e5e7eb !important;  /* Borde blanco */
  color: #ffffff !important;  /* Texto blanco */
}

body.dark-mode .hero-search-input::placeholder {
  color: #9ca3af !important;  /* Placeholder gris claro */
  opacity: 1 !important;
}

body.dark-mode .hero-search-input:focus {
  border-color: #3b82f6 !important;  /* Borde azul al enfocar */
  outline: none !important;
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2) !important;
}

body.dark-mode .hero-search-button {
  background: #3b82f6 !important;
  color: white !important;
  border: 1px solid #3b82f6 !important;
}

body.dark-mode .hero-search-button:hover {
  background: #2563eb !important;
  border-color: #2563eb !important;
}

/* ========== TÍTULOS Y TEXTOS EN MODO OSCURO ========== */
body.dark-mode .hero-title,
body.dark-mode .hero-subtitle {
  color: #ffffff !important;
}

body.dark-mode .instance-detail-chip-row span[style*="color: var(--text-tertiary)"] {
  color: #9ca3af !important;
}

/* ========== SELECTORES DE TIEMPO - MODO OSCURO ========== */
body.dark-mode .instance-detail-header button[style*="background: var(--bg-tertiary)"] {
  background: transparent !important;
  border: 1px solid #e5e7eb !important;
  color: #ffffff !important;
}

body.dark-mode .instance-detail-header button[style*="background: var(--bg-tertiary)"]:hover {
  background: rgba(255, 255, 255, 0.1) !important;
}

body.dark-mode .instance-detail-header span[style*="color: var(--text-secondary)"] {
  color: #9ca3af !important;
}

/* ========== DROPDOWNS EN MODO OSCURO ========== */
body.dark-mode div[style*="position: absolute"][style*="background: white"] {
  background: #1f2937 !important;
  border-color: #374151 !important;
}

body.dark-mode div[style*="position: absolute"] button {
  color: #e5e7eb !important;
  border-bottom-color: #374151 !important;
}

body.dark-mode div[style*="position: absolute"] button:hover {
  background: #374151 !important;
}

body.dark-mode div[style*="position: absolute"] button[style*="background: #3b82f6"] {
  background: #2563eb !important;
  color: white !important;
}
EOF

echo "✅ dark-mode.css actualizado - chips y searchbar con borde blanco"
echo ""

# ========== 3. MEJORAR SEARCHBAR.JSX PARA MEJOR SOPORTE DARK MODE ==========
echo "[3] Mejorando SearchBar.jsx para modo oscuro..."

cat > "${FRONTEND_DIR}/src/components/SearchBar.jsx" << 'EOF'
import React, { useState } from 'react';

const SearchBar = ({ onSearch }) => {
  const [query, setQuery] = useState('');

  const handleSubmit = (event) => {
    event.preventDefault();
    if (onSearch) {
      onSearch(query);
    }
  };

  return (
    <form className="hero-search" onSubmit={handleSubmit} role="search" style={{ display: 'flex', width: '100%' }}>
      <label className="sr-only" htmlFor="hero-search-input">
        Buscar un servicio
      </label>
      <input
        id="hero-search-input"
        type="search"
        className="hero-search-input"
        placeholder="Busca un servicio (WhatsApp, YouTube, Instagram...)"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        style={{
          flex: 1,
          padding: '12px 16px',
          fontSize: '0.95rem',
          border: '1px solid var(--border, #e5e7eb)',
          borderRight: 'none',
          borderRadius: '8px 0 0 8px',
          outline: 'none',
          backgroundColor: 'var(--input-bg, white)',
          color: 'var(--text-primary, #1f2937)',
          transition: 'all 0.2s ease',
        }}
      />
      <button 
        type="submit" 
        className="hero-search-button"
        style={{
          padding: '12px 24px',
          background: 'var(--info, #3b82f6)',
          color: 'white',
          border: '1px solid var(--info, #3b82f6)',
          borderRadius: '0 8px 8px 0',
          fontSize: '0.95rem',
          fontWeight: '500',
          cursor: 'pointer',
          transition: 'all 0.2s ease',
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.background = 'var(--info-hover, #2563eb)';
          e.currentTarget.style.borderColor = 'var(--info-hover, #2563eb)';
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.background = 'var(--info, #3b82f6)';
          e.currentTarget.style.borderColor = 'var(--info, #3b82f6)';
        }}
      >
        Buscar
      </button>
    </form>
  );
};

export default SearchBar;
EOF

echo "✅ SearchBar.jsx mejorado"
echo ""

# ========== 4. MEJORAR HERO.JSX PARA MEJOR SOPORTE DARK MODE ==========
echo "[4] Mejorando Hero.jsx para modo oscuro..."

cat > "${FRONTEND_DIR}/src/components/Hero.jsx" << 'EOF'
import React from "react";
import SearchBar from "./SearchBar";

const Hero = ({ onSearch }) => {
  return (
    <section className="hero" aria-labelledby="hero-title" style={{
      background: 'linear-gradient(to right, var(--bg-secondary, #f9fafb), var(--bg-primary, white))',
      padding: '40px 24px',
      position: 'relative',
    }}>
      <div style={{ maxWidth: '1200px', margin: '0 auto', display: 'flex', alignItems: 'center', gap: '40px' }}>
        <img
          src="/ThunderDetector.png"
          alt="ThunderNet Logo"
          style={{ height: '60px', width: 'auto' }}
        />

        <div style={{ flex: 1 }}>
          <h1 id="hero-title" style={{
            margin: '0 0 12px 0',
            fontSize: '1.8rem',
            fontWeight: '600',
            color: 'var(--text-primary, #111827)',
          }}>
            Monitor de problemas e interrupciones en tiempo real
          </h1>

          <p style={{
            margin: '0 0 24px 0',
            fontSize: '1.1rem',
            color: 'var(--text-secondary, #4b5563)',
          }}>
            Te avisamos cuando tus servicios favoritos presentan incidencias.
          </p>

          <div role="search" style={{ maxWidth: '600px' }}>
            <SearchBar onSearch={onSearch} />
          </div>
        </div>
      </div>
    </section>
  );
};

export default Hero;
EOF

echo "✅ Hero.jsx mejorado"
echo ""

# ========== 5. LIMPIAR CACHÉ ==========
echo "[5] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"
echo ""

# ========== 6. REINICIAR FRONTEND ==========
echo "[6] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ MODO OSCURO CORREGIDO - BORDES BLANCOS ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🏷️ CHIPS (Mostrando: Google | Ver promedio):"
echo "      • Fondo: TRANSPARENTE"
echo "      • Borde: BLANCO (#e5e7eb)"
echo "      • Texto: BLANCO (#ffffff)"
echo "      • Botón: AZUL (#3b82f6)"
echo ""
echo "   2. 🔍 SEARCHBAR (Buscador):"
echo "      • Input: TRANSPARENTE con borde BLANCO"
echo "      • Texto: BLANCO"
echo "      • Placeholder: GRIS CLARO (#9ca3af)"
echo "      • Botón: AZUL con hover"
echo ""
echo "   3. 🕒 SELECTORES DE TIEMPO:"
echo "      • Fondo: TRANSPARENTE"
echo "      • Borde: BLANCO"
echo "      • Texto: BLANCO"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Activa el modo oscuro (botón 🌙)"
echo "   3. ✅ CHIPS: 'Mostrando: Google' debe tener BORDE BLANCO"
echo "   4. ✅ SEARCHBAR: Input debe tener BORDE BLANCO y texto BLANCO"
echo "   5. ✅ SELECTORES: Botones de tiempo con BORDE BLANCO"
echo ""
echo "🎨 TODOS LOS ELEMENTOS AHORA TIENEN:"
echo "   • Borde blanco (#e5e7eb)"
echo "   • Texto blanco (#ffffff)"
echo "   • Fondo transparente"
echo "   • Hover effects sutiles"
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
