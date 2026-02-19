        if (alive) setMonitors(Array.isArray(data?.monitors) ? data.monitors : []);
      } catch (e) {        if (alive) setMonitors(Array.isArray(data?.monitors) ? data.monitors : []);
      } catch (e) {import React, { useEffect, useMemo, useState } from "react";
import { fetchAll } from "../api.js";
import ServiceCard from "../components/ServiceCard.jsx";
import { TIPOS_EQUIPO, normalizarTags, deducirTipoPorNombre } from "../lib/equiposConfig.js";

function Chip({ active, children, onClick }) {
  return (
    <button type="button" onClick={onClick} className="k-btn" style={{
      padding: "6px 12px", borderRadius: "16px",
      border: "1px solid var(--border, #e5e7eb)",
      background: active ? "var(--info, #3b82f6)" : "transparent",
      color: active ? "#fff" : "var(--text-primary, #1f2937)",
      fontSize: "0.85rem", cursor: "pointer", transition: "all 0.2s ease",
    }}>
      {children}
    </button>
  );
}

export default function Equipos() {
  const [monitors, setMonitors] = useState([]);
  const [tipoSel, setTipoSel] = useState("");
  const [tagSel, setTagSel] = useState("");
  const [q, setQ] = useState("");

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const data = await fetchAll();
        if (alive) setMonitors(Array.isArray(data?.monitors) ? data.monitors : []);
      } catch (e) {
        console.error("[Equipos] Error fetchAll:", e);
        if (alive) setMonitors([]);
      }
    })();
    return () => { alive = false; };
  }, []);

  const catalog = useMemo(() => {
    return monitors.map(m => {
      const name = m?.info?.monitor_name ?? m?.name ?? "";
      const tipo = m?.info?.tipo_equipo || deducirTipoPorNombre(name) || "OTRO";
      const tags = normalizarTags(m?.info?.tags || []);
      return { raw: m, name, tipo, tags };
    });
  }, [monitors]);

  const etiquetasDisponibles = useMemo(() => {
    const set = new Set();
    catalog.forEach(x => x.tags.forEach(t => set.add(t)));
    return Array.from(set).sort();
  }, [catalog]);

  const filtrados = useMemo(() => {
    const text = q.trim().toLowerCase();
    return catalog.filter(item => {
      const okTipo = !tipoSel || item.tipo === tipoSel;
      const okTag = !tagSel || item.tags.includes(tagSel.toUpperCase());
      const okText = !text ||
        item.name.toLowerCase().includes(text) ||
        item?.raw?.instance?.toLowerCase?.().includes(text);
      return okTipo && okTag && okText;
    });
  }, [catalog, tipoSel, tagSel, q]);

  const porTipo = useMemo(() => {
    const map = new Map();
    filtrados.forEach(item => {
      const key = TIPOS_EQUIPO.includes(item.tipo) ? item.tipo : "OTRO";
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(item);
    });
    const orden = [...TIPOS_EQUIPO, "OTRO"];
    return orden.filter(k => map.has(k)).map(k => ({ tipo: k, items: map.get(k) }));
  }, [filtrados]);

  return (
    <div style={{ padding: "24px" }}>
              {/* BOTÓN FLOTANTE - ADMIN PLANTAS */}
      <button
        onClick={() => window.location.hash = '#/admin-plantas'}
        style={{
          position: 'fixed',
          bottom: '30px',
          right: '30px',
          zIndex: 99999,
          padding: '16px 28px',
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          color: 'white',
          border: 'none',
          borderRadius: '60px',
          cursor: 'pointer',
          fontSize: '1.2rem',
          display: 'flex',
          alignItems: 'center',
          gap: '12px',
          fontWeight: 700,
          boxShadow: '0 10px 25px rgba(102, 126, 234, 0.4)',
          border: '2px solid white'
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.transform = 'scale(1.1)';
          e.currentTarget.style.boxShadow = '0 15px 30px rgba(102, 126, 234, 0.6)';
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.transform = 'scale(1)';
          e.currentTarget.style.boxShadow = '0 10px 25px rgba(102, 126, 234, 0.4)';
        }}
      >
        <span style={{ fontSize: '2rem' }}>🔧</span><s
        <span>ADMIN PLANTAS</span>
      </button>

      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16 }}>
        <h2 className="k-card__title" style={{ margin: 0, color: 'red', fontSize: '32px' }}>🔥 ESTO ES UNA PRUEBA - SI VES ESTO, EL ARCHIVO ES EL CORRECTO 🔥</h2>
        <input type="search" placeholder="Buscar por nombre o sede…" value={q}
          onChange={e => setQ(e.target.value)}
          style={{ padding: "8px 12px", border: "1px solid var(--border, #e5e7eb)", borderRadius: 8,
                   background: "var(--input-bg, #fff)", color: "var(--text-primary, #1f2937)", minWidth: 260 }} />
      </div>

      <div className="k-card" style={{ padding: 16, marginBottom: 16 }}>
        <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "center" }}>
          <strong>Tipo:</strong>
          <Chip active={tipoSel === ""} onClick={() => setTipoSel("")}>Todos</Chip>
          {TIPOS_EQUIPO.map(t => (
            <Chip key={t} active={tipoSel === t} onClick={() => setTipoSel(t)}>{t}</Chip>
          ))}
        </div>
        <div style={{ height: 12 }} />
        <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "center" }}>
          <strong>Etiqueta:</strong>
          <Chip active={tagSel === ""} onClick={() => setTagSel("")}>Todas</Chip>
          {etiquetasDisponibles.map(tag => (
            <Chip key={tag} active={tagSel === tag} onClick={() => setTagSel(tag)}>{tag}</Chip>
          ))}
        </div>
      </div>

      {porTipo.map(seccion => (
        <div key={seccion.tipo} style={{ marginBottom: 24 }}>
          <h3 className="k-card__title" style={{ margin: "0 0 12px 0" }}>
            {seccion.tipo} · {seccion.items.length}
          </h3>
          <div className="instance-grid"
               style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))", gap: 12 }}>
            {seccion.items.map(({ raw, name }) => (
              <div key={`${raw.instance ?? "?"}-${name}`} className="k-card" style={{ padding: 12 }}>
                <ServiceCard service={raw} series={[]} />
              </div>
            ))}
          </div>
        </div>
      ))}

      {porTipo.length === 0 && (
        <div className="k-card" style={{ padding: 24, textAlign: "center", color: "var(--text-secondary, #6b7280)" }}>
          No hay resultados con los filtros actuales.
        </div>
      )}
    </div>
  );
}
