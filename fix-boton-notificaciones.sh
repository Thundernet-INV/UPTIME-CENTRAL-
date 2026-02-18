#!/bin/bash
# fix-boton-notificaciones.sh - Corrige el botón de notificaciones

echo "🔧 CORRIGIENDO BOTÓN DE NOTIFICACIONES"
echo "======================================="

DASHBOARD_FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/views/Dashboard.jsx"
BACKUP_FILE="$DASHBOARD_FILE.backup.boton.$(date +%s)"

# Hacer backup
cp "$DASHBOARD_FILE" "$BACKUP_FILE"
echo "✅ Backup creado: $BACKUP_FILE"

# Buscar y reemplazar el botón de notificaciones
sed -i '/{·*Botón Notificaciones/,/<\/button>/c\
                {/* Botón Notificaciones ON/OFF - CORREGIDO */}\
                <button\
                  type="button"\
                  className={`k-btn ${notificationsEnabled ? '\''is-active'\'' : '\'\''}`}\
                  onClick={async () => {\
                    if (!notificationsEnabled) {\
                      if (!('\''Notification'\'' in window)) {\
                        alert('\''Tu navegador no soporta notificaciones'\'');\
                        return;\
                      }\
                      if (Notification.permission === '\''default'\'') {\
                        const permission = await Notification.requestPermission();\
                        setNotificationsEnabled(permission === '\''granted'\'');\
                        if (permission === '\''granted'\'') {\
                          new Notification('\''✅ Notificaciones activadas'\'', {\
                            body: '\''Ahora recibirás alertas de DOWN y variaciones'\'',\
                            silent: true\
                          });\
                        }\
                      } else if (Notification.permission === '\''granted'\'') {\
                        setNotificationsEnabled(true);\
                        new Notification('\''✅ Notificaciones activadas'\'', {\
                          body: '\''Ahora recibirás alertas de DOWN y variaciones'\'',\
                          silent: true\
                        });\
                      } else {\
                        alert('\''Las notificaciones están bloqueadas. Actívalas en la configuración de tu navegador.'\'');\
                        setNotificationsEnabled(false);\
                      }\
                    } else {\
                      setNotificationsEnabled(false);\
                    }\
                  }}\
                  style={{\
                    fontSize: "\''0.8rem\''",\
                    background: notificationsEnabled ? '\''#16a34a'\'' : '\''transparent'\'',\
                    color: notificationsEnabled ? '\''white'\'' : '\''#1f2937'\'',\
                    borderColor: notificationsEnabled ? '\''#16a34a'\'' : '\''#e5e7eb'\'',\
                    cursor: '\''pointer'\'',\
                    transition: '\''all 0.2s ease'\''\
                  }}\
                >\
                  🔔 Notificaciones: {notificationsEnabled ? '\''ON'\'' : '\''OFF'\''}\
                </button>' "$DASHBOARD_FILE"

echo "✅ Botón corregido"

echo ""
echo "🔄 Reiniciando frontend..."
cd "/home/thunder/kuma-dashboard-clean/kuma-ui"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo ""
echo "======================================="
echo "✅ CORREGIDO! Prueba el botón ahora:"
echo "======================================="
echo ""
echo "1. Haz click en 'Notificaciones: OFF'"
echo "2. El navegador pedirá permiso - CONCÉDELO"
echo "3. Verás una notificación de confirmación"
echo "4. El botón cambiará a verde 'Notificaciones: ON'"
echo ""
echo "======================================="
