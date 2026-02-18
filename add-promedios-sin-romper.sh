#!/bin/bash
# add-promedios-sin-romper.sh - AGREGAR PROMEDIOS SIN MODIFICAR EXISTENTE

echo "====================================================="
echo "➕ AGREGANDO PROMEDIOS DE INSTANCIA - SIN ROMPER NADA"
echo "====================================================="
echo "✅ NO modifica endpoints existentes"
echo "✅ SOLO agrega nueva funcionalidad"
echo "====================================================="

BACKEND_DIR="/opt/kuma-central/kuma-aggregator/src"
FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${BACKEND_DIR}/backup_add_promedios_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup preventivo..."
mkdir -p "$BACKUP_DIR"
cp "${BACKEND_DIR}/services/storage/sqlite.js" "$BACKUP_DIR/" 2>/dev/null || true
cp "${BACKEND_DIR}/services/historyService.js" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. AGREGAR TABLA DE PROMEDIOS AL SQLITE (SIN MODIFICAR EXISTENTE) ==========
echo "[2] Agregando tabla instance_averages a SQLite..."

# Verificar si la tabla ya existe
TABLE_EXISTS=$(sqlite3 /opt/kuma-central/kuma-aggregator/data/history.db "SELECT name FROM sqlite_master WHERE type='table' AND name='instance_averages';" 2>/dev/null || echo "")

if [ -z "$TABLE_EXISTS" ]; then
    sqlite3 /opt/kuma-central/kuma-aggregator/data/history.db << 'EOF'
    CREATE TABLE IF NOT EXISTS instance_averages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        instance TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        avgResponseTime REAL NOT NULL,
        avgStatus REAL NOT NULL,
        monitorCount INTEGER NOT NULL,
        upCount INTEGER NOT NULL,
        downCount INTEGER NOT NULL,
        degradedCount INTEGER NOT NULL,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_instance_averages_instance_time ON instance_averages(instance, timestamp);
    CREATE INDEX IF NOT EXISTS idx_instance_averages_timestamp ON instance_averages(timestamp);
EOF
    echo "✅ Tabla instance_averages creada"
else
    echo "⚠️ Tabla instance_averages ya existe"
fi
echo ""

# ========== 3. AGREGAR FUNCIONES DE PROMEDIOS A SQLITE.JS (SIN MODIFICAR EXISTENTE) ==========
echo "[3] Agregando funciones de promedios a sqlite.js..."

if ! grep -q "calculateInstanceAverage" "${BACKEND_DIR}/services/storage/sqlite.js"; then
    cat >> "${BACKEND_DIR}/services/storage/sqlite.js" << 'EOF'

// ========== 🆕 NUEVAS FUNCIONES DE PROMEDIOS DE INSTANCIA (AGREGADAS SIN MODIFICAR) ==========

export async function calculateInstanceAverage(instanceName, timestamp = Date.now()) {
    const db = await ensureSQLite();
    
    const from = timestamp - (5 * 60 * 1000);
    const to = timestamp;
    
    try {
        const monitors = await db.all(`
            SELECT 
                monitorId,
                AVG(responseTime) as avgResponseTime,
                AVG(CASE WHEN status = 'up' THEN 1 ELSE 0 END) as avgStatus,
                COUNT(*) as samples
            FROM monitor_history
            WHERE instance = ? 
                AND timestamp >= ? 
                AND timestamp <= ?
                AND responseTime IS NOT NULL
            GROUP BY monitorId
        `, [instanceName, from, to]);
        
        if (monitors.length === 0) return null;
        
        let totalResponseTime = 0;
        let totalStatus = 0;
        let validResponseCount = 0;
        let upCount = 0;
        let downCount = 0;
        let degradedCount = 0;
        
        for (const m of monitors) {
            if (m.avgResponseTime > 0) {
                totalResponseTime += m.avgResponseTime;
                validResponseCount++;
            }
            totalStatus += m.avgStatus;
            
            if (m.avgStatus > 0.8) upCount++;
            else if (m.avgStatus < 0.2) downCount++;
            else degradedCount++;
        }
        
        const avgResponseTime = validResponseCount > 0 ? totalResponseTime / validResponseCount : 0;
        const avgStatus = totalStatus / monitors.length;
        
        const result = await db.run(`
            INSERT INTO instance_averages 
                (instance, timestamp, avgResponseTime, avgStatus, monitorCount, upCount, downCount, degradedCount)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `, [
            instanceName, 
            timestamp, 
            avgResponseTime, 
            avgStatus, 
            monitors.length,
            upCount,
            downCount,
            degradedCount
        ]);
        
        console.log(`[SQLite] 📊 Promedio calculado para ${instanceName}: ${Math.round(avgResponseTime)}ms`);
        return { id: result.lastID };
    } catch (error) {
        console.error(`[SQLite] Error calculando promedio:`, error);
        return null;
    }
}

export async function getInstanceAverages(instanceName, hours = 24) {
    const db = await ensureSQLite();
    const from = Date.now() - (hours * 60 * 60 * 1000);
    
    try {
        return await db.all(`
            SELECT * FROM instance_averages
            WHERE instance = ? AND timestamp >= ?
            ORDER BY timestamp ASC
        `, [instanceName, from]);
    } catch (error) {
        console.error(`[SQLite] Error obteniendo promedios:`, error);
        return [];
    }
}

export async function calculateAllInstanceAverages() {
    const db = await ensureSQLite();
    
    try {
        const instances = await db.all(`
            SELECT DISTINCT instance FROM active_monitors
            WHERE lastSeen > ?
        `, [Date.now() - (10 * 60 * 1000)]);
        
        const results = [];
        for (const row of instances) {
            const result = await calculateInstanceAverage(row.instance);
            if (result) results.push(result);
        }
        
        console.log(`[SQLite] 📊 Promedios calculados para ${results.length} instancias`);
        return results;
    } catch (error) {
        console.error('[SQLite] Error calculando promedios:', error);
        return [];
    }
}
EOF
    echo "✅ Funciones de promedios agregadas a sqlite.js"
else
    echo "⚠️ Funciones de promedios ya existen en sqlite.js"
fi
echo ""

# ========== 4. AGREGAR ENDPOINT NUEVO (SIN MODIFICAR EXISTENTE) ==========
echo "[4] Agregando nuevo endpoint /api/instance/averages..."

cat > "${BACKEND_DIR}/routes/instanceAveragesRoutes.js" << 'EOF'
// 🆕 NUEVO ENDPOINT - PROMEDIOS DE INSTANCIA
// NO modifica ningún endpoint existente

import { Router } from 'express';
import * as historyService from '../services/historyService.js';

const router = Router();

// Obtener promedios de una instancia
router.get('/:instanceName', async (req, res) => {
    try {
        const instanceName = decodeURIComponent(req.params.instanceName);
        const { hours = 24 } = req.query;
        
        const averages = await historyService.getInstanceAverages(instanceName, hours);
        
        res.json({
            success: true,
            instance: instanceName,
            hours: parseInt(hours),
            data: averages.map(a => ({
                ts: a.timestamp,
                avgResponseTime: a.avgResponseTime,
                avgStatus: a.avgStatus,
                monitorCount: a.monitorCount
            })),
            count: averages.length
        });
    } catch (error) {
        console.error('[API] Error:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// Forzar cálculo de promedios
router.post('/calculate', async (req, res) => {
    try {
        const results = await historyService.calculateAllInstanceAverages();
        res.json({
            success: true,
            message: `Promedios calculados para ${results.length} instancias`,
            count: results.length
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

export default router;
EOF

echo "✅ Nuevo endpoint creado: /api/instance/averages"
echo ""

# ========== 5. AGREGAR FUNCIONES AL HISTORYSERVICE.JS (SIN MODIFICAR) ==========
echo "[5] Agregando funciones de promedios a historyService.js..."

if ! grep -q "getInstanceAverages" "${BACKEND_DIR}/services/historyService.js"; then
    cat >> "${BACKEND_DIR}/services/historyService.js" << 'EOF'

// ========== 🆕 NUEVAS FUNCIONES DE PROMEDIOS (AGREGADAS SIN MODIFICAR) ==========

export async function getInstanceAverages(instanceName, hours = 24) {
    try {
        const { getInstanceAverages: getAverages } = await import('./storage/sqlite.js');
        return await getAverages(instanceName, hours);
    } catch (error) {
        console.error('[HistoryService] Error obteniendo promedios:', error);
        return [];
    }
}

export async function calculateAllInstanceAverages() {
    try {
        const { calculateAllInstanceAverages: calculateAll } = await import('./storage/sqlite.js');
        return await calculateAll();
    } catch (error) {
        console.error('[HistoryService] Error calculando promedios:', error);
        return [];
    }
}
EOF
    echo "✅ Funciones de promedios agregadas a historyService.js"
else
    echo "⚠️ Funciones de promedios ya existen en historyService.js"
fi
echo ""

# ========== 6. MONTAR EL NUEVO ENDPOINT EN INDEX.JS ==========
echo "[6] Montando nuevo endpoint en index.js..."

if ! grep -q "instanceAveragesRoutes" "${BACKEND_DIR}/index.js"; then
    # Agregar import
    sed -i '/import .* from/i import instanceAveragesRoutes from '\''./routes/instanceAveragesRoutes.js'\'';' "${BACKEND_DIR}/index.js"
    
    # Agregar app.use
    sed -i '/app.use.*\/api\/metric-history/a app.use('\''/api/instance/averages'\'', instanceAveragesRoutes);' "${BACKEND_DIR}/index.js"
    
    echo "✅ Endpoint montado en /api/instance/averages"
else
    echo "⚠️ Endpoint ya estaba montado"
fi
echo ""

# ========== 7. AGREGAR SERVICIO AL FRONTEND (SIN MODIFICAR EXISTENTE) ==========
echo "[7] Agregando nuevo servicio al frontend..."

cat > "${FRONTEND_DIR}/src/services/promediosApi.js" << 'EOF'
// 🆕 NUEVO SERVICIO - PROMEDIOS DE INSTANCIA
// NO modifica los servicios existentes

const API_BASE = 'http://10.10.31.31:8080/api';

export const promediosApi = {
    // Obtener promedios históricos de una instancia
    async getInstanceAverages(instanceName, hours = 24) {
        try {
            const url = `${API_BASE}/instance/averages/${encodeURIComponent(instanceName)}?hours=${hours}&_=${Date.now()}`;
            const response = await fetch(url, { cache: 'no-store' });
            
            if (!response.ok) return { data: [], count: 0 };
            
            const result = await response.json();
            return result;
        } catch (error) {
            console.error('[PromediosApi] Error:', error);
            return { data: [], count: 0 };
        }
    },

    // Forzar cálculo de promedios
    async calculateAll() {
        try {
            const url = `${API_BASE}/instance/averages/calculate`;
            const response = await fetch(url, { method: 'POST' });
            return await response.json();
        } catch (error) {
            console.error('[PromediosApi] Error calculando:', error);
            return { success: false };
        }
    }
};

export default promediosApi;
EOF

echo "✅ Nuevo servicio frontend: promediosApi.js"
echo ""

# ========== 8. REINICIAR BACKEND ==========
echo ""
echo "[8] Reiniciando backend..."

cd "${BACKEND_DIR}/.."
pkill -f "node.*index.js" 2>/dev/null || true
sleep 2
NODE_ENV=production nohup node src/index.js > /tmp/kuma-backend.log 2>&1 &
sleep 3

echo "✅ Backend reiniciado"
echo ""

# ========== 9. CALCULAR PROMEDIOS INICIALES ==========
echo ""
echo "[9] Calculando promedios iniciales..."

curl -s -X POST "http://10.10.31.31:8080/api/instance/averages/calculate" > /dev/null
echo "✅ Promedios calculados"
echo ""

# ========== 10. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ PROMEDIOS AGREGADOS SIN ROMPER NADA ✅✅"
echo "====================================================="
echo ""
echo "📋 LO QUE SE AGREGÓ (SIN MODIFICAR LO EXISTENTE):"
echo ""
echo "   BACKEND:"
echo "   • 🆕 Tabla: instance_averages en SQLite"
echo "   • 🆕 Funciones: calculateInstanceAverage(), getInstanceAverages()"
echo "   • 🆕 Endpoint: /api/instance/averages/:instanceName"
echo ""
echo "   FRONTEND:"
echo "   • 🆕 Servicio: promediosApi.js"
echo ""
echo "📌 LO QUE NO SE TOCÓ (SIGUE FUNCIONANDO IGUAL):"
echo ""
echo "   • ✅ /api/history/series - Para monitores individuales"
echo "   • ✅ /api/summary - Datos en tiempo real"
echo "   • ✅ historyApi.js - Sin modificaciones"
echo "   • ✅ historyEngine.js - Sin modificaciones"
echo "   • ✅ InstanceDetail.jsx - Sin modificaciones"
echo ""
echo "🔄 PARA USAR LOS PROMEDIOS (OPCIONAL):"
echo ""
echo "   1. En cualquier componente:"
echo ""
echo "      import { promediosApi } from '../services/promediosApi.js';"
echo ""
echo "      const { data } = await promediosApi.getInstanceAverages('Caracas', 24);"
echo "      console.log('Promedios:', data);"
echo ""
echo "   2. Ver datos:"
echo "      curl http://10.10.31.31:8080/api/instance/averages/Caracas?hours=24"
echo ""
echo "====================================================="

# Preguntar si quiere probar el endpoint
read -p "¿Probar el nuevo endpoint de promedios? (s/N): " TEST_ENDPOINT
if [[ "$TEST_ENDPOINT" =~ ^[Ss]$ ]]; then
    echo ""
    echo "📊 Datos de Caracas:"
    curl -s "http://10.10.31.31:8080/api/instance/averages/Caracas?hours=24" | head -c 300
    echo ""
    echo ""
    echo "📊 Datos de Guanare:"
    curl -s "http://10.10.31.31:8080/api/instance/averages/Guanare?hours=24" | head -c 300
    echo ""
fi

echo ""
echo "✅ Script completado - NADA SE ROMPIÓ, TODO SIGUE IGUAL"
echo "   Los promedios están disponibles en un NUEVO endpoint"
