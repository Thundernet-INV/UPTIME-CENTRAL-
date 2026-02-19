import React, { useState, useEffect } from 'react';
import { usePlantaData } from '../hooks/usePlantaData.js';

const MODELOS_CON_CONSUMO = {
  '46-GI-30MDI': 6.5,
  '46-GI-33MDFW': 7.75,
  '46-GI-70DE': 15.6,
  '46-GI-70BM': 15.8,
  '46-GI-30FW': 7.0,
  '46-GI-25MDFW-X': 7.0,
  '46-GI-15MDQ': 4.4,
  '46-GI-25MDFW': 7.0,
  '46-GI-50FW': 11.0,
  '46-GI-75C-X': 13.1,
  '46-GI-75C': 13.1,
  'CU28LDE': 13.1,
  'JHON DEERE 65KVA': 15.0,
  'JYX24SA2': 5.0,
  'GI-30I-S': 7.75,
  'GI-55I-M': 11.0,
  '46-GI-40ZI': 9.0,
  '46-GI-240-Z': 50.0
};

export default function PlantaDetail({ planta, onClose, onActualizar }) {
  const [editando, setEditando] = useState(false);
  const [datosEditados, setDatosEditados] = useState({ ...planta });
  
  // Usar el hook para obtener datos en tiempo real
  const { estados, consumos, resetearPlanta, timestamp } = usePlantaData();
  
  const estadoActual = estados[planta.nombre_monitor];
  const consumo = consumos[planta.nombre_monitor] || { sesionActual: 0, historico: 0 };

  const resetearContador = async () => {
    if (window.confirm('¿Resetear el contador de consumo de esta planta?')) {
      const result = await resetearPlanta(planta.nombre_monitor);
      if (result.success) {
        alert('✅ Contador reseteado');
      } else {
        alert('❌ Error: ' + result.error);
      }
    }
  };

  const handleGuardar = async () => {
    try {
      // Aquí iría la llamada a la API para actualizar
      setEditando(false);
      if (onActualizar) onActualizar();
    } catch (error) {
      console.error('Error guardando:', error);
    }
  };

  const getStatusColor = () => {
    if (!estadoActual) return { bg: '#e5e7eb', color: '#6b7280', text: 'DESCONOCIDO' };
    if (estadoActual.status === 'UP') {
      return { bg: '#d1fae5', color: '#065f46', text: '🟢 ENCENDIDA' };
    }
    return { bg: '#fee2e2', color: '#991b1b', text: '🔴 APAGADA' };
  };

  const status = getStatusColor();

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'rgba(0,0,0,0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }}>
      <div style={{
        background: 'white',
        borderRadius: 12,
        width: '90%',
        maxWidth: 800,
        maxHeight: '90vh',
        overflow: 'auto',
        padding: 24,
        boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)'
      }}>
        {/* Header */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 24
        }}>
          <h2 style={{ margin: 0 }}>
            ⚡ {planta.nombre_monitor}
          </h2>
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              fontSize: 24,
              cursor: 'pointer',
              color: '#6b7280'
            }}
          >
            ×
          </button>
        </div>

        {/* Estado actual y consumo */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(4, 1fr)',
          gap: 16,
          marginBottom: 24
        }} key={timestamp}>
          <div style={{
            background: status.bg,
            padding: 16,
            borderRadius: 8,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.8rem', color: status.color, marginBottom: 4 }}>ESTADO</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700, color: status.color }}>
              {status.text}
            </div>
          </div>
          
          <div style={{
            background: '#f3f4f6',
            padding: 16,
            borderRadius: 8,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.8rem', color: '#6b7280', marginBottom: 4 }}>LATENCIA</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>
              {estadoActual?.responseTime?.toFixed(2) || '-1'} ms
            </div>
          </div>

          <div style={{
            background: '#d1fae5',
            padding: 16,
            borderRadius: 8,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.8rem', color: '#065f46', marginBottom: 4 }}>CONSUMO ACTUAL</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700, color: '#065f46' }}>
              {consumo.sesionActual.toFixed(3)} L
            </div>
          </div>

          <div style={{
            background: '#e5e7eb',
            padding: 16,
            borderRadius: 8,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.8rem', color: '#1f2937', marginBottom: 4 }}>HISTÓRICO</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700, color: '#1f2937' }}>
              {consumo.historico.toFixed(2)} L
            </div>
          </div>
        </div>

        {/* Información de la planta */}
        {!editando ? (
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 16,
            marginBottom: 24,
            padding: 16,
            background: '#f9fafb',
            borderRadius: 8
          }}>
            <div>
              <div style={{ fontSize: '0.8rem', color: '#6b7280' }}>Sede</div>
              <div style={{ fontWeight: 600 }}>{planta.sede}</div>
            </div>
            <div>
              <div style={{ fontSize: '0.8rem', color: '#6b7280' }}>Modelo</div>
              <div style={{ fontWeight: 600 }}>{planta.modelo}</div>
            </div>
            <div>
              <div style={{ fontSize: '0.8rem', color: '#6b7280' }}>Consumo por hora</div>
              <div style={{ fontWeight: 600 }}>{planta.consumo_lh} L/h</div>
            </div>
          </div>
        ) : (
          <div style={{ marginBottom: 24 }}>
            <h3>Editar Planta</h3>
            <div style={{ display: 'grid', gap: 16 }}>
              <div>
                <label style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>Sede:</label>
                <input
                  type="text"
                  value={datosEditados.sede}
                  onChange={(e) => setDatosEditados({...datosEditados, sede: e.target.value})}
                  style={{ width: '100%', padding: 8, borderRadius: 4, border: '1px solid #e5e7eb' }}
                />
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>Modelo:</label>
                <select
                  value={datosEditados.modelo}
                  onChange={(e) => {
                    const modelo = e.target.value;
                    setDatosEditados({
                      ...datosEditados,
                      modelo: modelo,
                      consumo_lh: MODELOS_CON_CONSUMO[modelo] || datosEditados.consumo_lh
                    });
                  }}
                  style={{ width: '100%', padding: 8, borderRadius: 4, border: '1px solid #e5e7eb' }}
                >
                  <option value="">Seleccionar modelo</option>
                  {Object.keys(MODELOS_CON_CONSUMO).map(m => (
                    <option key={m} value={m}>{m}</option>
                  ))}
                </select>
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: 4, fontWeight: 500 }}>Consumo (L/h):</label>
                <input
                  type="number"
                  step="0.1"
                  value={datosEditados.consumo_lh}
                  onChange={(e) => setDatosEditados({...datosEditados, consumo_lh: e.target.value})}
                  style={{ width: '100%', padding: 8, borderRadius: 4, border: '1px solid #e5e7eb' }}
                />
              </div>
            </div>
          </div>
        )}

        {/* Botones de acción */}
        <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
          {!editando ? (
            <>
              <button
                onClick={() => setEditando(true)}
                style={{
                  padding: '10px 24px',
                  background: '#3b82f6',
                  color: 'white',
                  border: 'none',
                  borderRadius: 6,
                  cursor: 'pointer'
                }}
              >
                Editar Planta
              </button>
              <button
                onClick={resetearContador}
                style={{
                  padding: '10px 24px',
                  background: '#ef4444',
                  color: 'white',
                  border: 'none',
                  borderRadius: 6,
                  cursor: 'pointer'
                }}
              >
                Resetear Contador
              </button>
            </>
          ) : (
            <>
              <button
                onClick={handleGuardar}
                style={{
                  padding: '10px 24px',
                  background: '#16a34a',
                  color: 'white',
                  border: 'none',
                  borderRadius: 6,
                  cursor: 'pointer'
                }}
              >
                Guardar Cambios
              </button>
              <button
                onClick={() => setEditando(false)}
                style={{
                  padding: '10px 24px',
                  background: '#e5e7eb',
                  border: 'none',
                  borderRadius: 6,
                  cursor: 'pointer'
                }}
              >
                Cancelar
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
