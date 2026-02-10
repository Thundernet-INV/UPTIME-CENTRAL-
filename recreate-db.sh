#!/bin/bash
echo "🗄️  RECREANDO BASE DE DATOS CON ESTRUCTURA CORRECTA"
echo "==================================================="

DB_FILE="/opt/kuma-central/kuma-aggregator/data/history.db"
BACKUP_FILE="$DB_FILE.backup.$(date +%s)"

if [ ! -f "$DB_FILE" ]; then
    echo "❌ Base de datos no encontrada: $DB_FILE"
    exit 1
fi

echo "1. Haciendo backup..."
cp "$DB_FILE" "$BACKUP_FILE"
echo "   ✅ Backup: $BACKUP_FILE"

echo ""
echo "2. Eliminando tabla vieja y creando nueva..."
sqlite3 "$DB_FILE" << 'SQL'
-- Eliminar tabla existente
DROP TABLE IF EXISTS monitor_history;

-- Crear tabla con estructura CORRECTA (con columna instance)
CREATE TABLE monitor_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    monitorId TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    status TEXT NOT NULL,
    responseTime REAL,
    message TEXT,
    instance TEXT
);

-- Crear todos los índices necesarios
CREATE INDEX idx_monitor_time ON monitor_history(monitorId, timestamp);
CREATE INDEX idx_timestamp ON monitor_history(timestamp);
CREATE INDEX idx_instance ON monitor_history(instance);

-- Optimizar espacio
VACUUM;
SQL

echo "   ✅ Tabla recreada con estructura correcta"

echo ""
echo "3. Verificando nueva estructura..."
echo "   Columnas:"
sqlite3 "$DB_FILE" "PRAGMA table_info(monitor_history);"

echo ""
echo "4. Registros en nueva tabla:"
sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM monitor_history;"

echo ""
echo "==================================================="
echo "✅ BASE DE DATOS LISTA"
echo ""
echo "📋 Nueva estructura:"
echo "   - id, monitorId, timestamp, status, responseTime, message, instance"
echo "   - Índices: idx_monitor_time, idx_timestamp, idx_instance"
echo ""
echo "⚠️  Backup del viejo (1 registro) en: $BACKUP_FILE"
echo "==================================================="
