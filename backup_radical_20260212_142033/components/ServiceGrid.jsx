import React, { useMemo } from "react";
import ServiceCard from "./ServiceCard.jsx";

/**
 * ServiceGrid (versión Downdetector)
 * Recibe:
 *  - monitorsAll: lista de monitores filtrados (Dashboard)
 *  - hiddenSet, onHideAll, onUnhideAll (por ahora los dejamos para futuro)
 *  - onOpen(instanceName): navegar a detalle de sede
 */
export default function ServiceGrid({
  monitorsAll = [],
  hiddenSet = new Set(),
  onHideAll,
  onUnhideAll,
  onOpen,
}) {
  // Agrupar monitores por instancia
  const instances = useMemo(() => {
    const map = new Map();
    for (const m of monitorsAll) {
      const instName = m.instance || "Desconocido";
      if (!map.has(instName)) {
        map.set(instName, {
          name: instName,
          monitors: [],
        });
      }
      map.get(instName).monitors.push(m);
    }
    // ordenar por nombre
    return Array.from(map.values()).sort((a, b) =>
      a.name.localeCompare(b.name, "es", { sensitivity: "base" })
    );
  }, [monitorsAll]);

  return (
    <div>
      {instances.map((inst) => {
        const total = inst.monitors.length;
        let down = 0;
        let issues = 0;

        for (const m of inst.monitors) {
          const latest = m.latest || {};
          const status =
            typeof latest.status === "number" ? latest.status : null;
          const rt = latest.responseTime;

          if (status === 0 || rt === -1) {
            down += 1;
          } else if (status !== 1 || (typeof rt === "number" && rt > 1500)) {
            issues += 1;
          }
        }

        let pillStatus = "ok";
        if (down > 0) pillStatus = "down";
        else if (issues > 0) pillStatus = "issues";

        const pillText =
          pillStatus === "down"
            ? `${down} monitores con fallas`
            : pillStatus === "issues"
            ? `${issues} monitores con posibles problemas`
            : "Sin incidencias";

        return (
          <section key={inst.name} className="instance-section">
            <header className="instance-header">
              <div>
                <h2 className="instance-title">{inst.name}</h2>
                <p className="instance-meta">
                  {inst.monitors.length} monitores ·{" "}
                  <span>
                    {down} DOWN · {issues} con posibles problemas
                  </span>
                </p>
              </div>
              <div
                className={`instance-status-pill instance-status-pill--${pillStatus}`}
              >
                {pillText}
              </div>
            </header>

            {/* Grid de servicios con estilo Downdetector */}
            <div className="service-grid">
              {inst.monitors.map((m, idx) => (
                <div
                  key={idx}
                  onClick={() => onOpen?.(inst.name)}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" || e.key === " ") {
                      e.preventDefault();
                      onOpen?.(inst.name);
                    }
                  }}
                >
                  <ServiceCard service={m} />
                </div>
              ))}
            </div>
          </section>
        );
      })}
    </div>
  );
}