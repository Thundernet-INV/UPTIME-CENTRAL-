// src/components/ReportesCombustible.jsx
import React, { useState, useEffect, useMemo } from 'react';
import { usePlantaData } from '../hooks/usePlantaData.js';

export default function ReportesCombustible() {
  const [periodo, setPeriodo] = useState('mensual');
  const [sedeSeleccionada, setSedeSeleccionada] = useState('todas');
  const [plantaSeleccionada, setPlantaSeleccionada] = useState('todas');
  const [datosPeriodo, setDatosPeriodo] = useState(null);
  const [resumenGlobal, setResumenGlobal] = useState(null);
  const [loading, setLoading] = useState(false);
  const [plantasFiltradas, setPlantasFiltradas] = useState([]);
  
  const { plantas, getResumenPorSede } = usePlantaData();

  // Obtener sedes que realmente tienen plantas (basado en plantas reales)
  const sedesConPlantas = useMemo(() => {
    // Extraer sedes únicas de las plantas que existen
    const sedesUnicas = [...new Set(plantas.map(p => p.sede))];
    return sedesUnicas.filter(sede => sede && sede !== 'Sin sede').sort();
  }, [plantas]);

  // También obtener el resumen por sede para mostrar estadísticas
  const resumenSedes = useMemo(() => {
    const resumen = getResumenPorSede();
    // Filtrar solo las sedes que existen en plantas
    const filtrado = {};
    sedesConPlantas.forEach(sede => {
      if (resumen[sede]) {
        filtrado[sede] = resumen[sede];
      }
    });
    return filtrado;
  }, [getResumenPorSede, sedesConPlantas]);

  // Actualizar lista de plantas cuando cambia la sede
  useEffect(() => {
    if (sedeSeleccionada === 'todas') {
      setPlantasFiltradas(plantas);
    } else {
      setPlantasFiltradas(plantas.filter(p => p.sede === sedeSeleccionada));
    }
    setPlantaSeleccionada('todas');
  }, [sedeSeleccionada, plantas]);

  // Cargar datos según selección
  useEffect(() => {
    if (plantaSeleccionada === 'todas') {
      cargarResumenGlobal();
    } else {
      cargarDatosPlanta();
    }
  }, [periodo, sedeSeleccionada, plantaSeleccionada]);

  const cargarResumenGlobal = async () => {
    setLoading(true);
    try {
      const url = `http://10.10.31.31:8080/api/combustible/resumen-global?periodo=${periodo}${sedeSeleccionada !== 'todas' ? `&sede=${encodeURIComponent(sedeSeleccionada)}` : ''}`;
      const res = await fetch(url);
      const data = await res.json();
      if (data.success) {
        setResumenGlobal(data);
        setDatosPeriodo(null);
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
        setResumenGlobal(null);
      }
    } catch (error) {
      console.error('Error cargando datos:', error);
    } finally {
      setLoading(false);
    }
  };

  // Función para escapar campos CSV
  const escapeCSV = (campo) => {
    if (campo === null || campo === undefined) return '';
    const str = String(campo);
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  };

  // Función para exportar a CSV
  const exportarACSV = () => {
    if (!datosPeriodo && !resumenGlobal) return;
    
    let csvContent = "";
    let filename = "";
    
    if (plantaSeleccionada !== 'todas' && datosPeriodo) {
      filename = `${plantaSeleccionada.replace(/\s+/g, '_')}_${periodo}.csv`;
      csvContent = "Período,Eventos,Duración Promedio (min),Consumo Total (L),Máximo (L),Mínimo (L)\n";
      
      datosPeriodo.datos.forEach(row => {
        csvContent += `${escapeCSV(row.periodo)},${row.eventos},${row.duracion_promedio_minutos},${row.total_consumo},${row.max_consumo || 0},${row.min_consumo || 0}\n`;
      });
      
      csvContent += `\nTOTALES,,,${datosPeriodo.totales.consumo},,\n`;
      
    } else if (resumenGlobal) {
      filename = `resumen_${sedeSeleccionada !== 'todas' ? sedeSeleccionada + '_' : ''}${periodo}.csv`;
      
      csvContent = "=== CONSUMO POR SEDE ===\n";
      csvContent += "Sede,Plantas Activas,Eventos,Consumo Total (L)\n";
      
      resumenGlobal.consumo_por_sede.forEach(sede => {
        csvContent += `${escapeCSV(sede.sede)},${sede.plantas_activas},${sede.total_eventos},${sede.total_consumo}\n`;
      });
      
      csvContent += "\n\n=== TOP 10 PLANTAS ===\n";
      csvContent += "Planta,Sede,Eventos,Consumo Total (L)\n";
      
      resumenGlobal.top_plantas.forEach(planta => {
        csvContent += `${escapeCSV(planta.nombre_monitor)},${escapeCSV(planta.sede)},${planta.eventos},${planta.total_consumo}\n`;
      });
      
      csvContent += `\n\nRESUMEN GLOBAL,Total Sedes: ${resumenGlobal.resumen.total_sedes},Total Consumo: ${resumenGlobal.resumen.total_consumo} L,Total Eventos: ${resumenGlobal.resumen.total_eventos}\n`;
    }
    
    const blob = new Blob(["\uFEFF" + csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.href = url;
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
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

  const volverAAdmin = () => {
    window.location.hash = '#/admin-plantas';
  };

  return (
    <div style={{ padding: '24px' }}>
      <style>{`
        .reportes-container {
          max-width: 1200px;
          margin: 0 auto;
        }
        .header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 24px;
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
          min-width: 180px;
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
          background: white;
          border-radius: 12px;
          overflow: hidden;
          box-shadow: 0 4px 6px rgba(0,0,0,0.05);
          margin-top: 20px;
        }
        .dark-mode .tabla-reporte {
          background: #1a1e24;
        }
        .tabla-reporte th {
          text-align: left;
          padding: 16px;
          background: #f3f4f6;
          border-bottom: 2px solid #e5e7eb;
          font-weight: 600;
        }
        .dark-mode .tabla-reporte th {
          background: #2d3238;
          color: #e5e7eb;
          border-bottom-color: #374151;
        }
        .tabla-reporte td {
          padding: 16px;
          border-bottom: 1px solid #e5e7eb;
        }
        .dark-mode .tabla-reporte td {
          border-bottom-color: #374151;
          color: #e5e7eb;
        }
        .tabla-reporte tr:hover {
          background: #f9fafb;
        }
        .dark-mode .tabla-reporte tr:hover {
          background: #2d3238;
        }
        .badge-periodo {
          background: #dbeafe;
          color: #1e40af;
          padding: 4px 12px;
          border-radius: 999px;
          font-size: 0.8rem;
          font-weight: 600;
          display: inline-block;
        }
        .dark-mode .badge-periodo {
          background: #1e3a5f;
          color: #93c5fd;
        }
        .btn-exportar {
          padding: 8px 16px;
          background: #16a34a;
          color: white;
          border: none;
          border-radius: 6px;
          cursor: pointer;
          font-size: 0.9rem;
          display: flex;
          align-items: center;
          gap: 6px;
          transition: all 0.2s ease;
        }
        .btn-exportar:hover {
          background: #15803d;
          transform: scale(1.05);
        }
        .btn-exportar:disabled {
          background: #9ca3af;
          cursor: not-allowed;
          transform: none;
        }
        .btn-volver {
          padding: 8px 16px;
          background: #3b82f6;
          color: white;
          border: none;
          border-radius: 6px;
          cursor: pointer;
          font-size: 0.9rem;
          display: flex;
          align-items: center;
          gap: 6px;
          transition: all 0.2s ease;
        }
        .btn-volver:hover {
          background: #2563eb;
        }
        .consumo-positivo {
          color: #16a34a;
          font-weight: 600;
        }
        .dark-mode .consumo-positivo {
          color: #4ade80;
        }
        .barra-porcentaje {
          width: 100px;
          height: 8px;
          background: #e5e7eb;
          border-radius: 4px;
          overflow: hidden;
          display: inline-block;
          margin-right: 8px;
        }
        .dark-mode .barra-porcentaje {
          background: #374151;
        }
        .barra-porcentaje-fill {
          height: 100%;
          background: #16a34a;
          border-radius: 4px;
        }
        .dark-mode .barra-porcentaje-fill {
          background: #4ade80;
        }
        .estadistica {
          background: #f3f4f6;
          padding: 8px 16px;
          border-radius: 999px;
          font-size: 0.9rem;
        }
        .dark-mode .estadistica {
          background: #2d3238;
          color: #e5e7eb;
        }
        .empty-state {
          text-align: center;
          padding: 60px;
          background: white;
          border-radius: 12px;
          box-shadow: 0 4px 6px rgba(0,0,0,0.05);
        }
        .dark-mode .empty-state {
          background: #1a1e24;
        }
      `}</style>

      <div className="reportes-container">
        <div className="header">
          <h1>📊 Reportes de Consumo de Combustible</h1>
          <button onClick={volverAAdmin} className="btn-volver">
            ← Volver a Admin
          </button>
        </div>

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

          {/* FILTRO POR SEDE - AHORA USA sedesConPlantas */}
          <select 
            className="select-periodo"
            value={sedeSeleccionada}
            onChange={(e) => setSedeSeleccionada(e.target.value)}
            style={{ minWidth: 200 }}
          >
            <option value="todas">🌍 Todas las sedes</option>
            {sedesConPlantas.map(sede => (
              <option key={sede} value={sede}>
                🏢 {sede} {resumenSedes[sede] ? `(${resumenSedes[sede].totalPlantas})` : ''}
              </option>
            ))}
          </select>

          {/* FILTRO POR PLANTA */}
          <select 
            className="select-periodo"
            value={plantaSeleccionada}
            onChange={(e) => setPlantaSeleccionada(e.target.value)}
            style={{ minWidth: 250 }}
          >
            <option value="todas">
              {sedeSeleccionada === 'todas' 
                ? '⚡ Todas las plantas' 
                : `⚡ Todas las plantas de ${sedeSeleccionada}`}
            </option>
            {plantasFiltradas.map(p => (
              <option key={p.nombre_monitor} value={p.nombre_monitor}>
                ⚡ {p.nombre_monitor}
              </option>
            ))}
          </select>

          <button
            onClick={exportarACSV}
            disabled={!datosPeriodo && !resumenGlobal}
            className="btn-exportar"
            title="Exportar a Excel/CSV"
          >
            📥 Exportar CSV
          </button>

          {loading && <span className="estadistica">Cargando...</span>}
        </div>

        {/* Resumen por sede (solo cuando se ven todas las sedes) */}
        {sedeSeleccionada === 'todas' && Object.keys(resumenSedes).length > 0 && (
          <div style={{ 
            display: 'grid', 
            gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
            gap: 12,
            marginBottom: 24
          }}>
            {Object.entries(resumenSedes).map(([sede, data]) => (
              <div 
                key={sede} 
                style={{
                  background: '#f3f4f6',
                  padding: 16,
                  borderRadius: 12,
                  border: '1px solid #e5e7eb',
                  cursor: 'pointer',
                  transition: 'all 0.2s'
                }}
                onClick={() => setSedeSeleccionada(sede)}
                onMouseEnter={(e) => e.currentTarget.style.background = '#e5e7eb'}
                onMouseLeave={(e) => e.currentTarget.style.background = '#f3f4f6'}
              >
                <div style={{ fontWeight: 700, marginBottom: 8 }}>{sede}</div>
                <div style={{ fontSize: '0.9rem', color: '#4b5563' }}>
                  {data.totalPlantas} plantas · {data.totalConsumo.toFixed(2)}L
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Contenido según selección */}
        {plantaSeleccionada === 'todas' ? (
          // VISTA GLOBAL O POR SEDE
          resumenGlobal ? (
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
                  <div className="stat-label">
                    {sedeSeleccionada === 'todas' ? 'Sedes con consumo' : 'Plantas activas'}
                  </div>
                  <div className="stat-value">
                    {sedeSeleccionada === 'todas' 
                      ? resumenGlobal.resumen.total_sedes 
                      : plantasFiltradas.length}
                  </div>
                  <div style={{ fontSize: '0.8rem', color: '#6b7280', marginTop: 4 }}>
                    en el período seleccionado
                  </div>
                </div>
                <div className="card-stats">
                  <div className="stat-label">Promedio por {sedeSeleccionada === 'todas' ? 'sede' : 'planta'}</div>
                  <div className="stat-value">
                    {(sedeSeleccionada === 'todas'
                      ? (resumenGlobal.resumen.total_consumo / resumenGlobal.resumen.total_sedes || 0)
                      : (resumenGlobal.resumen.total_consumo / plantasFiltradas.length || 0)
                    ).toFixed(2)} L
                  </div>
                </div>
              </div>

              {/* Consumo por sede (solo cuando se ven todas las sedes) */}
              {sedeSeleccionada === 'todas' && (
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
                      {resumenGlobal.consumo_por_sede
                        .filter(sede => sedesConPlantas.includes(sede.sede)) // Filtrar solo sedes que existen
                        .map(sede => {
                          const porcentaje = ((sede.total_consumo / resumenGlobal.resumen.total_consumo) * 100).toFixed(1);
                          return (
                            <tr key={sede.sede}>
                              <td><strong>{sede.sede}</strong></td>
                              <td>{sede.plantas_activas}</td>
                              <td>{sede.total_eventos}</td>
                              <td><span className="consumo-positivo">{sede.total_consumo} L</span></td>
                              <td>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                  <div className="barra-porcentaje">
                                    <div className="barra-porcentaje-fill" style={{ width: `${porcentaje}%` }} />
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
              )}

              {/* Top 10 Plantas */}
              <div className="card-stats">
                <h3 style={{ marginTop: 0, marginBottom: 16 }}>
                  🔥 Top 10 Plantas con Mayor Consumo
                  {sedeSeleccionada !== 'todas' && ` en ${sedeSeleccionada}`}
                </h3>
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
                    {resumenGlobal.top_plantas
                      .filter(planta => sedeSeleccionada === 'todas' || planta.sede === sedeSeleccionada)
                      .map(planta => (
                        <tr key={planta.nombre_monitor}>
                          <td><strong>{planta.nombre_monitor}</strong></td>
                          <td>{planta.sede}</td>
                          <td>{planta.eventos}</td>
                          <td><span className="consumo-positivo">{planta.total_consumo} L</span></td>
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>
            </>
          ) : (
            <div className="empty-state">
              <div style={{ fontSize: '4rem', marginBottom: '20px' }}>📊</div>
              <h3>No hay datos disponibles</h3>
              <p style={{ color: '#6b7280' }}>
                No se encontraron registros de consumo para el período seleccionado.
              </p>
            </div>
          )
        ) : (
          // VISTA DE UNA PLANTA ESPECÍFICA
          datosPeriodo ? (
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
                        <td><span className="consumo-positivo">{row.total_consumo} L</span></td>
                        <td>{row.max_consumo || 0} L</td>
                        <td>{row.min_consumo || 0} L</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          ) : (
            <div className="empty-state">
              <div style={{ fontSize: '4rem', marginBottom: '20px' }}>📊</div>
              <h3>No hay datos disponibles</h3>
              <p style={{ color: '#6b7280' }}>
                No se encontraron registros de consumo para esta planta en el período seleccionado.
              </p>
            </div>
          )
        )}
      </div>
    </div>
  );
}
