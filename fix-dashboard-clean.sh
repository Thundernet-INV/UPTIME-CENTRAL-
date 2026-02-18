#!/bin/bash

# fix-dashboard-clean.sh - Limpia el archivo y restaura la estructura correcta

echo "🧹 Limpiando archivo Dashboard.jsx..."

FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/views/Dashboard.jsx"

# Verificar que el archivo existe
if [ ! -f "$FILE" ]; then
    echo "❌ Error: No se encontró el archivo $FILE"
    exit 1
fi

# Crear backup
BACKUP="${FILE}.backup-antes-de-limpiar-$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$BACKUP"
echo "✅ Backup creado: $BACKUP"

# Eliminar la línea de depuración que comienza con "==>" y crear archivo limpio
sed -i '/^==>/d' "$FILE"

echo "✅ Línea de depuración eliminada"

# Verificar que el archivo ahora comienza con "import"
echo "📋 Verificando primeras líneas del archivo:"
head -5 "$FILE"

echo ""
echo "🔄 Reiniciando servidor..."

# Matar procesos de Vite
pkill -f vite || true

# Reiniciar
cd "/home/thunder/kuma-dashboard-clean/kuma-ui"
npm run dev &

echo ""
echo "✨ Script completado. El servidor debería funcionar ahora."
echo "📁 Backup guardado en: $BACKUP"
