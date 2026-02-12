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
