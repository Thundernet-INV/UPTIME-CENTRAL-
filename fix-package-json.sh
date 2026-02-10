#!/bin/bash
echo "🔧 ARREGLANDO PACKAGE.JSON..."
echo "=============================="

BACKEND_ROOT="/opt/kuma-central/kuma-aggregator"
PACKAGE_JSON="$BACKEND_ROOT/package.json"

if [ ! -f "$PACKAGE_JSON" ]; then
    echo "❌ package.json no encontrado"
    exit 1
fi

# Hacer backup primero
cp "$PACKAGE_JSON" "$PACKAGE_JSON.backup.$(date +%s)"

echo "Package.json actual (primeras 20 líneas):"
head -20 "$PACKAGE_JSON"

# Arreglar conflictos de merge
echo ""
echo "Arreglando conflictos de merge..."
sed -i '/^<<<<<<< HEAD/,/^=======/d' "$PACKAGE_JSON"
sed -i '/^>>>>>>> /d' "$PACKAGE_JSON"

# También eliminar cualquier otra línea problemática
sed -i '/^<<<<<<< /d' "$PACKAGE_JSON"
sed -i '/^=======$/d' "$PACKAGE_JSON"
sed -i '/^>>>>>>> /d' "$PACKAGE_JSON"

# Verificar que sea JSON válido
if python3 -m json.tool "$PACKAGE_JSON" > /dev/null 2>&1; then
    echo "✅ package.json ahora es JSON válido"
    
    echo ""
    echo "Package.json arreglado (primeras 20 líneas):"
    head -20 "$PACKAGE_JSON"
else
    echo "❌ Aún hay problemas con el JSON. Restaurando backup..."
    cp "$PACKAGE_JSON.backup.*" "$PACKAGE_JSON" 2>/dev/null
    echo "Se restauró la versión anterior"
fi

echo ""
echo "=============================="
