#!/bin/bash
echo "🔧 ARREGLANDO historyService.js (VERSIÓN FINAL)"
echo "================================================"

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
echo "📄 Creando versión corregida..."

# Crear la versión CORRECTA
cat > "$SERVICE_FILE" << 'EOF'
// src/services/historyService.js
import { 
    initSQLite, 
    insertHistory, 
    getHistory, 
    getHistoryAgg, 
    getAvailableMonitors as getAvailableMonitorsFromSQLite 
} from './storage/sqlite.js';

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
    return await getAvailableMonitorsFromSQLite();
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
echo "🔍 Verificando funciones:"
echo ""
echo "1. Import de sqlite.js:"
head -10 "$SERVICE_FILE"
echo ""
echo "2. Funciones exportadas:"
grep -n "export" "$SERVICE_FILE"
echo ""
echo "3. ¿getAvailableMonitors llama a SQLite?:"
sed -n '22,26p' "$SERVICE_FILE"

echo ""
echo "================================================"
echo "✅ historyService.js ARREGLADO CORRECTAMENTE"
echo ""
echo "📋 Cambios realizados:"
echo "   - Renombrado import: getAvailableMonitors → getAvailableMonitorsFromSQLite"
echo "   - Función getAvailableMonitors() ahora llama a getAvailableMonitorsFromSQLite()"
echo "   - Eliminada recursión infinita"
echo ""
echo "⚠️  El archivo original está en: $BACKUP_FILE"
echo "================================================"
