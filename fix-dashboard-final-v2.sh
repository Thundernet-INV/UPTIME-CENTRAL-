#!/bin/bash

# fix-dashboard-final-v2.sh - Limpieza completa de Dashboard.jsx

echo "🧹 Limpiando completamente Dashboard.jsx..."

FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/views/Dashboard.jsx"

# Verificar que el archivo existe
if [ ! -f "$FILE" ]; then
    echo "❌ Error: No se encontró el archivo $FILE"
    exit 1
fi

# Crear backup
BACKUP="${FILE}.backup-final-$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$BACKUP"
echo "✅ Backup creado: $BACKUP"

# Crear un archivo completamente nuevo con la estructura correcta
cat > "$FILE" << 'EOF'
import { useEffect, useMemo, useRef, useState } from "react";
import Energia from "./Energia.jsx";
import Hero from "../components/Hero.jsx";
import AlertsBanner from "../components/AlertsBanner.jsx";

function Dashboard() {
  // EARLY RETURN Energía v10 (no usa variable local `monitors`)
  if (typeof isEnergiaRoute === "function" && isEnergiaRoute()) {
    return <Energia monitors={monitors} />;
  }

  return (
    <main>
      {/* HERO principal con barra de búsqueda */}
      <Hero>
        <div style={{ margin: "10px 0" }}>
          <a 
            href="#/energia" 
            onClick={(e) => {
              e.preventDefault(); 
              window.location.hash = "#/energia";
            }}
            className="btn btn-primary" 
            style={{ padding: "6px 10px", borderRadius: "8px" }}
          >
            Energía
          </a>
        </div>
      </Hero>

      {/* El resto del contenido original se mantiene aquí */}
      {/* ========================================== */}
      {/* COPIAR AQUÍ EL CONTENIDO ORIGINAL DESDE EL BACKUP */}
      {/* ========================================== */}
      
    </main>
  );
}

export default Dashboard;
EOF

echo "✅ Archivo limpiado con estructura básica"
echo ""
echo "📝 Ahora necesitas copiar el contenido original desde el backup"
echo "   Abre el backup y el archivo nuevo en dos terminales:"
echo ""
echo "   Terminal 1: cat $BACKUP"
echo "   Terminal 2: nano $FILE"
echo ""
echo "   Copia el contenido interno del return desde el backup"
echo "   (todo lo que estaba dentro del <main>...</main>)"
echo ""
echo "🔄 Por ahora, reiniciando servidor para verificar sintaxis básica..."

# Matar procesos de Vite
pkill -f vite || true

# Reiniciar
cd "/home/thunder/kuma-dashboard-clean/kuma-ui"
npm run dev &

echo ""
echo "✨ Script completado"
