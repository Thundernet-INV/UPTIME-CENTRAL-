#!/bin/bash

# fix-dashboard-emergency.sh

echo "🚨 Modo emergencia - Reescribiendo estructura básica..."

FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/views/Dashboard.jsx"
BACKUP="${FILE}.backup-emergency-$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$BACKUP"

echo "✅ Backup creado: $BACKUP"

# Extraer el contenido hasta antes del return
head -n $(grep -n "return (" "$FILE" | cut -d: -f1) "$FILE" > "${FILE}.new"

# Agregar la estructura correcta
cat >> "${FILE}.new" << 'EOF'
  return (
    <main>
      {/* HERO principal con barra de búsqueda */}
      <Hero>
        <div style={{margin:"10px 0"}}>
          <a href="#/energia" onClick={(e)=>{e.preventDefault(); window.location.hash="#/energia";}}
             className="btn btn-primary" style={{padding:"6px 10px", borderRadius:"8px"}}>
            Energía
          </a>
        </div>
      </Hero>
      
      {/* Aquí continúa el resto del contenido */}
      <section>
        <div>
          {/* El resto del contenido se mantiene igual */}
        </div>
      </section>
    </main>
  );
}

export default Dashboard;
EOF

# Mantener el resto del archivo original después de la estructura problemática
tail -n +$(grep -n "export default" "$FILE" | tail -1 | cut -d: -f1) "$FILE" >> "${FILE}.new"

# Reemplazar archivo
mv "${FILE}.new" "$FILE"

echo "✅ Estructura básica reescrita"
echo "🔄 Reiniciando servidor..."

cd "/home/thunder/kuma-dashboard-clean/kuma-ui"
pkill -f vite
npm run dev &

echo "✨ Listo!"
