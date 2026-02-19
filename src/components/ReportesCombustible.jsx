import React, { useState, useEffect } from 'react';
import { usePlantaData } from '../hooks/usePlantaData.js';

export default function ReportesCombustible() {
  const [periodo, setPeriodo] = useState('mensual');
  const [plantaSeleccionada, setPlantaSeleccionada] = useState('todas');
  const [datosPeriodo, setDatosPeriodo] = useState(null);
  const [resumenGlobal, setResumenGlobal] = useState(null);
  const [loading, setLoading] = useState(false);
  
  const { plantas } = usePlantaData();

  useEffect(() => {
    if (plantaSeleccionada === 'todas') {
      cargarResumenGlobal();
    } else {
      cargarDatosPlanta();
    }
  }, [periodo, plantaSeleccionada]);

  const cargarResumenGlobal = async () => {
    setLoading(true);
    try {
      const res = await fetch(`http://10.10.31.31:8080/api/combustible/resumen-global?periodo=${periodo}`);
      const data = await res.json();
      if (data.success) {
        setResumenGlobal(data);
      }
    } catch (error) {
      console.error('Error cargando resumen:', error);
    } finally {
      setLoading(false);
    }
  };

  const cargarDatosPlanta = async () => {
    setLoading(true);
    try {
      const res = await fetch(`http://10.10.31.31:8080/api/combustible/consumo-periodo/${encodeURIComponent(plantaSeleccionada)}?periodo=${periodo}`);
      const data = await res.json();
      if (data.success) {
        setDatosPeriodo(data);
      }
    } catch (error) {
      console.error('Error cargando datos:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatPeriodo = (periodoStr) => {
    if (periodo === 'diario') return periodoStr;
    if (periodo === 'mensual') {
      const [year, month] = periodoStr.split('-');
      const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return `${meses[parseInt(month)-1]} ${year}`;
    }
    if (periodo === 'anual') return periodoStr;
    return periodoStr;
  };

  return (
    <div style={{ padding: '24px' }}>
      <style>{`
        .reportes-container {
          max-width: 1200px;
          margin: 0 auto;
        }
        .filtros {
          background: white;
          border-radius: 12px;
          padding: 20px;
          margin-bottom: 24px;
          box-shadow: 0 4px 6px rgba(0,0,0,0.05);
          display: flex;
          gap: 16px;
          flex-wrap: wrap;
          align-items: center;
        }
        .dark-mode .filtros {
          background: #1a1e24;
        }
        .select-periodo {
          padding: 8px 16px;
          border-radius: 8px;
          border: 1px solid #e5e7eb;
          background: white;
          font-size: 0.95rem;
          cursor: pointer;
        }
        .dark-mode .select-periodo {
          background: #2d3238;
          color: #e5e7eb;
          border-color: #374151;
        }
        .card-stats {
          background: white;
          border-radius: 12px;
          padding: 20px;
          box-shadow: 0 4px 6px rgba(0,0,0,0.05);
        }
        .dark-mode .card-stats {
          background: #1a1e24;
        }
        .stat-value {
          font-size: 2rem;
          font-weight: 700;
          color: #16a34a;
        }
        .stat-label {
          font-size: 0.85rem;
          color: #6b7280;
          margin-bottom: 4px;
        }
        .tabla-reporte {
          width: 100%;
          border-collapse: collapse;
          margin-top: 20px;
        }
        .tabla-reporte th {
          text-align: left;
          padding: 12px;
          background: #f3f4f6;
          border-bottom: 2px solid #e5e7eb;
        }
        .dark-mode .tabla-reporte th {
          background: #2d3238;
          color: #e5e7eb;
        }
        .tabla-reporte td {
          padding: 12px;
          border-bottom: 1px solid #e5e7eb;
        }
        .badge-periodo {
          background: #dbeafe;
          color: #1e40af;
          padding: 4px 8px;
          border-radius: 999px;
          font-size: 0.75rem;
          font-weight: 600;
        }
      `}</style>

      <div className="reportes-container">
        <h1 style={{ marginBottom: 24 }}>📊 Reportes de Consumo</h1>

        {/* Filtros */}
        <div className="filtros">
          <select 
            className="select-periodo"
            value={periodo}
            onChange={(e) => setPeriodo(e.target.value)}
          >
            <option value="diario">📅 Diario (últimos 30 días)</option>
            <option value="semanal">📆 Semanal (último año)</option>
            <option value="mensual">📈 Mensual (últimos 12 meses)</option>
            <option value="anual">📊 Anual (todo el histórico)</option>
          </select>

          <select 
            className="select-periodo"
            value={plantaSeleccionada}
            onChange={(e) => setPlantaSeleccionada(e.target.value)}
            style={{ minWidth: 250 }}
          >
            <option value="todas">🌍 Todas las plantas</option>
            {plantas.map(p => (
              <option key={p.nombre_monitor} value={p.nombre_monitor}>
                ⚡ {p.nombre_monitor} ({p.sede})
              </option>
            ))}
          </select>

          {loading && <span style={{ color: '#6b7280' }}>Cargando...</span>}
        </div>

        {/* Resumen Global */}
        {plantaSeleccionada === 'todas' && resumenGlobal && (
          <>
            {/* Stats Cards */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 20, marginBottom: 24 }}>
              <div className="card-stats">
                <div className="stat-label">Consumo Total</div>
                <div className="stat-value">{resumenGlobal.resumen.total_consumo.toFixed(2)} L</div>
                <div style={{ fontSize: '0.8rem', color: '#6b7280', marginTop: 4 }}>
                  {resumenGlobal.resumen.total_eventos} eventos
                </div>
              </div>
              <div className="card-stats">
                <div className="stat-label">Sedes con consumo</div>
                <div className="stat-value">{resumenGlobal.resumen.total_sedes}</div>
                <div style={{ fontSize: '0.8rem', color: '#6b7280', marginTop: 4 }}>
                  en el período seleccionado
                </div>
              </div>
              <div className="card-stats">
                <div className="stat-label">Promedio por sede</div>
                <div className="stat-value">
                  {(resumenGlobal.resumen.total_consumo / resumenGlobal.resumen.total_sedes || 0).toFixed(2)} L
                </div>
              </div>
            </div>

            {/* Consumo por sede */}
            <div className="card-stats" style={{ marginBottom: 24 }}>
              <h3 style={{ marginTop: 0, marginBottom: 16 }}>Consumo por Sede</h3>
              <table className="tabla-reporte">
                <thead>
                  <tr>
                    <th>Sede</th>
                    <th>Plantas Activas</th>
                    <th>Eventos</th>
                    <th>Total Consumo</th>
                    <th>% del Total</th>
                  </tr>
                </thead>
                <tbody>
                  {resumenGlobal.consumo_por_sede.map(sede => {
                    const porcentaje = ((sede.total_consumo / resumenGlobal.resumen.total_consumo) * 100).toFixed(1);
                    return (
                      <tr key={sede.sede}>
                        <td><strong>{sede.sede}</strong></td>
                        <td>{sede.plantas_activas}</td>
                        <td>{sede.total_eventos}</td>
                        <td><span style={{ fontWeight: 600, color: '#16a34a' }}>{sede.total_consumo} L</span></td>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            <div style={{ 
                              width: 100, 
                              height: 8, 
                              background: '#e5e7eb', 
                              borderRadius: 4,
                              overflow: 'hidden'
                            }}>
                              <div style={{ 
                                width: `${porcentaje}%`, 
                                height: '100%', 
                                background: '#16a34a' 
                              }} />
                            </div>
                            <span>{porcentaje}%</span>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {/* Top 10 Plantas */}
            <div className="card-stats">
              <h3 style={{ marginTop: 0, marginBottom: 16 }}>🔥 Top 10 Plantas con Mayor Consumo</h3>
              <table className="tabla-reporte">
                <thead>
                  <tr>
                    <th>Planta</th>
                    <th>Sede</th>
                    <th>Eventos</th>
                    <th>Total Consumo</th>
                  </tr>
                </thead>
                <tbody>
                  {resumenGlobal.top_plantas.map(planta => (
                    <tr key={planta.nombre_monitor}>
                      <td><strong>{planta.nombre_monitor}</strong></td>
                      <td>{planta.sede}</td>
                      <td>{planta.eventos}</td>
                      <td><span style={{ fontWeight: 600, color: '#16a34a' }}>{planta.total_consumo} L</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}

        {/* Datos de una planta específica */}
        {plantaSeleccionada !== 'todas' && datosPeriodo && (
          <>
            {/* Stats de la planta */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 20, marginBottom: 24 }}>
              <div className="card-stats">
                <div className="stat-label">Consumo Total</div>
                <div className="stat-value">{datosPeriodo.totales.consumo} L</div>
              </div>
              <div className="card-stats">
                <div className="stat-label">Eventos</div>
                <div className="stat-value">{datosPeriodo.totales.eventos}</div>
              </div>
              <div className="card-stats">
                <div className="stat-label">Promedio por evento</div>
                <div className="stat-value">
                  {(datosPeriodo.totales.consumo / datosPeriodo.totales.eventos || 0).toFixed(2)} L
                </div>
              </div>
            </div>

            {/* Tabla de consumo por período */}
            <div className="card-stats">
              <h3 style={{ marginTop: 0, marginBottom: 16 }}>
                Consumo {periodo === 'diario' ? 'Diario' : 
                        periodo === 'semanal' ? 'Semanal' : 
                        periodo === 'mensual' ? 'Mensual' : 'Anual'}
              </h3>
              <table className="tabla-reporte">
                <thead>
                  <tr>
                    <th>Período</th>
                    <th>Eventos</th>
                    <th>Duración Promedio</th>
                    <th>Consumo Total</th>
                    <th>Máximo</th>
                    <th>Mínimo</th>
                  </tr>
                </thead>
                <tbody>
                  {datosPeriodo.datos.map(row => (
                    <tr key={row.periodo}>
                      <td>
                        <span className="badge-periodo">
                          {formatPeriodo(row.periodo)}
                        </span>
                      </td>
                      <td>{row.eventos}</td>
                      <td>{row.duracion_promedio_minutos} min</td>
                      <td><span style={{ fontWeight: 600, color: '#16a34a' }}>{row.total_consumo} L</span></td>
                      <td>{row.max_consumo?.toFixed(2) || 0} L</td>
                      <td>{row.min_consumo?.toFixed(2) || 0} L</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
