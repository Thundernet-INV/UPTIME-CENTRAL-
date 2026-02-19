#!/bin/bash
# crear-energia-detail-final.sh
# CREA EL COMPONENTE ENERGIA DETAIL CON CONSUMO

echo "====================================================="
echo "📝 CREANDO COMPONENTE ENERGIA DETAIL CON CONSUMO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DETAIL_FILE="$FRONTEND_DIR/src/components/EnergiaDetail.jsx"

# ========== 1. CREAR EL ARCHIVO ==========
echo ""
echo "[1] Creando EnergiaDetail.jsx..."

cat > "$DETAIL_FILE" << 'EOF'
import React, { useState, useEffect } from 'react';

export default function EnergiaDetail({ monitor, onClose }) {
  const [consumo, setConsumo] = useState({ sesionActual: 0, historico: 0 });

  useEffect(() => {
    // Cargar consumo inicial
    const saved = localStorage.getItem('consumo_plantas');
    if (saved) {
      const data = JSON.parse(saved);
      setConsumo(data[monitor.info?.monitor_name] || { sesionActual: 0, historico: 0 });
    }

    // Actualizar cada 2 segundos
    const interval = setInterval(() => {
      const updated = localStorage.getItem('consumo_plantas');
      if (updated) {
        const data = JSON.parse(updated);
        setConsumo(data[monitor.info?.monitor_name] || { sesionActual: 0, historico: 0 });
      }
    }, 2000);

    return () => clearInterval(interval);
  }, [monitor]);

  const isUp = monitor.latest?.status === 1;

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
        borderRadius: 16,
        padding: 32,
        maxWidth: 600,
        width: '100%',
        position: 'relative',
        boxShadow: '0 20px 40px rgba(0,0,0,0.2)'
      }}>
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: 20,
            right: 20,
            background: 'transparent',
            border: 'none',
            fontSize: 28,
            cursor: 'pointer',
            color: '#6b7280'
          }}
        >
          ×
        </button>

        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 24 }}>
          <span style={{ fontSize: '3rem' }}>🏭</span>
          <div>
            <h2 style={{ margin: 0, fontSize: '1.8rem', color: '#1f2937' }}>
              {monitor.info?.monitor_name}
            </h2>
            <p style={{ margin: '4px 0 0', fontSize: '1rem', color: '#6b7280' }}>
              Plantas eléctricas · Energia
            </p>
          </div>
        </div>

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: 16,
          marginBottom: 24
        }}>
          <div style={{
            background: isUp ? '#d1fae5' : '#fee2e2',
            padding: 20,
            borderRadius: 12,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: 8 }}>ESTADO</div>
            <div style={{ fontSize: '2rem', fontWeight: 700, color: isUp ? '#16a34a' : '#dc2626' }}>
              {isUp ? 'UP' : 'DOWN'}
            </div>
          </div>

          <div style={{
            background: '#f3f4f6',
            padding: 20,
            borderRadius: 12,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: 8 }}>LATENCIA</div>
            <div style={{ fontSize: '2rem', fontWeight: 700, color: '#1f2937' }}>
              {monitor.latest?.responseTime?.toFixed(2) || '-1'} ms
            </div>
          </div>

          <div style={{
            background: '#e5e7eb',
            padding: 20,
            borderRadius: 12,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: 8 }}>TIPO</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600, color: '#3b82f6' }}>PLANTA</div>
          </div>

          <div style={{
            background: '#e5e7eb',
            padding: 20,
            borderRadius: 12,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: 8 }}>ÚLTIMO CHECK</div>
            <div style={{ fontSize: '1.2rem', fontWeight: 600, color: '#1f2937' }}>
              {monitor.latest?.timestamp ? new Date(monitor.latest.timestamp).toLocaleTimeString() : '—'}
            </div>
          </div>
        </div>

        {/* SECCIÓN DE CONSUMO DE COMBUSTIBLE */}
        <div style={{
          background: '#d1fae5',
          padding: 20,
          borderRadius: 12,
          marginBottom: 16
        }}>
          <h4 style={{ margin: '0 0 12px 0', fontSize: '1rem', color: '#065f46' }}>
            ⛽ CONSUMO DE COMBUSTIBLE
          </h4>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <div style={{ background: 'white', padding: 16, borderRadius: 8, textAlign: 'center' }}>
              <div style={{ fontSize: '0.8rem', color: '#6b7280', marginBottom: 4 }}>
                Consumo Actual (Sesión)
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 700, color: '#065f46' }}>
                {consumo.sesionActual.toFixed(2)} L
              </div>
              {isUp && (
                <div style={{ fontSize: '0.7rem', color: '#065f46', marginTop: 4 }}>
                  Acumulado desde que encendió
                </div>
              )}
            </div>
            <div style={{ background: 'white', padding: 16, borderRadius: 8, textAlign: 'center' }}>
              <div style={{ fontSize: '0.8rem', color: '#6b7280', marginBottom: 4 }}>
                Consumo Histórico Total
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 700, color: '#1f2937' }}>
                {consumo.historico.toFixed(1)} L
              </div>
              <div style={{ fontSize: '0.7rem', color: '#6b7280', marginTop: 4 }}>
                Total acumulado de todas las sesiones
              </div>
            </div>
          </div>
        </div>

        <div style={{
          padding: 20,
          background: '#f3f4f6',
          borderRadius: 12
        }}>
          <h4 style={{ margin: '0 0 12px', fontSize: '1rem', color: '#4b5563' }}>
            INFORMACIÓN ADICIONAL
          </h4>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div><strong>URL:</strong> {monitor.info?.monitor_url || '—'}</div>
            <div><strong>Tipo de monitor:</strong> {monitor.info?.monitor_type || '—'}</div>
            <div><strong>Tags:</strong> {monitor.info?.tags?.join(', ') || 'Ninguno'}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

echo "✅ EnergiaDetail.jsx creado"

# ========== 2. LIMPIAR EL ARCHIVO ENERGIA.JSX ==========
echo ""
echo "[2] Limpiando Energia.jsx (quitando modales duplicados)..."

ENERGIA_FILE="$FRONTEND_DIR/src/views/Energia.jsx"
cp "$ENERGIA_FILE" "$ENERGIA_FILE.backup.clean.$(date +%Y%m%d_%H%M%S)"

# Crear una versión limpia
cat > "$ENERGIA_FILE" << 'EOF'
import EnergiaDetail from "../components/EnergiaDetail.jsx";
import React, { useMemo, useState } from "react";
import ServiceCard from "../components/ServiceCard.jsx";

const TIPOS = ["PLANTA", "AVR", "CORPOELEC", "INVERSOR"];
const KEYWORDS_TIPO = [
  { kw: "planta", tipo: "PLANTA" },
  { kw: "avr", tipo: "AVR" },
  { kw: "corpoelec", tipo: "CORPOELEC" },
  { kw: "corpo", tipo: "CORPOELEC" },
  { kw: "inversor", tipo: "INVERSOR" },
];

function deducirTipo(nombre = "", tipoExplicito) {
  if (tipoExplicito && TIPOS.includes(tipoExplicito)) return tipoExplicito;
  const low = String(nombre).toLowerCase();
  for (const { kw, tipo } of KEYWORDS_TIPO) { if (low.includes(kw)) return tipo; }
  return "OTRO";
}

function Chip({ active, children, onClick }) {
  return (
    <button
      type="button"
      className="k-btn"
      onClick={onClick}
      style={{
        padding: "6px 12px",
        borderRadius: "16px",
        border: "1px solid var(--border, #e5e7eb)",
        background: active ? "var(--info, #3b82f6)" : "transparent",
        color: active ? "#fff" : "var(--text-primary, #1f2937)",
        fontSize: "0.85rem",
        cursor: "pointer",
        transition: "all 0.2s ease",
      }}
    >
      {children}
    </button>
  );
}

export default function Energia({ monitorsAll = [] }) {
  const [tipoSel, setTipoSel] = useState("");
  const [tagSel, setTagSel] = useState("");
  const [q, setQ] = useState("");
  const [selectedMonitor, setSelectedMonitor] = useState(null);

  const icmp = useMemo(() => {
    return (Array.isArray(monitorsAll) ? monitorsAll : []).filter(m => {
      const t = m?.info?.monitor_type ?? "";
      return String(t).toLowerCase() === "icmp";
    });
  }, [monitorsAll]);

  const dataset = useMemo(() => {
    return icmp.map(m => {
      const name = m?.info?.monitor_name ?? m?.name ?? "";
      const tipo = deducirTipo(name, m?.info?.tipo_equipo);
      const tagsRaw = Array.isArray(m?.info?.tags) ? m.info.tags : [];
      const tags = (tagsRaw.length ? tagsRaw : [m?.instance]).filter(Boolean).map(t => String(t).trim());
      return { raw: m, name, tipo, tags };
    });
  }, [icmp]);

  const etiquetas = useMemo(() => {
    const set = new Set();
    dataset.forEach(x => x.tags.forEach(t => set.add(t)));
    return Array.from(set).sort((a,b)=>String(a).localeCompare(String(b)));
  }, [dataset]);

  const filtrados = useMemo(() => {
    const text = q.trim().toLowerCase();
    return dataset.filter(item => {
      const okTipo = !tipoSel || item.tipo === tipoSel;
      const okTag = !tagSel || item.tags.includes(tagSel);
      const okText = !text
        || item.name.toLowerCase().includes(text)
        || String(item.raw?.instance ?? "").toLowerCase().includes(text);
      return okTipo && okTag && okText;
    });
  }, [dataset, tipoSel, tagSel, q]);

  const porTipo = useMemo(() => {
    const map = new Map();
    filtrados.forEach(item => {
      const key = TIPOS.includes(item.tipo) ? item.tipo : "OTRO";
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(item);
    });
    const orden = [...TIPOS, "OTRO"];
    return orden.filter(k => map.has(k)).map(k => ({ tipo:k, items:map.get(k) }));
  }, [filtrados]);

  return (
    <div style={{ padding: 24 }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", marginBottom:16 }}>
        <h2 className="k-card__title" style={{ margin:0 }}>Energia · Monitoreo ICMP</h2>
        <input
          type="search"
          placeholder="Buscar por nombre o sede…"
          value={q}
          onChange={e => setQ(e.target.value)}
          style={{
            padding: "8px 12px",
            border: "1px solid var(--border, #e5e7eb)",
            borderRadius: 8,
            background: "var(--input-bg, #fff)",
            color: "var(--text-primary, #1f2937)",
            minWidth: 260
          }}
        />
      </div>

      <div className="k-card" style={{ padding:16, marginBottom:16 }}>
        <div style={{ display:"flex", gap:16, flexWrap:"wrap", alignItems:"center" }}>
          <strong>Tipo:</strong>
          <Chip active={tipoSel === ""} onClick={() => setTipoSel("")}>Todos</Chip>
          {TIPOS.map(t => (<Chip key={t} active={tipoSel === t} onClick={() => setTipoSel(t)}>{t}</Chip>))}
        </div>

        <div style={{ height:12 }} />

        <div style={{ display:"flex", gap:16, flexWrap:"wrap", alignItems:"center" }}>
          <strong>Etiqueta (sede):</strong>
          <Chip active={tagSel === ""} onClick={() => setTagSel("")}>Todas</Chip>
          {etiquetas.map(tag => (
            <Chip key={tag} active={tagSel === tag} onClick={() => setTagSel(tag)}>{tag}</Chip>
          ))}
        </div>
      </div>

      {porTipo.map(sec => (
        <div key={sec.tipo} style={{ marginBottom:24 }}>
          <h3 className="k-card__title" style={{ margin:"0 0 12px 0" }}>{sec.tipo} · {sec.items.length}</h3>
          <div className="instance-grid" style={{ display:"grid", gridTemplateColumns:"repeat(auto-fill,minmax(320px,1fr))", gap:12 }}>
            {sec.items.map(({ raw, name }) => {
              const nombreMonitor = raw.info?.monitor_name || name;
              const saved = typeof window !== "undefined" ? localStorage.getItem("consumo_plantas") : null;
              const data = saved ? JSON.parse(saved) : {};
              const consumo = data[nombreMonitor] || { sesionActual: 0, historico: 0 };
              const isUp = raw.latest?.status === 1;
              
              return (
                <div
                  key={`${raw.instance ?? "?"}-${name}`}
                  className="k-card"
                  style={{ padding: 12, position: "relative", cursor: "pointer" }}
                  onClick={() => setSelectedMonitor(raw)}
                >
                  <ServiceCard service={raw} series={[]} />
                  
                  {/* CONSUMO DE COMBUSTIBLE */}
                  {raw.info?.monitor_name?.startsWith("PLANTA") && (
                    <div style={{
                      marginTop: 8,
                      padding: "8px 12px",
                      background: isUp ? "#d1fae5" : "#f3f4f6",
                      borderRadius: 6,
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      fontSize: "0.8rem"
                    }}>
                      <span style={{ fontWeight: 600, color: isUp ? "#065f46" : "#4b5563" }}>
                        ⛽ Consumo
                      </span>
                      <span style={{ fontWeight: 700, color: isUp ? "#059669" : "#6b7280" }}>
                        {isUp ? `${consumo.sesionActual.toFixed(2)} L` : `${consumo.historico.toFixed(1)} L`}
                      </span>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      ))}

      {porTipo.length === 0 && (
        <div className="k-card" style={{ padding:24, textAlign:"center", color:"var(--text-secondary,#6b7280)" }}>
          No hay monitores ICMP que coincidan con los filtros.
        </div>
      )}

      {selectedMonitor && (
        <EnergiaDetail
          monitor={selectedMonitor}
          onClose={() => setSelectedMonitor(null)}
        />
      )}
    </div>
  );
}
EOF

echo "✅ Energia.jsx limpiado"

# ========== 3. REINICIAR FRONTEND ==========
echo ""
echo "[3] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ COMPONENTE ENERGIA DETAIL CREADO ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA EN LA VISTA ENERGÍA:"
echo "   • Las cards de PLANTAS muestran el consumo actual"
echo "   • Al hacer click en una card, se abre el detalle"
echo "   • El detalle muestra consumo actual e histórico"
echo "   • Los datos se actualizan en tiempo real"
echo ""
