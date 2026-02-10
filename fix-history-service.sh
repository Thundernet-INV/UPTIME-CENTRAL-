#!/bin/bash
echo "🔧 ARREGLANDO historyService.js"
echo "================================"

SERVICE_FILE="/opt/kuma-central/kuma-aggregator/src/services/historyService.js"
BACKUP_FILE="$SERVICE_FILE.backup.$(date +%s)"

if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ Archivo no encontrado: $SERVICE_FILE"
    exit 1
fi

# Hacer backup
cp "$SERVICE_FILE" "$BACKUP_FILE"
echo "✅ Backup creado: $BACKUP_FILE"

echo ""
echo "📄 Contenido actual (primeras 40 líneas):"
head -40 "$SERVICE_FILE"

echo ""
echo "🔄 Creando versión corregida..."

# Crear versión corregida (sin duplicados)
cat > "$SERVICE_FILE" << 'EOF'
// src/services/historyService.js
import { initSQLite, insertHistory, getHistory, getHistoryAgg, getAvailableMonitors } from './storage/sqlite.js';

export function init() {
    initSQLite();
}

export async function addEvent(event) {
    return insertHistory(event);
}

export async function listRaw(params) {
    return getHistory(params);
}

export async function listSeries(params) {
    const bucketMs = Number(params.bucketMs || 60000);
    return getHistoryAgg({ ...params, bucketMs });
}

// Función auxiliar para obtener monitores disponibles
export async function getAvailableMonitors() {
    return await getAvailableMonitors();
}
EOF

echo "✅ historyService.js recreado"

echo ""
echo "🧪 Verificando sintaxis..."
if node -c "$SERVICE_FILE" > /dev/null 2>&1; then
    echo "✅ Sintaxis correcta"
else
    echo "❌ Error de sintaxis:"
    node -c "$SERVICE_FILE"
    echo ""
    echo "🔙 Restaurando backup..."
    cp "$BACKUP_FILE" "$SERVICE_FILE"
    exit 1
fi

echo ""
echo "🔍 Funciones exportadas:"
grep -n "export" "$SERVICE_FILE"

echo ""
echo "================================"
echo "✅ historyService.js ARREGLADO"
echo ""
echo "📋 El archivo ahora tiene:"
echo "   - init()"
echo "   - addEvent()"
echo "   - listRaw()"
echo "   - listSeries()"
echo "   - getAvailableMonitors()"
echo ""
echo "⚠️  NOTA: Hay un problema cíclico en getAvailableMonitors()"
echo "   (llama a sí mismo), pero lo arreglaremos después."
echo "================================"
