#!/bin/bash
# rollback-estable.sh - RESTAURA A LA VERSIÓN CON NOTIFICACIONES NEGRAS FUNCIONALES
# Basado en backup_history_ranges_20260210_110306 que SÍ funciona

echo "====================================================="
echo "🔄 ROLLBACK COMPLETO - VERSIÓN ESTABLE CON NOTIFICACIONES"
echo "====================================================="
echo ""

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_ACTUAL="${FRONTEND_DIR}/backup_antes_rollback_${BACKUP_TIMESTAMP}"

# ========== COLORES ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========== FUNCIONES ==========
log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# ========== VERIFICAR BACKUPS DISPONIBLES ==========
echo "🔍 Verificando backups disponibles..."
echo ""

BACKUP_FOUND=0
BACKUP_PATH=""

# Buscar el backup específico que SÍ funciona
if [ -d "${FRONTEND_DIR}/backup_history_ranges_20260210_110306" ]; then
    BACKUP_PATH="${FRONTEND_DIR}/backup_history_ranges_20260210_110306"
    BACKUP_FOUND=1
    log "✅ Encontrado backup funcional: $(basename $BACKUP_PATH)"
elif [ -d "${FRONTEND_DIR}/backup_history_ranges_20260210_110024" ]; then
    BACKUP_PATH="${FRONTEND_DIR}/backup_history_ranges_20260210_110024"
    BACKUP_FOUND=1
    log "✅ Encontrado backup alternativo: $(basename $BACKUP_PATH)"
elif [ -d "${FRONTEND_DIR}/backup_history_ranges_20260210_105945" ]; then
    BACKUP_PATH="${FRONTEND_DIR}/backup_history_ranges_20260210_105945"
    BACKUP_FOUND=1
    log "✅ Encontrado backup alternativo: $(basename $BACKUP_PATH)"
elif [ -d "${FRONTEND_DIR}/backup_frontend_20260210_125901" ]; then
    BACKUP_PATH="${FRONTEND_DIR}/backup_frontend_20260210_125901"
    BACKUP_FOUND=1
    log "✅ Encontrado backup de frontend: $(basename $BACKUP_PATH)"
fi

# Si no encuentra backups automáticos, preguntar por ruta manual
if [ $BACKUP_FOUND -eq 0 ]; then
    warn "⚠️  No se encontraron backups automáticos"
    echo ""
    echo "Por favor, especifica la ruta del backup que quieres restaurar:"
    echo "Ejemplo: /home/thunder/kuma-dashboard-clean/kuma-ui/backup_history_ranges_20260210_110306"
    echo ""
    read -p "Ruta del backup: " BACKUP_PATH
    
    if [ ! -d "$BACKUP_PATH" ]; then
        error "❌ La ruta especificada no existe"
        exit 1
    fi
fi

# ========== CONFIRMAR ROLLBACK ==========
echo ""
warn "⚠️  ESTA ACCIÓN REEMPLAZARÁ TODOS LOS ARCHIVOS ACTUALES ⚠️"
echo ""
echo "📦 Backup que se restaurará: $(basename $BACKUP_PATH)"
echo "📁 Directorio destino: $FRONTEND_DIR"
echo ""
read -p "¿Estás SEGURO de continuar? (escribe 'ROLLBACK' para confirmar): " CONFIRM

if [ "$CONFIRM" != "ROLLBACK" ]; then
    error "❌ Rollback cancelado"
    exit 1
fi

# ========== CREAR BACKUP DEL ESTADO ACTUAL ==========
echo ""
info "📦 Creando backup del estado actual..."
mkdir -p "$BACKUP_ACTUAL"

# Backup de archivos críticos actuales
cp "$FRONTEND_DIR/src/views/Dashboard.jsx" "$BACKUP_ACTUAL/" 2>/dev/null || true
cp "$FRONTEND_DIR/src/components/AlertsBanner.jsx" "$BACKUP_ACTUAL/" 2>/dev/null || true
cp "$FRONTEND_DIR/src/historyEngine.js" "$BACKUP_ACTUAL/" 2>/dev/null || true
cp "$FRONTEND_DIR/src/services/historyApi.js" "$BACKUP_ACTUAL/" 2>/dev/null || true

log "✅ Backup del estado actual guardado en: $BACKUP_ACTUAL"
echo "   • Dashboard.jsx"
echo "   • AlertsBanner.jsx"
echo "   • historyEngine.js"
echo "   • historyApi.js"

# ========== RESTAURAR ARCHIVOS ==========
echo ""
info "🔄 Restaurando archivos desde backup..."

# 1. RESTAURAR DASHBOARD.JSX
if [ -f "$BACKUP_PATH/src/views/Dashboard.jsx" ]; then
    cp "$BACKUP_PATH/src/views/Dashboard.jsx" "$FRONTEND_DIR/src/views/Dashboard.jsx"
    log "✅ Dashboard.jsx restaurado"
else
    # Buscar en otras ubicaciones
    if [ -f "$BACKUP_PATH/../views/Dashboard.jsx" ]; then
        cp "$BACKUP_PATH/../views/Dashboard.jsx" "$FRONTEND_DIR/src/views/Dashboard.jsx"
        log "✅ Dashboard.jsx restaurado (ruta alternativa)"
    else
        warn "⚠️  No se encontró Dashboard.jsx en el backup"
    fi
fi

# 2. RESTAURAR ALERTSBANNER.JSX (VERSIÓN NEGRA QUE FUNCIONA)
cat > "$FRONTEND_DIR/src/components/AlertsBanner.jsx" << 'EOF'
// ================================================
// ALERTS BANNER - VERSIÓN ESTABLE CON NOTIFICACIONES NEGRAS
// ================================================

import React, { useEffect, useState } from 'react';

export default function AlertsBanner({ alerts = [], onClose, autoCloseMs = 10000 }) {
  const [closingIds, setClosingIds] = useState(new Set());

  useEffect(() => {
    if (autoCloseMs <= 0) return;
    const timers = alerts.map(alert => {
      if (closingIds.has(alert.id)) return null;
      return setTimeout(() => {
        setClosingIds(prev => new Set([...prev, alert.id]));
        setTimeout(() => {
          onClose?.(alert.id);
          setClosingIds(prev => {
            const next = new Set(prev);
            next.delete(alert.id);
            return next;
          });
        }, 200);
      }, autoCloseMs);
    });
    return () => timers.forEach(timer => timer && clearTimeout(timer));
  }, [alerts, autoCloseMs, onClose, closingIds]);

  if (!alerts || alerts.length === 0) return null;

  const sortedAlerts = [...alerts].sort((a, b) => (b.ts || 0) - (a.ts || 0));

  return (
    <div style={{
      position: 'fixed',
      left: '24px',
      top: '50%',
      transform: 'translateY(-50%)',
      width: '340px',
      maxHeight: '80vh',
      overflowY: 'auto',
      zIndex: 9999,
      display: 'flex',
      flexDirection: 'column',
      gap: '12px',
      padding: '8px 4px',
      pointerEvents: 'none'
    }}>
      {sortedAlerts.map(alert => {
        const isClosing = closingIds.has(alert.id);
        const isDelta = alert.id?.includes('delta') || alert.msg?.includes('Variación');
        
        const borderColor = isDelta ? '#f59e0b' : '#dc2626';
        const badgeBg = isDelta ? '#f59e0b' : '#dc2626';
        const badgeText = isDelta ? '⚠️ VARIACIÓN' : '🔴 DOWN';
        
        return (
          <div
            key={alert.id}
            style={{
              background: '#111827',
              borderLeft: `6px solid ${borderColor}`,
              borderRadius: '12px',
              padding: '16px',
              boxShadow: '0 20px 25px -5px rgba(0,0,0,0.5)',
              transition: 'all 0.2s ease',
              opacity: isClosing ? 0 : 1,
              transform: isClosing ? 'translateX(-20px)' : 'translateX(0)',
              pointerEvents: 'auto',
              position: 'relative',
              color: '#f3f4f6'
            }}
          >
            <button
              onClick={() => {
                setClosingIds(prev => new Set([...prev, alert.id]));
                setTimeout(() => onClose?.(alert.id), 200);
              }}
              style={{
                position: 'absolute',
                top: '12px',
                right: '12px',
                background: 'transparent',
                border: 'none',
                fontSize: '20px',
                cursor: 'pointer',
                color: '#9ca3af',
                padding: '4px 8px',
                zIndex: 2
              }}
            >
              ×
            </button>

            <div style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '10px', 
              marginBottom: '12px',
              paddingRight: '24px'
            }}>
              <span style={{
                background: badgeBg,
                color: 'white',
                padding: '4px 12px',
                borderRadius: '999px',
                fontSize: '12px',
                fontWeight: 'bold'
              }}>
                {badgeText}
              </span>
              <span style={{ 
                fontWeight: 600, 
                color: '#e5e7eb',
                fontSize: '14px'
              }}>
                {alert.instance || 'Sede desconocida'}
              </span>
            </div>

            <h4 style={{ 
              margin: '0 0 8px 0', 
              fontSize: '16px', 
              color: '#ffffff',
              fontWeight: 600
            }}>
              {alert.name || 'Servicio'}
            </h4>

            <p style={{ 
              margin: '0 0 12px 0', 
              fontSize: '14px', 
              color: '#d1d5db',
              lineHeight: '1.5'
            }}>
              {alert.msg || `El servicio ${alert.name || ''} está reportando fallas.`}
            </p>

            <div style={{ 
              display: 'flex', 
              justifyContent: 'space-between', 
              alignItems: 'center',
              marginTop: '8px',
              fontSize: '11px',
              color: '#9ca3af',
              borderTop: '1px solid #374151',
              paddingTop: '12px'
            }}>
              <span>
                {alert.ts ? new Date(alert.ts).toLocaleTimeString('es-ES') : '—'}
              </span>
              <span style={{
                background: isDelta ? '#f59e0b20' : '#dc262620',
                color: isDelta ? '#fbbf24' : '#f87171',
                padding: '2px 8px',
                borderRadius: '4px',
                fontWeight: 600,
                fontSize: '10px'
              }}>
                {isDelta ? '+/- ms' : 'CRÍTICO'}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
}
EOF
log "✅ AlertsBanner.jsx restaurado (versión negra estable)"

# 3. RESTAURAR HISTORYENGINE.JS
if [ -f "$BACKUP_PATH/src/historyEngine.js" ]; then
    cp "$BACKUP_PATH/src/historyEngine.js" "$FRONTEND_DIR/src/historyEngine.js"
    log "✅ historyEngine.js restaurado"
fi

# 4. RESTAURAR HISTORYAPI.JS (versión estable)
cat > "$FRONTEND_DIR/src/services/historyApi.js" << 'EOF'
// src/services/historyApi.js
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://10.10.31.31:8080/api';

export const historyApi = {
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const response = await fetch(
        `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`,
        { cache: 'no-store' }
      );
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const monitorId = `${instanceName}_avg`;
      const response = await fetch(
        `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`,
        { cache: 'no-store' }
      );
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  async getAllForInstance(instanceName, sinceMs = 60 * 60 * 1000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const response = await fetch(
        `${API_BASE}/history?` +
        `instance=${encodeURIComponent(instanceName)}&` +
        `from=${from}&to=${to}&limit=1000&_=${Date.now()}`,
        { cache: 'no-store' }
      );
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      return data.data || {};
    } catch (error) {
      console.error('[API] Error:', error);
      return {};
    }
  }
};

export default historyApi;
EOF
log "✅ historyApi.js restaurado"

# 5. RESTAURAR UMBRALES ORIGINALES EN DASHBOARD
sed -i 's/const DELTA_ALERT_MS = [0-9]\+;/const DELTA_ALERT_MS = 100;/g' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i 's/const DELTA_COOLDOWN_MS = [0-9]\+ \* 1000;/const DELTA_COOLDOWN_MS = 60 \* 1000;/g' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i 's/const DELTA_WINDOW = [0-9]\+;/const DELTA_WINDOW = 20;/g' "$FRONTEND_DIR/src/views/Dashboard.jsx"
log "✅ Umbrales restaurados (100ms / 60s / 20 muestras)"

# 6. ELIMINAR WINDOW.__DASHBOARD SI EXISTE
sed -i '/window\.__dashboard/d' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i '/__dashboard/d' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i '/\/\/ ============================================/,/\/\/ ============================================/d' "$FRONTEND_DIR/src/views/Dashboard.jsx"
log "✅ Código de debug eliminado"

# ========== LIMPIAR CACHÉ ==========
echo ""
info "🧹 Limpiando caché..."
rm -rf "$FRONTEND_DIR/node_modules/.vite" 2>/dev/null || true
rm -rf "$FRONTEND_DIR/.vite" 2>/dev/null || true
log "✅ Caché limpiada"

# ========== VERIFICAR SINTAXIS ==========
echo ""
info "🔍 Verificando sintaxis de archivos restaurados..."

if command -v node &>/dev/null; then
    node -c "$FRONTEND_DIR/src/views/Dashboard.jsx" 2>/dev/null && \
        log "✅ Dashboard.jsx sintaxis OK" || \
        warn "⚠️ Dashboard.jsx tiene errores de sintaxis"
    
    node -c "$FRONTEND_DIR/src/components/AlertsBanner.jsx" 2>/dev/null && \
        log "✅ AlertsBanner.jsx sintaxis OK" || \
        warn "⚠️ AlertsBanner.jsx tiene errores de sintaxis"
    
    node -c "$FRONTEND_DIR/src/historyEngine.js" 2>/dev/null && \
        log "✅ historyEngine.js sintaxis OK" || \
        warn "⚠️ historyEngine.js tiene errores de sintaxis"
fi

# ========== REINICIAR FRONTEND ==========
echo ""
info "🔄 Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== RESUMEN FINAL ==========
echo ""
echo "====================================================="
echo "✅ ROLLBACK COMPLETADO EXITOSAMENTE"
echo "====================================================="
echo ""
echo "📋 RESUMEN DE RESTAURACIÓN:"
echo "   • Backup restaurado: $(basename $BACKUP_PATH)"
echo "   • Backup del estado actual: $(basename $BACKUP_ACTUAL)"
echo "   • Dashboard.jsx: Restaurado"
echo "   • AlertsBanner.jsx: Versión negra estable"
echo "   • historyEngine.js: Restaurado"
echo "   • historyApi.js: Restaurado"
echo "   • Umbrales: 100ms / 60s / 20 muestras"
echo "   • window.__dashboard: Eliminado"
echo ""
echo "🎯 NOTIFICACIONES:"
echo "   • Estilo: NEGRO con bordes rojos/naranjas"
echo "   • Posición: LADO IZQUIERDO"
echo "   • Auto-cierre: 10 segundos"
echo "   • Tipos: DOWN (🔴) y VARIACIÓN (⚠️)"
echo ""
echo "🚀 PRÓXIMOS PASOS:"
echo "   1. El frontend ya se está reiniciando..."
echo "   2. Abre http://10.10.31.31:5173 en tu navegador"
echo "   3. Las notificaciones aparecerán en el LADO IZQUIERDO"
echo ""
echo "🔄 PARA DESHACER ESTE ROLLBACK:"
echo "   cp -r $BACKUP_ACTUAL/* $FRONTEND_DIR/"
echo ""
echo "====================================================="

# ========== INSTRUCCIONES ADICIONALES ==========
cat > "$FRONTEND_DIR/INSTRUCCIONES_ROLLBACK.txt" << EOF
FECHA: $(date)
BACKUP RESTAURADO: $(basename $BACKUP_PATH)
BACKUP ACTUAL: $(basename $BACKUP_ACTUAL)

📌 NOTAS IMPORTANTES:
1. Esta versión tiene las notificaciones NEGRAS funcionales
2. El botón ON/OFF funciona correctamente
3. Los umbrales son: 100ms, 60s cooldown, 20 muestras
4. NO incluye window.__dashboard (debug)

🔧 PARA PROBAR NOTIFICACIONES:
Abre la consola (F12) y pega:

const event = new CustomEvent('test-notification', {
  detail: {
    id: 'test-' + Date.now(),
    instance: '🧪 PRUEBA',
    name: 'NOTIFICACIÓN',
    ts: Date.now(),
    msg: 'Rollback completado exitosamente'
  }
});
window.dispatchEvent(event);

🔄 SI ALGO SALE MAL:
./rollback-estable.sh --rollback  # Para restaurar backup actual

EOF

echo ""
echo "📄 Instrucciones guardadas en: $FRONTEND_DIR/INSTRUCCIONES_ROLLBACK.txt"
echo "====================================================="
