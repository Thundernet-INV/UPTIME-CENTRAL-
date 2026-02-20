// src/hooks/usePlantaData.js - VERSIÓN OPTIMIZADA
import { useState, useEffect, useCallback, useRef, useMemo } from 'react';

export function usePlantaData() {
  const [plantas, setPlantas] = useState([]);
  const [estados, setEstados] = useState({});
  const [consumos, setConsumos] = useState({});
  const [loading, setLoading] = useState(true);
  const [timestamp, setTimestamp] = useState(Date.now());
  
  // Usar refs para evitar re-renders innecesarios
  const intervalRef = useRef(null);
  const isMountedRef = useRef(true);

  // Cargar plantas configuradas (solo una vez al inicio)
  useEffect(() => {
    let isMounted = true;
    
    const cargarPlantas = async () => {
      try {
        const res = await fetch('http://10.10.31.31:8080/api/combustible/plantas');
        const data = await res.json();
        if (data.success && isMounted) {
          setPlantas(data.data);
        }
      } catch (error) {
        console.error('Error cargando plantas:', error);
      } finally {
        if (isMounted) setLoading(false);
      }
    };
    
    cargarPlantas();
    
    return () => {
      isMounted = false;
    };
  }, []);

  // Cargar estados y consumos con debounce
  useEffect(() => {
    if (plantas.length === 0) return;
    
    let isMounted = true;
    let timeoutId = null;
    
    const cargarDatos = async () => {
      try {
        // Cargar estados del summary
        const resEstados = await fetch('http://10.10.31.31:8080/api/summary');
        const dataEstados = await resEstados.json();
        
        if (!isMounted) return;
        
        const monitoresEnergia = dataEstados.monitors?.filter(m => 
          (m.instance === 'Energia' || m.instance === 'Energía') && 
          m.info?.monitor_name?.startsWith('PLANTA')
        ) || [];
        
        const nuevosEstados = {};
        monitoresEnergia.forEach(m => {
          nuevosEstados[m.info.monitor_name] = {
            status: m.latest?.status === 1 ? 'UP' : 'DOWN',
            responseTime: m.latest?.responseTime || 0,
            lastCheck: m.latest?.timestamp || Date.now()
          };
        });
        
        setEstados(nuevosEstados);
        
        // Cargar consumos (solo de plantas que tenemos)
        const nuevosConsumos = { ...consumos };
        let cambios = false;
        
        await Promise.all(plantas.map(async (planta) => {
          try {
            const res = await fetch(`http://10.10.31.31:8080/api/combustible/consumo/${encodeURIComponent(planta.nombre_monitor)}`);
            if (res.ok) {
              const data = await res.json();
              if (data.success && isMounted) {
                nuevosConsumos[planta.nombre_monitor] = {
                  sesionActual: data.data.consumo_actual_sesion || 0,
                  historico: data.data.consumo_total_historico || 0,
                  esta_encendida: data.data.esta_encendida_ahora || false
                };
                cambios = true;
              }
            }
          } catch (e) {
            // Silenciar errores de red
          }
        }));
        
        if (cambios && isMounted) {
          setConsumos(nuevosConsumos);
        }
        
        setTimestamp(Date.now());
        
      } catch (error) {
        // Silenciar errores
      }
    };
    
    // Ejecutar inmediatamente
    cargarDatos();
    
    // Luego cada 5 segundos con debounce
    intervalRef.current = setInterval(() => {
      if (timeoutId) clearTimeout(timeoutId);
      timeoutId = setTimeout(cargarDatos, 100);
    }, 5000);
    
    return () => {
      isMounted = false;
      if (intervalRef.current) clearInterval(intervalRef.current);
      if (timeoutId) clearTimeout(timeoutId);
    };
  }, [plantas]); // Solo depende de plantas

  // Funciones memoizadas
  const getResumenPorSede = useCallback(() => {
    const resumen = {};
    
    plantas.forEach(p => {
      const sede = p.sede;
      if (!resumen[sede]) {
        resumen[sede] = {
          totalPlantas: 0,
          plantasEncendidas: 0,
          totalConsumo: 0
        };
      }
      resumen[sede].totalPlantas++;
      if (estados[p.nombre_monitor]?.status === 'UP') {
        resumen[sede].plantasEncendidas++;
      }
      resumen[sede].totalConsumo += consumos[p.nombre_monitor]?.historico || 0;
    });
    
    return resumen;
  }, [plantas, estados, consumos]);

  const getPlantasPorSede = useCallback((sede) => {
    if (sede === 'todas') return plantas;
    return plantas.filter(p => p.sede === sede);
  }, [plantas]);

  const actualizarPlanta = useCallback(async (nombreOriginal, datosActualizados) => {
    try {
      const res = await fetch(`http://10.10.31.31:8080/api/combustible/plantas/${encodeURIComponent(nombreOriginal)}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(datosActualizados)
      });
      
      const data = await res.json();
      if (data.success) {
        // Actualizar estado local inmediatamente
        setPlantas(prev => prev.map(p => 
          p.nombre_monitor === nombreOriginal ? datosActualizados : p
        ));
        return { success: true };
      }
      return { success: false, error: data.error };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }, []);

  const resetearPlanta = useCallback(async (nombreMonitor) => {
    try {
      const res = await fetch(`http://10.10.31.31:8080/api/combustible/reset/${encodeURIComponent(nombreMonitor)}`, {
        method: 'POST'
      });
      
      const data = await res.json();
      return { success: data.success, error: data.error };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }, []);

  // Memoizar valores derivados
  const sedes = useMemo(() => 
    [...new Set(plantas.map(p => p.sede))].filter(Boolean).sort(),
    [plantas]
  );

  const recargar = useCallback(() => {
    setTimestamp(Date.now());
  }, []);

  return {
    plantas,
    estados,
    consumos,
    loading,
    timestamp,
    sedes,
    getResumenPorSede,
    getPlantasPorSede,
    actualizarPlanta,
    resetearPlanta,
    recargar
  };
}
