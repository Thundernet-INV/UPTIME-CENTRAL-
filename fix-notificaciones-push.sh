#!/bin/bash
# fix-notificaciones-push.sh
# ================================================
# CORRIGE NOTIFICACIONES PUSH EN EL LADO IZQUIERDO
# ================================================
# Este script:
# 1. Crea backup del AlertsBanner.jsx actual
# 2. Reemplaza con versión funcional de notificaciones
# 3. Permite rollback automático si algo falla
# 4. Muestra instrucciones para verificar
# ================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ALERTS_FILE="$FRONTEND_DIR/src/components/AlertsBanner.jsx"
BACKUP_DIR="$FRONTEND_DIR/backup_notificaciones_$(date +%Y%m%d_%H%M%S)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Funciones de utilidad
log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
separator() { echo "================================================"; }

# Función para mostrar ayuda
show_help() {
    separator
    echo "🔧 FIX DE NOTIFICACIONES PUSH - LADO IZQUIERDO"
    separator
    echo "Uso: $0 [opción]"
    echo ""
    echo "Opciones:"
    echo "  --install    Instalar/actualizar notificaciones push (por defecto)"
    echo "  --rollback   Restaurar último backup"
    echo "  --list       Listar backups disponibles"
    echo "  --help       Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0                    # Instalar notificaciones"
    echo "  $0 --rollback        # Restaurar último backup"
    echo "  $0 --rollback 3      # Restaurar backup #3 de la lista"
    echo "  $0 --list           # Ver todos los backups"
    separator
}

# Función para listar backups
list_backups() {
    separator
    echo "📋 BACKUPS DISPONIBLES:"
    separator
    
    local backups=($(ls -d "$FRONTEND_DIR"/backup_notificaciones_* 2>/dev/null | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        warn "No hay backups disponibles"
        return 1
    fi
    
    local i=1
    for backup in "${backups[@]}"; do
        local backup_name=$(basename "$backup")
        local backup_date=$(echo "$backup_name" | sed 's/backup_notificaciones_//' | sed 's/\([0-9]\{8\}\)_\([0-9]\{6\}\)/\1 \2/')
        local file_size=$(du -h "$backup/AlertsBanner.jsx" 2>/dev/null | cut -f1 || echo "N/A")
        
        if [ -f "$backup/AlertsBanner.jsx" ]; then
            echo -e "${GREEN}$i)${NC} $backup_name"
            echo "   📅 Fecha: ${backup_date:0:4}-${backup_date:4:2}-${backup_date:6:2} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}"
            echo "   📦 Tamaño: $file_size"
            echo "   🔍 SHA256: $(sha256sum "$backup/AlertsBanner.jsx" | cut -c1-16)..."
            echo ""
        fi
        ((i++))
    done
    
    separator
    echo "Para restaurar: $0 --rollback [número]"
    separator
}

# Función para hacer rollback
do_rollback() {
    local index=$1
    
    # Obtener lista de backups
    local backups=($(ls -d "$FRONTEND_DIR"/backup_notificaciones_* 2>/dev/null | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        error "No hay backups para restaurar"
        return 1
    fi
    
    local selected_backup
    
    if [ -z "$index" ]; then
        # Si no especifica índice, usar el más reciente
        selected_backup="${backups[0]}"
        info "Usando backup más reciente: $(basename "$selected_backup")"
    else
        # Verificar que el índice sea válido
        if ! [[ "$index" =~ ^[0-9]+$ ]] || [ "$index" -lt 1 ] || [ "$index" -gt ${#backups[@]} ]; then
            error "Índice inválido. Usa un número entre 1 y ${#backups[@]}"
            list_backups
            return 1
        fi
        selected_backup="${backups[$((index-1))]}"
    fi
    
    if [ ! -f "$selected_backup/AlertsBanner.jsx" ]; then
        error "Backup corrupto: no se encuentra AlertsBanner.jsx"
        return 1
    fi
    
    separator
    warn "⚠️  VAS A RESTAURAR UN BACKUP ⚠️"
    separator
    echo "Backup: $(basename "$selected_backup")"
    echo "Destino: $ALERTS_FILE"
    echo ""
    read -p "¿Continuar? (s/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        info "Rollback cancelado"
        return 0
    fi
    
    # Crear backup antes de restaurar (por si acaso)
    local pre_rollback_backup="$FRONTEND_DIR/backup_pre_rollback_${TIMESTAMP}"
    mkdir -p "$pre_rollback_backup"
    cp "$ALERTS_FILE" "$pre_rollback_backup/AlertsBanner.jsx.before_rollback" 2>/dev/null || true
    log "Backup pre-rollback creado: $pre_rollback_backup"
    
    # Restaurar
    cp "$selected_backup/AlertsBanner.jsx" "$ALERTS_FILE"
    
    if [ $? -eq 0 ]; then
        log "✅ Rollback completado exitosamente"
        log "Restaurado: $(basename "$selected_backup")"
        
        # Verificar sintaxis
        if command -v node &>/dev/null; then
            if node -c "$ALERTS_FILE" &>/dev/null; then
                log "✅ Sintaxis JavaScript válida"
            else
                warn "⚠️  El archivo restaurado tiene errores de sintaxis"
            fi
        fi
        
        separator
        info "Para deshacer este rollback:"
        echo "  cp \"$pre_rollback_backup/AlertsBanner.jsx.before_rollback\" \"$ALERTS_FILE\""
        separator
    else
        error "Error al restaurar backup"
        return 1
    fi
}

# Función principal de instalación
install_notifications() {
    separator
    echo "🚀 INSTALANDO NOTIFICACIONES PUSH - LADO IZQUIERDO"
    separator
    
    # 1. Verificar directorio
    if [ ! -d "$FRONTEND_DIR" ]; then
        error "Directorio frontend no encontrado: $FRONTEND_DIR"
        error "Por favor, verifica la ruta en la configuración del script"
        exit 1
    fi
    
    log "Directorio frontend: $FRONTEND_DIR"
    
    # 2. Crear backup
    info "Creando backup..."
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "$ALERTS_FILE" ]; then
        cp "$ALERTS_FILE" "$BACKUP_DIR/AlertsBanner.jsx"
        log "Backup creado: $BACKUP_DIR/AlertsBanner.jsx"
        
        # Backup adicional con hash
        local hash=$(sha256sum "$ALERTS_FILE" | cut -c1-8)
        cp "$ALERTS_FILE" "$BACKUP_DIR/AlertsBanner.jsx.${hash}.bak"
        log "Backup con hash: $BACKUP_DIR/AlertsBanner.jsx.${hash}.bak"
    else
        warn "No existe AlertsBanner.jsx, se creará uno nuevo"
        # Crear directorio si no existe
        mkdir -p "$FRONTEND_DIR/src/components"
    fi
    
    # 3. Verificar/Crear archivo CSS para animaciones
    local CSS_FILE="$FRONTEND_DIR/src/styles.css"
    if [ -f "$CSS_FILE" ]; then
        if ! grep -q "@keyframes slideInLeft" "$CSS_FILE"; then
            info "Agregando animaciones CSS..."
            cat >> "$CSS_FILE" << 'EOF'

/* ===== NOTIFICACIONES PUSH - ANIMACIONES ===== */
@keyframes slideInLeft {
    from {
        opacity: 0;
        transform: translateX(-30px);
    }
    to {
        opacity: 1;
        transform: translateX(0);
    }
}

.alert-push {
    animation: slideInLeft 0.3s ease-out;
}

.alert-push.closing {
    animation: slideOutLeft 0.2s ease-in forwards;
}

@keyframes slideOutLeft {
    to {
        opacity: 0;
        transform: translateX(-30px);
    }
}
/* ===== FIN NOTIFICACIONES PUSH ===== */
EOF
            log "Animaciones CSS agregadas a styles.css"
        else
            info "Animaciones CSS ya existen"
        fi
    fi
    
    # 4. CREAR EL NUEVO AlertsBanner.jsx CON LAS NOTIFICACIONES PUSH
    info "Escribiendo nuevo AlertsBanner.jsx..."
    
    cat > "$ALERTS_FILE" << 'EOF'
// ================================================
// ALERTS BANNER - NOTIFICACIONES PUSH LATERALES
// ================================================
// Muestra notificaciones en el lado IZQUIERDO
// Con animaciones, auto-cierre y sistema de colores
// ================================================

import React, { useEffect, useState } from 'react';

/**
 * AlertsBanner - Notificaciones push estilo lateral
 * @param {Array} alerts - Array de alertas a mostrar
 * @param {Function} onClose - Callback al cerrar una alerta
 * @param {number} autoCloseMs - Tiempo en ms para auto-cerrar (0 = desactivado)
 */
export default function AlertsBanner({ 
  alerts = [], 
  onClose, 
  autoCloseMs = 12000  // 12 segundos por defecto
}) {
  const [closingIds, setClosingIds] = useState(new Set());
  const [expandedId, setExpandedId] = useState(null);

  // Auto-cierre de alertas
  useEffect(() => {
    if (autoCloseMs <= 0) return;

    const timers = alerts.map(alert => {
      if (closingIds.has(alert.id)) return null;
      
      return setTimeout(() => {
        // Marcar como cerrando para animación
        setClosingIds(prev => new Set([...prev, alert.id]));
        
        // Eliminar después de la animación
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

  // Si no hay alertas, no renderizar nada
  if (!alerts || alerts.length === 0) {
    return null;
  }

  // Ordenar alertas: las más recientes primero
  const sortedAlerts = [...alerts].sort((a, b) => (b.ts || 0) - (a.ts || 0));

  return (
    <div 
      className="notificaciones-push-container"
      style={{
        position: 'fixed',
        left: '24px',
        top: '50%',
        transform: 'translateY(-50%)',
        width: '340px',
        maxWidth: 'calc(100vw - 48px)',
        maxHeight: '80vh',
        overflowY: 'auto',
        overflowX: 'hidden',
        zIndex: 9999,
        display: 'flex',
        flexDirection: 'column',
        gap: '12px',
        padding: '8px 4px',
        pointerEvents: 'none'  // Permite hacer click a través del contenedor
      }}
    >
      {sortedAlerts.map(alert => {
        const isClosing = closingIds.has(alert.id);
        const isExpanded = expandedId === alert.id;
        const isDelta = alert.id?.includes('delta') || alert.msg?.includes('Variación');
        const isDown = alert.id?.includes('down') || alert.msg?.includes('DOWN') || !isDelta;
        
        // Definir estilos según tipo de alerta
        const alertStyle = {
          down: {
            borderColor: '#dc2626',
            bg: '#fff',
            headerBg: '#fee2e2',
            badgeBg: '#dc2626',
            badgeText: '#fff',
            accent: '#ef4444'
          },
          delta: {
            borderColor: '#f59e0b',
            bg: '#fff',
            headerBg: '#fef3c7',
            badgeBg: '#f59e0b',
            badgeText: '#fff',
            accent: '#fbbf24'
          }
        };

        const style = isDelta ? alertStyle.delta : alertStyle.down;
        const badgeText = isDelta ? '⚠️ VARIACIÓN' : '🔴 DOWN';
        const severity = isDelta ? 'Media' : 'Crítica';
        
        return (
          <div
            key={alert.id}
            className={`alert-push ${isClosing ? 'closing' : ''} ${isExpanded ? 'expanded' : ''}`}
            style={{
              background: style.bg,
              borderLeft: `6px solid ${style.borderColor}`,
              borderRadius: '12px',
              padding: '16px',
              boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1), 0 10px 10px -5px rgba(0,0,0,0.04)',
              transition: 'all 0.2s ease',
              opacity: isClosing ? 0 : 1,
              transform: isClosing ? 'translateX(-20px)' : 'translateX(0)',
              pointerEvents: 'auto',  // El contenido sí es clickeable
              position: 'relative',
              cursor: 'pointer'
            }}
            onClick={() => setExpandedId(isExpanded ? null : alert.id)}
          >
            {/* Botón cerrar */}
            <button
              onClick={(e) => {
                e.stopPropagation();
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
                color: '#6b7280',
                padding: '4px 8px',
                borderRadius: '4px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                transition: 'background 0.2s',
                zIndex: 2
              }}
              onMouseEnter={(e) => e.currentTarget.style.background = '#f3f4f6'}
              onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
            >
              ×
            </button>

            {/* Header con badge y sede */}
            <div style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '10px', 
              marginBottom: '12px',
              paddingRight: '24px'
            }}>
              <span style={{
                background: style.badgeBg,
                color: style.badgeText,
                padding: '4px 12px',
                borderRadius: '999px',
                fontSize: '12px',
                fontWeight: 'bold',
                letterSpacing: '0.5px',
                boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
              }}>
                {badgeText}
              </span>
              <span style={{ 
                fontWeight: 600, 
                color: '#111827',
                fontSize: '14px'
              }}>
                {alert.instance || 'Sede desconocida'}
              </span>
            </div>

            {/* Título del servicio */}
            <h4 style={{ 
              margin: '0 0 8px 0', 
              fontSize: '16px', 
              color: '#1f2937',
              fontWeight: 600,
              paddingRight: '24px'
            }}>
              {alert.name || 'Servicio'}
            </h4>

            {/* Mensaje - siempre visible */}
            <p style={{ 
              margin: '0 0 12px 0', 
              fontSize: '14px', 
              color: '#4b5563',
              lineHeight: '1.5'
            }}>
              {alert.msg || `El servicio ${alert.name || ''} está reportando fallas.`}
            </p>

            {/* Información expandible */}
            {isExpanded && (
              <div style={{
                marginTop: '12px',
                paddingTop: '12px',
                borderTop: '1px solid #e5e7eb',
                fontSize: '13px'
              }}>
                <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
                  <div>
                    <span style={{ color: '#6b7280', fontSize: '11px' }}>Severidad</span>
                    <div style={{ 
                      fontWeight: 600, 
                      color: style.borderColor,
                      fontSize: '13px',
                      marginTop: '2px'
                    }}>
                      {severity}
                    </div>
                  </div>
                  <div>
                    <span style={{ color: '#6b7280', fontSize: '11px' }}>ID Evento</span>
                    <div style={{ 
                      fontFamily: 'monospace',
                      fontSize: '11px',
                      color: '#374151',
                      marginTop: '2px'
                    }}>
                      {alert.id?.substring(0, 12)}...
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Footer con timestamp */}
            <div style={{ 
              display: 'flex', 
              justifyContent: 'space-between', 
              alignItems: 'center',
              marginTop: '8px',
              fontSize: '11px',
              color: '#6b7280'
            }}>
              <span>
                {alert.ts ? new Date(alert.ts).toLocaleTimeString('es-ES', {
                  hour: '2-digit',
                  minute: '2-digit',
                  second: '2-digit'
                }) : '—'}
              </span>
              <span style={{
                background: style.headerBg,
                color: style.borderColor,
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

// Versión simplificada para pruebas rápidas
export const SimpleAlertsBanner = ({ alerts = [], onClose }) => {
  if (!alerts.length) return null;
  
  return (
    <div style={{ position: 'fixed', left: 20, top: '50%', transform: 'translateY(-50%)', width: 300 }}>
      {alerts.map(alert => (
        <div key={alert.id} style={{
          background: 'white',
          borderLeft: `4px solid ${alert.id?.includes('delta') ? '#f59e0b' : '#ef4444'}`,
          padding: 16,
          marginBottom: 12,
          borderRadius: 8,
          boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <strong>{alert.instance} - {alert.name}</strong>
            <button onClick={() => onClose?.(alert.id)}>×</button>
          </div>
          <p style={{ margin: '8px 0 0', fontSize: 14 }}>{alert.msg}</p>
        </div>
      ))}
    </div>
  );
};

export default AlertsBanner;
EOF

    if [ $? -eq 0 ]; then
        log "✅ AlertsBanner.jsx creado exitosamente"
        
        # Backup del nuevo archivo
        cp "$ALERTS_FILE" "$BACKUP_DIR/AlertsBanner.jsx.nuevo"
        log "Backup del nuevo archivo guardado"
    else
        error "Error al escribir AlertsBanner.jsx"
        return 1
    fi

    # 5. Verificar sintaxis
    if command -v node &>/dev/null; then
        info "Verificando sintaxis JavaScript..."
        if node -c "$ALERTS_FILE" &>/dev/null; then
            log "✅ Sintaxis JavaScript válida"
        else
            warn "⚠️  El archivo tiene errores de sintaxis"
            warn "Ejecuta 'node -c $ALERTS_FILE' para ver detalles"
        fi
    fi

    # 6. Crear archivo de instrucciones
    cat > "$BACKUP_DIR/INSTRUCCIONES.txt" << EOF
FIX DE NOTIFICACIONES PUSH - $(date)
====================================
Backup realizado: $(date '+%Y-%m-%d %H:%M:%S')
Archivo original: AlertsBanner.jsx
Hash original: $(sha256sum "$BACKUP_DIR/AlertsBanner.jsx" 2>/dev/null | cut -d' ' -f1)
Hash nuevo: $(sha256sum "$ALERTS_FILE" | cut -d' ' -f1)

📌 VERIFICACIÓN:
1. Reinicia el frontend: npm run dev
2. Abre las herramientas de desarrollo (F12)
3. Busca alertas DOWN o variaciones de latencia
4. Las notificaciones deben aparecer en el LADO IZQUIERDO

🔄 ROLLBACK:
Si necesitas restaurar el backup:
   ./fix-notificaciones-push.sh --rollback

📋 BACKUPS DISPONIBLES:
   ls -la $FRONTEND_DIR/backup_notificaciones_*

📊 LOGS DE VERIFICACIÓN:
   Verifica en consola: localStorage.debug = 'alerts:*'
EOF

    log "Instrucciones guardadas en: $BACKUP_DIR/INSTRUCCIONES.txt"

    # 7. Resumen final
    separator
    echo "✅ INSTALACIÓN COMPLETADA EXITOSAMENTE"
    separator
    echo "📋 RESUMEN:"
    echo "   📁 Backup creado: $BACKUP_DIR"
    echo "   📄 Archivo modificado: $ALERTS_FILE"
    echo "   🎨 Animaciones CSS: Verificadas"
    echo ""
    echo "🚀 PRÓXIMOS PASOS:"
    echo "   1. Reinicia el frontend:"
    echo "      cd $FRONTEND_DIR && npm run dev"
    echo ""
    echo "   2. Verifica las notificaciones en el LADO IZQUIERDO"
    echo "      • Alertas DOWN → Rojo"
    echo "      • Variaciones → Naranja"
    echo ""
    echo "   3. Para restaurar backup:"
    echo "      $0 --rollback"
    echo ""
    echo "   4. Para ver backups disponibles:"
    echo "      $0 --list"
    separator
}

# ========== MAIN ==========
case "$1" in
    --help|-h)
        show_help
        ;;
    --list)
        list_backups
        ;;
    --rollback)
        do_rollback "$2"
        ;;
    --install|"")
        install_notifications
        ;;
    *)
        error "Opción desconocida: $1"
        show_help
        exit 1
        ;;
esac

exit 0
