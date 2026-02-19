import { useState, useEffect, useCallback } from 'react';

export function usePlantaData() {
  const [plantas, setPlantas] = useState([]);
  const [estados, setEstados] = useState({});
  const [consumos, setConsumos] = useState({});
  const [loading, setLoading] = useState(true);
  const [timestamp, setTimestamp] = useState(Date.now());

  // Cargar plantas configuradas
  const cargarPlantas = useCallback(async () => {
    try {
      const res = await fetch('http://10.10.31.31:8080/api/combustible/plantas');
      const data = await res.json();
      if (data.success) {
        setPlantas(data.data);
      }
    } catch (error) {
      console.error('Error cargando plantas:', error);
    }
  }, []);

  // Cargar estados desde el summary
  const cargarEstados = useCallback(async () => {
    try {
      const res = await fetch('http://10.10.31.31:8080/api/summary');
      const data = await res.json();
      
      const monitoresEnergia = data.monitors.filter(m => 
        m.instance === 'Energia' && 
        m.info.monitor_name.startsWith('PLANTA')
      );
      
      const nuevosEstados = {};
      
      monitoresEnergia.forEach(m => {
        const nombre = m.info.monitor_name;
        nuevosEstados[nombre] = {
          status: m.latest?.status === 1 ? 'UP' : 'DOWN',
          responseTime: m.latest?.responseTime || 0,
          lastCheck: m.latest?.timestamp || Date.now()
        };
      });
      
      setEstados(nuevosEstados);
    } catch (error) {
      console.error('Error cargando estados:', error);
    }
  }, []);

  // Cargar consumos desde la API
  const cargarConsumos = useCallback(async (plantasList = plantas) => {
    if (!plantasList.length) return;
    
    try {
      const nuevosConsumos = {};
      
      await Promise.all(plantasList.map(async (planta) => {
        const nombre = planta.nombre_monitor;
        try {
          const res = await fetch(`http://10.10.31.31:8080/api/combustible/consumo/${encodeURIComponent(nombre)}`);
          if (res.ok) {
            const data = await res.json();
            if (data.success) {
              nuevosConsumos[nombre] = {
                sesionActual: data.data.consumo_actual_sesion || 0,
                historico: data.data.consumo_total_historico || 0,
                esta_encendida: data.data.esta_encendida_ahora,
                ultimoCambio: data.data.ultimo_cambio,
                consumo_lh: data.data.consumo_lh
              };
            }
          }
        } catch (e) {
          console.error(`Error cargando consumo de ${nombre}:`, e);
        }
      }));
      
      setConsumos(nuevosConsumos);
      setTimestamp(Date.now());
    } catch (error) {
      console.error('Error cargando consumos:', error);
    }
  }, [plantas]);

  // Cargar todo al inicio
  useEffect(() => {
    const init = async () => {
      setLoading(true);
      await cargarPlantas();
      setLoading(false);
    };
    init();
  }, [cargarPlantas]);

  // Cuando cambian las plantas, cargar estados y consumos
  useEffect(() => {
    if (plantas.length > 0) {
      const cargarTodo = async () => {
        await Promise.all([
          cargarEstados(),
          cargarConsumos(plantas)
        ]);
      };
      
      cargarTodo();
      const interval = setInterval(cargarTodo, 2000);
      return () => clearInterval(interval);
    }
  }, [plantas, cargarEstados, cargarConsumos]);

  // Función para simular evento
  const simularEvento = useCallback(async (nombreMonitor, estado) => {
    try {
      const res = await fetch('http://10.10.31.31:8080/api/combustible/evento', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          nombre_monitor: nombreMonitor, 
          estado 
        })
      });
      
      const data = await res.json();
      if (data.success) {
        // Recargar datos inmediatamente
        await Promise.all([
          cargarEstados(),
          cargarConsumos(plantas)
        ]);
        return { success: true, message: `Planta ${estado === 'UP' ? 'encendida' : 'apagada'}` };
      }
      return { success: false, error: data.error };
    } catch (error) {
      console.error('Error en simulación:', error);
      return { success: false, error: error.message };
    }
  }, [plantas, cargarEstados, cargarConsumos]);

  // Función para resetear planta
  const resetearPlanta = useCallback(async (nombreMonitor) => {
    try {
      const res = await fetch(`http://10.10.31.31:8080/api/combustible/reset/${encodeURIComponent(nombreMonitor)}`, {
        method: 'POST'
      });
      
      const data = await res.json();
      if (data.success) {
        await cargarConsumos(plantas);
        return { success: true };
      }
      return { success: false, error: data.error };
    } catch (error) {
      console.error('Error reseteando:', error);
      return { success: false, error: error.message };
    }
  }, [plantas, cargarConsumos]);

  // Obtener estado de una planta
  const getEstado = useCallback((nombre) => {
    return estados[nombre] || { status: 'DOWN', responseTime: 0 };
  }, [estados]);

  // Obtener consumo de una planta
  const getConsumo = useCallback((nombre) => {
    return consumos[nombre] || { sesionActual: 0, historico: 0, esta_encendida: false };
  }, [consumos]);

  return {
    plantas,
    estados,
    consumos,
    loading,
    timestamp,
    simularEvento,
    resetearPlanta,
    getEstado,
    getConsumo,
    recargar: () => {
      cargarEstados();
      cargarConsumos(plantas);
    }
  };
}
