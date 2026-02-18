#!/bin/bash
# Renombrar Equipos.jsx a Equipos.jsx.bak y crear un enlace simbólico
cd /home/thunder/kuma-dashboard-clean/kuma-ui/src/views
if [ -f "Equipos.jsx" ] && [ ! -f "Equipos.jsx.bak" ]; then
    cp Equipos.jsx Equipos.jsx.bak
    echo "✅ Backup de Equipos.jsx creado"
fi

# Hacer que #/energia cargue Equipos.jsx (opcional - no necesario si ya funciona con #/equipos)
# Esto es solo informativo - la redirección ya se maneja en Dashboard.jsx
echo ""
echo "📋 NOTA: El botón Energia ahora apunta a #/equipos"
echo "   Si quieres que #/energia también funcione, agrega esta línea en Dashboard.jsx:"
echo "   if (hash.startsWith(\"#/energia\")) return { name: \"equipos\" };"
