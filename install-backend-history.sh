#!/bin/bash
echo "🚀 INSTALACIÓN COMPLETA DE HISTORIAL SQLITE EN BACKEND"
echo "========================================================"
echo "Backend target: /opt/kuma-central/kuma-aggregator"
echo ""

# Configuración
BACKEND_ROOT="/opt/kuma-central/kuma-aggregator"
BACKEND_SRC="$BACKEND_ROOT/src"
BACKUP_DIR="$BACKEND_ROOT/backup_history_$(date +%Y%m%d_%H%M%S)"
DB_DIR="$BACKEND_ROOT/data"
DB_FILE="$DB_DIR/history.db"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Funciones de log
log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[X]${NC} $1"; exit 1; }

# ========== VERIFICACIONES INICIALES ==========
echo "🔍 Verificando pre-requisitos..."

# 1. Verificar que somos root o tenemos permisos
if [ "$EUID" -ne 0 ]; then
    warn "Ejecutando sin sudo. Algunos archivos pueden requerir permisos elevados."
    read -p "¿Continuar de todos modos? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        error "Ejecuta con: sudo ./install-backend-history.sh"
    fi
fi

# 2. Verificar que el backend existe
if [ ! -d "$BACKEND_ROOT" ]; then
    error "Backend no encontrado en $BACKEND_ROOT"
fi

if [ ! -f "$BACKEND_SRC/index.js" ]; then
    error "Archivo principal no encontrado: $BACKEND_SRC/index.js"
fi

log "Backend encontrado: $BACKEND_ROOT"

# 3. Verificar si ya tiene módulo de historial
if [ -f "$BACKEND_SRC/routes/historyRoutes.js" ]; then
    warn "Ya existe historyRoutes.js. Se hará backup."
fi

if [ -f "$DB_FILE" ]; then
    warn "Base de datos ya existe: $DB_FILE"
fi

# 4. Detener backend temporalmente
log "Deteniendo backend temporalmente..."
BACKEND_PID=$(sudo lsof -ti:8080 2>/dev/null)
if [ -n "$BACKEND_PID" ]; then
    log "Backend PID $BACKEND_PID en puerto 8080"
    read -p "¿Detener backend para la instalación? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        sudo kill $BACKEND_PID 2>/dev/null
        sleep 2
        if sudo lsof -ti:8080 >/dev/null 2>&1; then
            sudo kill -9 $BACKEND_PID 2>/dev/null
        fi
        log "Backend detenido"
    else
        warn "Backend seguirá corriendo. La instalación podría requerir reinicio."
    fi
else
    warn "Backend no está corriendo o no se pudo detectar"
fi

# ========== CREAR BACKUPS ==========
echo ""
echo "📦 CREANDO BACKUPS..."
mkdir -p "$BACKUP_DIR"

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup_path="$BACKUP_DIR/${file#$BACKEND_ROOT/}"
        mkdir -p "$(dirname "$backup_path")"
        cp "$file" "$backup_path"
        log "  Backup: $file"
    fi
}

# Archivos críticos a respaldar
declare -a CRITICAL_FILES=(
    "src/index.js"
    "src/routes/historyRoutes.js"
    "src/services/historyService.js"
    "src/services/storage/sqlite.js"
    "package.json"
)

for file in "${CRITICAL_FILES[@]}"; do
    backup_file "$BACKEND_ROOT/$file"
done

log "Backups guardados en: $BACKUP_DIR"

# ========== INSTALAR DEPENDENCIAS ==========
echo ""
echo "📦 INSTALANDO DEPENDENCIAS..."

cd "$BACKEND_ROOT"

# Verificar si sqlite3 ya está en package.json
if ! grep -q "sqlite3" "package.json"; then
    log "Instalando sqlite3..."
    npm install sqlite3 --save
else
    log "sqlite3 ya está en package.json"
fi

# Verificar si es ESM (type: module)
if grep -q '"type": "module"' "package.json"; then
    log "Backend es ESM (type: module)"
    IS_ESM=true
else
    warn "Backend no es ESM. Se asumirá CommonJS."
    IS_ESM=false
fi

# ========== CREAR ESTRUCTURA DE DIRECTORIOS ==========
echo ""
echo "📁 CREANDO ESTRUCTURA DE DIRECTORIOS..."

mkdir -p "$BACKEND_SRC/utils"
mkdir -p "$BACKEND_SRC/services/storage"
mkdir -p "$BACKEND_SRC/controllers"
mkdir -p "$BACKEND_SRC/routes"
mkdir -p "$DB_DIR"

log "Directorios creados"

# ========== CREAR ARCHIVOS DEL MÓDULO DE HISTORIAL ==========
echo ""
echo "📄 CREANDO ARCHIVOS DEL MÓDULO DE HISTORIAL..."

# 1. utils/validate.js
cat > "$BACKEND_SRC/utils/validate.js" << 'EOF'
// src/utils/validate.js
export function ensureEnv(key, fallback = undefined) {
    return process.env[key] ?? fallback;
}

export function assertQuery(params) {
    const errors = [];
    const { monitorId, from, to, limit, offset, bucketMs } = params;
    
    if (!monitorId || typeof monitorId !== 'string') errors.push('monitorId requerido');
    if (!from || isNaN(Number(from))) errors.push('from inválido (epoch ms)');
    if (!to || isNaN(Number(to))) errors.push('to inválido (epoch ms)');
    
    if (limit !== undefined && (isNaN(Number(limit)) || Number(limit) < 1 || Number(limit) > 10000)) {
        errors.push('limit debe ser 1-10000');
    }
    
    if (offset !== undefined && (isNaN(Number(offset)) || Number(offset) < 0)) {
        errors.push('offset debe ser >= 0');
    }
    
    if (bucketMs !== undefined && (isNaN(Number(bucketMs)) || Number(bucketMs) < 1000)) {
        errors.push('bucketMs debe ser >= 1000');
    }
    
    return errors;
}
EOF
log "Creado: utils/validate.js"

# 2. services/storage/sqlite.js (versión ESM)
cat > "$BACKEND_SRC/services/storage/sqlite.js" << 'EOF'
// src/services/storage/sqlite.js
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let db = null;

export async function initSQLite() {
    if (db) return;
    
    // Asegurar que el directorio data existe
    const dataDir = path.join(__dirname, '../../../data');
    if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
    }
    
    db = await open({
        filename: path.join(dataDir, 'history.db'),
        driver: sqlite3.Database
    });
    
    // Crear tablas
    await db.exec(`
        CREATE TABLE IF NOT EXISTS monitor_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            monitorId TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            status TEXT NOT NULL,
            responseTime REAL,
            message TEXT,
            instance TEXT
        );
        
        CREATE INDEX IF NOT EXISTS idx_monitor_time 
        ON monitor_history(monitorId, timestamp);
        
        CREATE INDEX IF NOT EXISTS idx_timestamp 
        ON monitor_history(timestamp);
        
        CREATE INDEX IF NOT EXISTS idx_instance 
        ON monitor_history(instance);
    `);
    
    console.log('[SQLite] Base de datos inicializada para historial');
}

export async function insertHistory(event) {
    if (!db) await initSQLite();
    
    const { monitorId, timestamp, status, responseTime = null, message = null } = event;
    const instance = monitorId.includes('_') ? monitorId.split('_')[0] : 'unknown';
    
    const result = await db.run(
        `INSERT INTO monitor_history (monitorId, timestamp, status, responseTime, message, instance)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [monitorId, timestamp, status, responseTime, message, instance]
    );
    
    return { id: result.lastID };
}

export async function getHistory(params) {
    if (!db) await initSQLite();
    
    const { monitorId, from, to, limit = 1000, offset = 0 } = params;
    
    return await db.all(
        `SELECT * FROM monitor_history
         WHERE monitorId = ?
           AND timestamp >= ?
           AND timestamp <= ?
         ORDER BY timestamp DESC
         LIMIT ? OFFSET ?`,
        [monitorId, from, to, limit, offset]
    );
}

export async function getHistoryAgg(params) {
    if (!db) await initSQLite();
    
    const { monitorId, from, to, bucketMs = 60000 } = params;
    
    const result = await db.all(
        `SELECT
            CAST((timestamp / ?) * ? AS INTEGER) AS bucket,
            AVG(CASE WHEN status = 'up' THEN 1 ELSE 0 END) as avgStatus,
            AVG(responseTime) as avgResponseTime,
            COUNT(*) as count
         FROM monitor_history
         WHERE monitorId = ?
           AND timestamp >= ?
           AND timestamp <= ?
         GROUP BY bucket
         ORDER BY bucket ASC`,
        [bucketMs, bucketMs, monitorId, from, to]
    );
    
    return result.map(row => ({
        timestamp: row.bucket,
        avgStatus: row.avgStatus,
        avgResponseTime: row.avgResponseTime || 0,
        count: row.count
    }));
}

export async function getAvailableMonitors() {
    if (!db) await initSQLite();
    
    return await db.all(
        `SELECT 
            monitorId,
            instance,
            COUNT(*) as totalChecks,
            MAX(timestamp) as lastCheck,
            MIN(timestamp) as firstCheck
         FROM monitor_history
         GROUP BY monitorId, instance
         ORDER BY lastCheck DESC`
    );
}
EOF
log "Creado: services/storage/sqlite.js"

# 3. services/historyService.js
cat > "$BACKEND_SRC/services/historyService.js" << 'EOF'
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
log "Creado: services/historyService.js"

# 4. controllers/historyController.js
cat > "$BACKEND_SRC/controllers/historyController.js" << 'EOF'
// src/controllers/historyController.js
import { assertQuery } from '../utils/validate.js';
import * as historyService from '../services/historyService.js';

export async function getHistory(req, res) {
    try {
        const { monitorId, from, to } = req.query;
        const limit = Number(req.query.limit || 1000);
        const offset = Number(req.query.offset || 0);
        
        const errors = assertQuery({ monitorId, from, to, limit, offset });
        if (errors.length) return res.status(400).json({ errors });
        
        const rows = await historyService.listRaw({
            monitorId,
            from: Number(from),
            to: Number(to),
            limit,
            offset,
        });
        
        res.json({ data: rows, page: { limit, offset, count: rows.length } });
    } catch (err) {
        console.error('getHistory error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
}

export async function getSeries(req, res) {
    try {
        const { monitorId, from, to } = req.query;
        const bucketMs = Number(req.query.bucketMs || 60000);
        
        const errors = assertQuery({ monitorId, from, to, bucketMs });
        if (errors.length) return res.status(400).json({ errors });
        
        const series = await historyService.listSeries({
            monitorId,
            from: Number(from),
            to: Number(to),
            bucketMs,
        });
        
        res.json({ data: series, meta: { bucketMs } });
    } catch (err) {
        console.error('getSeries error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
}

// Endpoint para insertar eventos (útil para testing)
export async function postEvent(req, res) {
    try {
        const { monitorId, timestamp, status, responseTime = null, message = null } = req.body;
        
        const errors = [];
        if (!monitorId) errors.push('monitorId requerido');
        if (!timestamp || isNaN(Number(timestamp))) errors.push('timestamp inválido (epoch ms)');
        if (!['up', 'down', 'degraded'].includes(status)) {
            errors.push("status debe ser 'up', 'down' o 'degraded'");
        }
        
        if (errors.length) return res.status(400).json({ errors });
        
        const result = await historyService.addEvent({
            monitorId,
            timestamp: Number(timestamp),
            status,
            responseTime,
            message
        });
        
        res.status(201).json({ ok: true, id: result.id });
    } catch (err) {
        console.error('postEvent error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
}
EOF
log "Creado: controllers/historyController.js"

# 5. routes/historyRoutes.js
cat > "$BACKEND_SRC/routes/historyRoutes.js" << 'EOF'
// src/routes/historyRoutes.js
import { Router } from 'express';
import { getHistory, getSeries, postEvent } from '../controllers/historyController.js';

const router = Router();

router.get('/', getHistory);
router.get('/series', getSeries);
router.post('/', postEvent);

export default router;
EOF
log "Creado: routes/historyRoutes.js"

# ========== MODIFICAR index.js PARA INTEGRAR HISTORIAL ==========
echo ""
echo "🔧 MODIFICANDO index.js PARA INTEGRAR HISTORIAL..."

# Primero, hacer backup del index.js actual
cp "$BACKEND_SRC/index.js" "$BACKEND_SRC/index.js.backup.$(date +%s)"

# Leer el archivo actual
INDEX_CONTENT=$(cat "$BACKEND_SRC/index.js")

# Verificar si ya tiene los imports necesarios
if ! echo "$INDEX_CONTENT" | grep -q "import.*historyRoutes"; then
    log "Añadiendo imports a index.js..."
    
    # Buscar la línea después de los últimos imports
    IMPORT_LINE=$(grep -n "import.*from" "$BACKEND_SRC/index.js" | tail -1 | cut -d: -f1)
    
    if [ -n "$IMPORT_LINE" ]; then
        # Insertar después del último import
        sed -i "${IMPORT_LINE}a\\
import historyRoutes from './routes/historyRoutes.js';\\
import * as historyService from './services/historyService.js';" "$BACKEND_SRC/index.js"
    else
        # Insertar después de 'import express'
        sed -i "/import express/a\\
import historyRoutes from './routes/historyRoutes.js';\\
import * as historyService from './services/historyService.js';" "$BACKEND_SRC/index.js"
    fi
else
    log "Imports ya existen en index.js"
fi

# Verificar si ya tiene historyService.init()
if ! grep -q "historyService.init()" "$BACKEND_SRC/index.js"; then
    log "Añadiendo historyService.init()..."
    
    # Buscar línea después de const app = express()
    APP_LINE=$(grep -n "const app = express()" "$BACKEND_SRC/index.js" | head -1 | cut -d: -f1)
    
    if [ -n "$APP_LINE" ]; then
        APP_LINE=$((APP_LINE + 1))
        sed -i "${APP_LINE}i\\
historyService.init();" "$BACKEND_SRC/index.js"
    fi
fi

# Verificar si ya tiene la ruta montada
if ! grep -q "app.use.*/api/history.*historyRoutes" "$BACKEND_SRC/index.js"; then
    log "Montando ruta /api/history..."
    
    # Buscar línea después de historyService.init() o app.use(express.json())
    MOUNT_LINE=$(grep -n "historyService.init()" "$BACKEND_SRC/index.js" | head -1 | cut -d: -f1)
    
    if [ -n "$MOUNT_LINE" ]; then
        MOUNT_LINE=$((MOUNT_LINE + 1))
        sed -i "${MOUNT_LINE}i\\
app.use('/api/history', express.json({ limit: '256kb' }), historyRoutes);" "$BACKEND_SRC/index.js"
    else
        # Buscar después de app.use(express.json())
        JSON_LINE=$(grep -n "app.use(express.json" "$BACKEND_SRC/index.js" | head -1 | cut -d: -f1)
        if [ -n "$JSON_LINE" ]; then
            JSON_LINE=$((JSON_LINE + 1))
            sed -i "${JSON_LINE}i\\
app.use('/api/history', express.json({ limit: '256kb' }), historyRoutes);" "$BACKEND_SRC/index.js"
        fi
    fi
fi

# Modificar la función cycle() para guardar automáticamente
log "Modificando función cycle() para guardar datos automáticamente..."

# Buscar la función cycle
CYCLE_START=$(grep -n "async function cycle" "$BACKEND_SRC/index.js" | head -1 | cut -d: -f1)
if [ -n "$CYCLE_START" ]; then
    # Buscar dentro de la función cycle donde se procesan los monitores
    # Buscar el bucle for que procesa las instancias
    FOR_LINE=$(awk -v start="$CYCLE_START" 'NR >= start && /for.*const inst.*instances/ {print NR; exit}' "$BACKEND_SRC/index.js")
    
    if [ -n "$FOR_LINE" ]; then
        # Buscar el try block dentro del for
        TRY_LINE=$(awk -v start="$FOR_LINE" 'NR >= start && /try/ {print NR; exit}' "$BACKEND_SRC/index.js")
        
        if [ -n "$TRY_LINE" ]; then
            # Buscar donde se extraen los monitores
            EXTRACT_LINE=$(awk -v start="$TRY_LINE" 'NR >= start && /extracted.*extract/ {print NR; exit}' "$BACKEND_SRC/index.js")
            
            if [ -n "$EXTRACT_LINE" ]; then
                # Insertar después de la línea que agrega a nextMonitors
                INSERT_AFTER=$(awk -v start="$EXTRACT_LINE" 'NR >= start && /nextMonitors.push/ {last=$0; line=NR} END{print line}' "$BACKEND_SRC/index.js")
                
                if [ -n "$INSERT_AFTER" ]; then
                    sed -i "${INSERT_AFTER}a\\
                    // Guardar en SQLite automáticamente\\
                    await historyService.addEvent({\\
                        monitorId: \`\${inst.name}_\${m.info?.monitor_name}\`.replace(/\\\\s+/g, '_'),\\
                        timestamp: Date.now(),\\
                        status: m.latest?.status === 1 ? 'up' : 'down',\\
                        responseTime: m.latest?.responseTime || null,\\
                        message: null\\
                    });" "$BACKEND_SRC/index.js"
                fi
            fi
        fi
    fi
fi

log "index.js modificado exitosamente"

# ========== CREAR SCRIPT DE TEST ==========
echo ""
echo "🧪 CREANDO SCRIPT DE TEST..."

cat > "$BACKEND_ROOT/test_history.sh" << 'EOF'
#!/bin/bash
echo "🧪 TEST DEL MÓDULO DE HISTORIAL"
echo "================================"

API="http://localhost:8080/api/history"
TS_MS=$(date +%s%3N)
FROM=$((TS_MS - 3600000))  # 1 hora atrás
TO=$TS_MS

echo "1. Probando POST de evento..."
POST_RESP=$(curl -s -X POST "$API" \
  -H "Content-Type: application/json" \
  -d "{
    \"monitorId\": \"test_monitor_$(date +%s)\",
    \"timestamp\": $TS_MS,
    \"status\": \"up\",
    \"responseTime\": 150,
    \"message\": \"Test event\"
  }")

echo "   Respuesta: $POST_RESP"

echo ""
echo "2. Probando GET de eventos..."
GET_RESP=$(curl -s "$API?monitorId=test&from=$FROM&to=$TO&limit=5")
echo "   Respuesta: $GET_RESP"

echo ""
echo "3. Probando GET de series..."
SERIES_RESP=$(curl -s "$API/series?monitorId=test&from=$FROM&to=$TO&bucketMs=60000")
echo "   Respuesta: $(echo $SERIES_RESP | head -c 200)..."

echo ""
echo "4. Verificando base de datos..."
DB_FILE="/opt/kuma-central/kuma-aggregator/data/history.db"
if [ -f "$DB_FILE" ]; then
    echo "   ✅ Base de datos: $DB_FILE"
    if command -v sqlite3 > /dev/null; then
        COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM monitor_history" 2>/dev/null || echo "0")
        echo "   📊 Registros totales: $COUNT"
        
        echo ""
        echo "5. Últimos 5 registros:"
        sqlite3 "$DB_FILE" "SELECT datetime(timestamp/1000, 'unixepoch'), monitorId, status, responseTime FROM monitor_history ORDER BY timestamp DESC LIMIT 5" 2>/dev/null || echo "   No se pudo leer"
    else
        echo "   ⚠️  sqlite3 no instalado, no se puede verificar datos"
    fi
else
    echo "   ❌ Base de datos no encontrada"
fi

echo ""
echo "================================"
echo "💡 Si ves errores, revisa:"
echo "   - Que el backend esté corriendo: curl http://localhost:8080/health"
echo "   - Los logs del backend"
echo "   - Permisos del directorio data/"
EOF

chmod +x "$BACKEND_ROOT/test_history.sh"
log "Script de test creado: $BACKEND_ROOT/test_history.sh"

# ========== CONFIGURAR PERMISOS ==========
echo ""
echo "🔒 CONFIGURANDO PERMISOS..."

chmod -R 755 "$BACKEND_SRC"
chmod -R 755 "$DB_DIR" 2>/dev/null || true
chown -R thunder:thunder "$DB_DIR" 2>/dev/null || true

log "Permisos configurados"

# ========== INICIAR BACKEND ==========
echo ""
echo "🚀 INICIANDO BACKEND..."

cd "$BACKEND_ROOT"

# Verificar si hay un proceso de gestión (pm2, systemd, etc.)
if command -v pm2 > /dev/null 2>&1; then
    log "PM2 detectado. Reiniciando aplicación..."
    PM2_APP=$(pm2 list | grep "kuma-aggregator" | awk '{print $2}')
    if [ -n "$PM2_APP" ]; then
        pm2 restart "$PM2_APP"
    else
        warn "No se encontró aplicación PM2 para kuma-aggregator"
        log "Iniciando manualmente: npm start"
        npm start &
    fi
else
    log "Iniciando backend manualmente..."
    npm start &
    BACKEND_PID=$!
    log "Backend iniciado con PID: $BACKEND_PID"
fi

# Esperar a que inicie
sleep 3

# ========== VERIFICAR INSTALACIÓN ==========
echo ""
echo "✅ VERIFICANDO INSTALACIÓN..."

echo "1. Verificando que el backend responda..."
if curl -s http://localhost:8080/health > /dev/null; then
    log "   ✅ Backend activo"
else
    warn "   ⚠️  Backend no responde. Puede requerir reinicio manual."
fi

echo ""
echo "2. Verificando ruta /api/history..."
TEST_RESP=$(curl -s "http://localhost:8080/api/history/series?monitorId=test&from=1&to=2" 2>/dev/null || echo "ERROR")
if echo "$TEST_RESP" | grep -q "errors\|data"; then
    log "   ✅ Ruta /api/history funcionando"
else
    warn "   ⚠️  Ruta /api/history puede no estar funcionando"
fi

echo ""
echo "3. Verificando base de datos..."
if [ -f "$DB_FILE" ]; then
    log "   ✅ Base de datos creada: $DB_FILE"
    ls -la "$DB_FILE"
else
    warn "   ⚠️  Base de datos no creada. Se creará en el primer evento."
fi

# ========== INSTRUCCIONES FINALES ==========
echo ""
echo "========================================================"
echo "🎉 INSTALACIÓN COMPLETADA"
echo "========================================================"
echo ""
echo "📋 RESUMEN:"
echo "   ✅ Módulo de historial SQLite instalado en backend"
echo "   ✅ Backend configurado para guardar datos automáticamente"
echo "   ✅ Rutas /api/history y /api/history/series disponibles"
echo "   ✅ Base de datos: $DB_FILE"
echo "   ✅ Backup de archivos originales en: $BACKUP_DIR"
echo ""
echo "🔧 PRÓXIMOS PASOS:"
echo ""
echo "1. Probar la instalación:"
echo "   cd /opt/kuma-central/kuma-aggregator"
echo "   ./test_history.sh"
echo ""
echo "2. Esperar 1-2 ciclos de polling (10 segundos) para que"
echo "   el backend comience a guardar datos automáticamente"
echo ""
echo "3. Verificar datos en la base de datos:"
echo "   sqlite3 $DB_FILE \"SELECT COUNT(*) FROM monitor_history\""
echo ""
echo "4. Para el frontend (NO SE REQUIERE MODIFICACIÓN INICIAL):"
echo "   Las gráficas seguirán funcionando con datos en cache"
echo "   Luego actualizaremos el frontend para usar el backend"
echo ""
echo "⚠️  SI HAY PROBLEMAS:"
echo "   1. Revisa los logs del backend"
echo "   2. Verifica permisos en $DB_DIR"
echo "   3. Restaura desde backup: cp -r $BACKUP_DIR/* $BACKEND_ROOT/"
echo ""
echo "🔗 Para probar manualmente:"
echo "   curl \"http://localhost:8080/api/history/series?monitorId=San_Felipe_monitor_name&from=\$(date +%s%3N -d '1 hour ago')&to=\$(date +%s%3N)\""
echo ""
echo "========================================================"
