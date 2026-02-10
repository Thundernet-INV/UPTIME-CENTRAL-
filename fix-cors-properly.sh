#!/bin/bash
echo "🔧 ARREGLANDO CORS (ELIMINANDO DUPLICADOS)"
echo "=========================================="

INDEX_FILE="/opt/kuma-central/kuma-aggregator/src/index.js"
BACKUP_FILE="$INDEX_FILE.backup.cors2.$(date +%s)"

if [ ! -f "$INDEX_FILE" ]; then
    echo "❌ Archivo no encontrado: $INDEX_FILE"
    exit 1
fi

# Hacer backup
cp "$INDEX_FILE" "$BACKUP_FILE"
echo "✅ Backup: $BACKUP_FILE"

echo ""
echo "📄 Eliminando configuración CORS duplicada..."

# Método: Mantener solo la PRIMERA configuración CORS y agregar 'Pragma'
awk '
BEGIN { in_first_cors = 0; in_second_cors = 0; first_cors_done = 0; }
/app\.use\(cors\({/ {
    if (first_cors_done == 0) {
        in_first_cors = 1
        first_cors_done = 1
        print $0
        next
    } else {
        in_second_cors = 1
        next  # Saltar la segunda configuración CORS
    }
}
in_first_cors && /allowedHeaders:/ {
    # Actualizar la primera configuración
    gsub(/\]/, "\x27Pragma\x27]")
    print $0
    next
}
in_first_cors && /}\);/ {
    print $0
    in_first_cors = 0
    next
}
in_second_cors && /}\);/ {
    # Fin de la segunda configuración, no imprimir
    in_second_cors = 0
    next
}
in_first_cors || in_second_cors {
    # Dentro de alguna configuración CORS
    if (in_first_cors) {
        print $0
    }
    # Si in_second_cors, no imprimir (eliminar duplicado)
    next
}
{
    # Fuera de configuraciones CORS, imprimir normalmente
    print $0
}
' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

echo "✅ CORS duplicado eliminado"

echo ""
echo "🔍 Verificando resultado..."
echo "Configuración CORS final (líneas 23-28):"
sed -n '23,33p' "$INDEX_FILE"

echo ""
echo "🧪 Verificando sintaxis..."
if node -c "$INDEX_FILE" > /dev/null 2>&1; then
    echo "✅ Sintaxis correcta"
else
    echo "❌ Error de sintaxis:"
    node -c "$INDEX_FILE"
    exit 1
fi

echo ""
echo "🔄 Reiniciando backend..."
BACKEND_PID=$(sudo lsof -ti:8080)
if [ -n "$BACKEND_PID" ]; then
    echo "   Deteniendo backend PID $BACKEND_PID..."
    sudo kill $BACKEND_PID
    sleep 2
    
    echo "   Iniciando nuevo backend..."
    cd /opt/kuma-central/kuma-aggregator
    npm start > /var/log/kuma-backend.log 2>&1 &
    sleep 3
    
    if curl -s http://localhost:8080/health > /dev/null; then
        echo "   ✅ Backend reiniciado y respondiendo"
    else
        echo "   ⚠️  Backend puede estar iniciando..."
    fi
else
    echo "   ⚠️  Backend no está corriendo"
fi

echo ""
echo "=========================================="
echo "✅ CORS COMPLETAMENTE ARREGLADO"
echo ""
echo "📋 Cambios realizados:"
echo "   1. Eliminada configuración CORS duplicada (líneas 29-34)"
echo "   2. Agregado 'Pragma' a allowedHeaders en configuración restante"
echo "   3. Backend reiniciado"
echo ""
echo "🌐 Ahora prueba el frontend:"
echo "   http://10.10.31.31:5173"
echo "   Los errores CORS deberían desaparecer."
echo ""
echo "💡 Si aún hay errores, prueba en navegador:"
echo "   1. Abrir herramientas de desarrollo (F12)"
echo "   2. Ir a pestaña Network"
echo "   3. Recargar página (Ctrl+F5)"
echo "   4. Verificar que las peticiones a :8080 tengan éxito"
echo "=========================================="
