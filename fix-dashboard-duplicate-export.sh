#!/bin/bash

# fix-dashboard-duplicate-export.sh - Corrige las exportaciones duplicadas

echo "🔧 Corrigiendo exportaciones duplicadas en Dashboard.jsx..."

FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/views/Dashboard.jsx"

# Verificar que el archivo existe
if [ ! -f "$FILE" ]; then
    echo "❌ Error: No se encontró el archivo $FILE"
    exit 1
fi

# Crear backup
BACKUP="${FILE}.backup-dup-$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$BACKUP"
echo "✅ Backup creado: $BACKUP"

# Crear archivo temporal
TEMP_FILE="${FILE}.tmp"

# Procesar el archivo para eliminar la exportación duplicada
awk '
    # Si encontramos "export default Dashboard;" (la primera exportación)
    /export default Dashboard;/ { 
        print "// " $0 " [ELIMINADA - duplicada]"
        next 
    }
    # Si encontramos "export default function Dashboard()" y ya pasamos la primera
    /export default function Dashboard\(\)/ { 
        print $0
        in_function = 1
        next
    }
    # Mantener el resto del archivo
    { print }
' "$FILE" > "$TEMP_FILE"

# Reemplazar archivo original
mv "$TEMP_FILE" "$FILE"

echo "✅ Exportaciones duplicadas corregidas"

# Mostrar las líneas alrededor de la exportación para verificar
echo ""
echo "📋 Verificando corrección (líneas 144-150):"
sed -n '144,150p' "$FILE" 2>/dev/null || echo "No se pudieron mostrar las líneas"

echo ""
echo "🔄 Reiniciando servidor..."

# Matar procesos de Vite
pkill -f vite || true

# Reiniciar
cd "/home/thunder/kuma-dashboard-clean/kuma-ui"
npm run dev &

echo ""
echo "✨ Script completado"
echo "📁 Backup guardado en: $BACKUP"
