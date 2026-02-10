import React, { useEffect, useMemo, useRef, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";

const RANGE_MS = 15 * 60 * 1000; // rango temporal para pedir histórico

// Color estable a partir del nombre de la sede (para que no se repitan)
function getColorForInstance(name = "") {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  const hue = hash % 360; // 0–359
  const saturation = 70;
  const lightness = 50;
  return `hsl(${hue}, ${saturation}%, ${lightness}%)`;
}

export default function MultiServiceView({ monitorsAll = [] }) {
  // 1) Lista de servicios HTTP únicos (case-insensitive)
  const services = useMemo(() => {
    const map = new Map();
    for (const m of monitorsAll) {
      const typeRaw = m.info?.monitor_type ?? "";
      if (typeRaw.toLowerCase() !== "http") continue; // SOLO HTTP

      const name = m.info?.monitor_name ?? m.name ?? "";
      if (!name) continue;

      const type = typeRaw.toLowerCase();
      if (!map.has(name)) {
        map.set(name, { name, type, count: 0 });
      }
      map.get(name).count += 1;
    }
    return Array.from(map.values()).sort((a, b) =>
      a.name.localeCompare(b.name, "es", { sensitivity: "base" })
    );
  }, [monitorsAll]);

  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesByInstance, setSeriesByInstance] = useState(new Map());
  const [loading, setLoading] = useState(false);
  const [autoRotate, setAutoRotate] = useState(false);
  const [rotateIntervalSec, setRotateIntervalSec] = useState(8); // segundos entre servicios

  // Flag: el usuario ya tocó la selección de sedes?
  const [userTouchedInstances, setUserTouchedInstances] = useState(false);

  // Ref estable con la lista de servicios (para autoplay sin reinicios)
  const servicesRef = useRef([]);
  useEffect(() => {
    servicesRef.current = services;
  }, [services]);

  // 2) Sedes que tienen ese servicio HTTP
  const instancesWithService = useMemo(() => {
    if (!selectedService) return [];
    const set = new Set();
    for (const m of monitorsAll) {
      const typeRaw = m.info?.monitor_type ?? "";
      if (typeRaw.toLowerCase() !== "http") continue;

      const name = m.info?.monitor_name ?? m.name ?? "";
      if (name === selectedService && m.instance) {
        set.add(m.instance);
      }
    }
    return Array.from(set).sort();
  }, [monitorsAll, selectedService]);

  // 3) Elegir un servicio inicial automáticamente si no hay ninguno
  useEffect(() => {
    if (!selectedService && services.length > 0) {
      setSelectedService(services[0].name);
    }
  }, [services, selectedService]);

  // 4) Resetear el flag cuando se cambia de servicio
  useEffect(() => {
    setUserTouchedInstances(false);
  }, [selectedService]);

  // 5) Sincronizar sedes seleccionadas
  useEffect(() => {
    if (!instancesWithService || instancesWithService.length === 0) return;

    setSelectedInstances((prev) => {
      if (!userTouchedInstances) {
        // Sin interacción del usuario: seleccionamos todas las sedes disponibles
        return instancesWithService;
      }

      // Usuario ya eligió: mantener solo las sedes que siguen existiendo
      const intersection = prev.filter((name) =>
        instancesWithService.includes(name)
      );
      return intersection.length > 0 ? intersection : prev;
    });
  }, [instancesWithService, userTouchedInstances]);

  const toggleInstance = (name) => {
    setUserTouchedInstances(true);
    setSelectedInstances((prev) =>
      prev.includes(name) ? prev.filter((n) => n !== name) : [...prev, name]
    );
  };

  // 6) Cargar series (historial) solo cuando cambia servicio o sedes seleccionadas
  useEffect(() => {
    let alive = true;

    const fetchAll = async () => {
      if (!selectedService || selectedInstances.length === 0) {
        setSeriesByInstance(new Map());
        setLoading(false);
        return;
      }

      setLoading(true);
      try {
        const entries = await Promise.all(
          selectedInstances.map(async (instanceName) => {
            const arr = await History.getSeriesForMonitor(
              instanceName,
              selectedService,
              RANGE_MS
            );
            return [instanceName, Array.isArray(arr) ? arr : []];
          })
        );
        if (alive) setSeriesByInstance(new Map(entries));
      } finally {
        if (alive) setLoading(false);
      }
    };

    fetchAll();
    return () => {
      alive = false;
    };
  }, [selectedService, selectedInstances]);

  // 7) Auto-rotate: ir cambiando de servicio (WhatsApp -> Facebook -> Apple...)
  useEffect(() => {
    if (!autoRotate) return;

    const intervalMs = Math.max(2, Number(rotateIntervalSec) || 8) * 1000; // mínimo 2s
    const timer = setInterval(() => {
      const list = servicesRef.current;
      if (!list || list.length === 0) return;

      setSelectedService((prev) => {
        if (!prev) return list[0].name;
        const idx = list.findIndex((s) => s.name === prev);
        const nextIdx = idx === -1 ? 0 : (idx + 1) % list.length;
        return list[nextIdx].name;
      });
    }, intervalMs);

    return () => clearInterval(timer);
  }, [autoRotate, rotateIntervalSec]);

  // 8) Adaptar datos para HistoryChart (modo multi)
  const chartSeries = useMemo(() => {
    return selectedInstances.map((instanceName) => {
      const points = seriesByInstance.get(instanceName) ?? [];
      return {
        id: instanceName,
        label: instanceName, // nombre de la sede
        color: getColorForInstance(instanceName), // color único por sede
        points,
      };
    });
  }, [selectedInstances, seriesByInstance]);

  // Banderas auxiliares para la vista
  const hasService = !!selectedService;
  const hasSeries = chartSeries.length > 0;

  return (
    <div className="multi-view">
      <h2 className="multi-view-title">Comparar servicio HTTP por sede</h2>

      <section
        className="filters-toolbar"
        aria-label="Filtros de comparación"
      >
        {/* Servicio HTTP */}
        <div className="filter-group">
          <label className="filter-label" htmlFor="service-select">
            Servicio HTTP
          </label>
          <select
            id="service-select"
            className="filter-select"
            value={selectedService}
            onChange={(e) => setSelectedService(e.target.value)}
          >
            <option value="">Selecciona un servicio…</option>
            {services.map((s) => (
              <option key={s.name} value={s.name}>
                {s.name}{" "}
                {s.type ? `(${s.type.toUpperCase()})` : ""} · {s.count} monitores
              </option>
            ))}
          </select>
        </div>

        {/* Sedes */}
        {hasService && (
          <div className="filter-group">
            <span className="filter-label">Sedes</span>
            <div className="filter-chips">
              {instancesWithService.map((name) => {
                const isActive = selectedInstances.includes(name);
                return (
                  <button
                    key={name}
                    type="button"
                    className={
                      "k-btn k-btn--ghost" + (isActive ? " is-active" : "")
                    }
                    onClick={() => toggleInstance(name)}
                  >
                    {name}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Opciones de auto-rotación */}
        <div className="filter-group">
          <span className="filter-label">Opciones</span>
          <div
            className="filter-chips"
            style={{ alignItems: "center" }}
          >
            <button
              type="button"
              className={
                "k-btn k-btn--ghost" + (autoRotate ? " is-active" : "")
              }
              onClick={() => setAutoRotate((prev) => !prev)}
            >
              Auto: {autoRotate ? "ON" : "OFF"}
            </button>
            <span style={{ fontSize: "0.8rem", color: "#4b5563" }}>
              Cada
            </span>
            <input
              type="number"
              min={2}
              max={600}
              value={rotateIntervalSec}
              onChange={(e) => setRotateIntervalSec(e.target.value)}
              style={{
                width: 60,
                padding: "4px 6px",
                fontSize: "0.8rem",
                borderRadius: 6,
                border: "1px solid #e5e7eb",
                textAlign: "right",
              }}
            />
            <span style={{ fontSize: "0.8rem", color: "#4b5563" }}>seg</span>
          </div>
        </div>
      </section>

      <section
        className="multi-view-chart-section"
        aria-label="Gráfica comparativa de servicio HTTP por sede"
      >
        {/* Mensaje inicial si no hay servicio */}
        {!hasService && (
          <p className="muted">
            Selecciona un servicio HTTP para ver su comportamiento en todas las
            sedes.
          </p>
        )}

        {/* Sin datos para ese servicio */}
        {hasService && !hasSeries && !loading && (
          <p className="muted">
            No hay sedes seleccionadas o no se encontró historial para este
            servicio.
          </p>
        )}

        {/* Cargando por primera vez (sin datos previos) */}
        {hasService && !hasSeries && loading && (
          <p className="muted">Cargando series…</p>
        )}

        {/* Gráfica: siempre la mantenemos montada; solo añadimos overlay mientras carga */}
        {hasService && hasSeries && (
          <div className="multi-view-chart-wrapper">
            <HistoryChart mode="multi" seriesMulti={chartSeries} h={380} />
            {loading && (
              <div className="multi-view-chart-overlay">
                Actualizando datos…
              </div>
            )}
          </div>
        )}
      </section>
    </div>
  );
}
