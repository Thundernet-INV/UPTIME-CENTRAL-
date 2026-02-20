// src/hooks/useMonitorNotifications.js
import { useEffect, useRef } from 'react';
import { notify } from '../utils/notify.js';

export function useMonitorNotifications(monitors = [], enabled = true) {
  const prevMonitorsRef = useRef({});

  useEffect(() => {
    if (!enabled || !monitors.length) return;

    const prev = prevMonitorsRef.current;
    const changes = [];

    monitors.forEach(monitor => {
      const id = `${monitor.instance}_${monitor.info?.monitor_name}`;
      const prevStatus = prev[id];
      const currentStatus = monitor.latest?.status;
      const currentRT = monitor.latest?.responseTime;

      // Detectar cambios de DOWN a UP o UP a DOWN
      if (prevStatus !== undefined && prevStatus !== currentStatus) {
        if (currentStatus === 0 || currentRT === -1) {
          changes.push({
            type: 'DOWN',
            monitor: monitor.info?.monitor_name,
            instance: monitor.instance,
            message: `🔴 ${monitor.info?.monitor_name} en ${monitor.instance} está DOWN`
          });
        } else if (currentStatus === 1 && (prevStatus === 0 || prevStatus === -1)) {
          changes.push({
            type: 'UP',
            monitor: monitor.info?.monitor_name,
            instance: monitor.instance,
            message: `🟢 ${monitor.info?.monitor_name} en ${monitor.instance} está UP nuevamente`
          });
        }
      }

      // Guardar estado actual
      prev[id] = currentStatus;
    });

    // Enviar notificaciones
    changes.forEach(change => {
      notify('Cambio de estado', change.message);
    });

    prevMonitorsRef.current = prev;
  }, [monitors, enabled]);
}
