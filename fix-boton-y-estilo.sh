#!/bin/bash
# fix-boton-y-estilo.sh - CORRIGE BOTÓN Y MANTIENE ESTILO NEGRO

echo "🔧 CORRIGIENDO BOTÓN DE NOTIFICACIONES Y ESTILO NEGRO"
echo "===================================================="

DASHBOARD_FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/views/Dashboard.jsx"
ALERTS_FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/components/AlertsBanner.jsx"
BACKUP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui/backup_notificaciones_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"
cp "$DASHBOARD_FILE" "$BACKUP_DIR/Dashboard.jsx.bak"
cp "$ALERTS_FILE" "$BACKUP_DIR/AlertsBanner.jsx.bak"
echo "✅ Backups creados en: $BACKUP_DIR"

# ===== CORREGIR BOTÓN EN DASHBOARD =====
echo "📝 Corrigiendo botón de notificaciones..."

# Buscar y reemplazar el bloque del botón
sed -i '/{·*Botón Notificaciones/,/<\/button>/c\
                {/* Botón Notificaciones - CORREGIDO */}\
                <button\
                  type="button"\
                  className={`k-btn ${notificationsEnabled ? '\''is-active'\'' : '\'\''}`}\
                  onClick={async (e) => {\
                    e.preventDefault();\
                    console.log('\''🔔 Botón clickeado. Estado actual:'\'', notificationsEnabled);\
                    if (notificationsEnabled === false) {\
                      console.log('\''🟡 Intentando activar notificaciones...'\'');\
                      if (!('\''Notification'\'' in window)) {\
                        alert('\''Tu navegador no soporta notificaciones'\'');\
                        return;\
                      }\
                      if (Notification.permission === '\''granted'\'') {\
                        console.log('\''✅ Permiso ya concedido, activando...'\'');\
                        setNotificationsEnabled(true);\
                        new Notification('\''🔔 Notificaciones activadas'\'', {\
                          body: '\''Recibirás alertas de DOWN y variaciones'\'',\
                          silent: true\
                        });\
                      } else if (Notification.permission === '\''default'\'') {\
                        console.log('\''🟡 Solicitando permiso...'\'');\
                        const permission = await Notification.requestPermission();\
                        console.log('\''📝 Permiso resultado:'\'', permission);\
                        if (permission === '\''granted'\'') {\
                          setNotificationsEnabled(true);\
                          new Notification('\''✅ Notificaciones activadas'\'', {\
                            body: '\''Ahora recibirás alertas'\'',\
                            silent: true\
                          });\
                        } else {\
                          setNotificationsEnabled(false);\
                          alert('\''No concediste permiso para notificaciones'\'');\
                        }\
                      } else {\
                        console.log('\''❌ Permiso denegado'\'');\
                        alert('\''Las notificaciones están bloqueadas. Actívalas en la configuración del navegador.'\'');\
                        setNotificationsEnabled(false);\
                      }\
                    } else {\
                      console.log('\''🔴 Apagando notificaciones...'\'');\
                      setNotificationsEnabled(false);\
                      if (Notification.permission === '\''granted'\'') {\
                        new Notification('\''🔕 Notificaciones desactivadas'\'', {\
                          body: '\''Ya no recibirás alertas'\'',\
                          silent: true\
                        });\
                      }\
                    }\
                  }}\
                  style={{\
                    fontSize: "\''0.8rem\''",\
                    background: notificationsEnabled ? '\''#16a34a'\'' : '\''transparent'\'',\
                    color: notificationsEnabled ? '\''white'\'' : '\''#1f2937'\'',\
                    borderColor: notificationsEnabled ? '\''#16a34a'\'' : '\''#e5e7eb'\'',\
                    cursor: '\''pointer'\'',\
                    padding: '\''6px 12px'\'',\
                    borderRadius: '\''6px'\'',\
                    fontWeight: notificationsEnabled ? '\''600'\'' : '\''400'\''\
                  }}\
                >\
                  🔔 Notificaciones: {notificationsEnabled ? '\''ON'\'' : '\''OFF'\''}\
                </button>' "$DASHBOARD_FILE"

echo "✅ Botón corregido"

# ===== MANTENER ESTILO NEGRO =====
echo "🎨 Aplicando estilo NEGRO a las notificaciones..."

cat > "$ALERTS_FILE" << 'EOF'
// ================================================
// ALERTS BANNER - NOTIFICACIONES PUSH NEGRAS
// ================================================

import React, { useEffect, useState } from 'react';

export default function AlertsBanner({ alerts = [], onClose, autoCloseMs = 12000 }) {
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

echo "✅ Estilo negro aplicado"

echo ""
echo "🔄 Reiniciando frontend..."
cd "/home/thunder/kuma-dashboard-clean/kuma-ui"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo ""
echo "===================================================="
echo "✅ TODO CORREGIDO!"
echo "===================================================="
echo ""
echo "🎯 PRUEBA EL BOTÓN AHORA:"
echo "   1. Haz click en 'Notificaciones: OFF'"
echo "   2. ✅ Concede permiso"
echo "   3. ✅ Se pondrá verde 'ON'"
echo "   4. ✅ Notificación negra de confirmación"
echo ""
echo "🎨 NOTIFICACIONES NEGRAS MANTENIDAS"
echo ""
echo "🔄 Para apagar: click en 'Notificaciones: ON' → OFF"
echo "🔄 Para encender: click en 'Notificaciones: OFF' → ON"
echo ""
echo "===================================================="
