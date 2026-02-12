import React, { useMemo } from "react";

const countStatus = (monitors) => {
  let total = monitors.length;
  let up = 0;
  let down = 0;
  let issues = 0;

  for (const m of monitors) {
    const latest = m.latest || {};
    const status =
      typeof latest.status === "number" ? latest.status : null;
    const rt = latest.responseTime;

    // DOWN: status 0 o responseTime -1
    if (status === 0 || rt === -1) {
      down += 1;
    } else if (
      status === 1 &&
      typeof rt === "number" &&
      rt <= 1500
    ) {
      // OK
      up += 1;
    } else if (
      status !== null // cualquier otro caso se considera "issues"
    ) {
      issues += 1;
    }
  }

  // Si hay monitores sin status, se quedan fuera de up/down/issues
  const uptimePercent = total > 0 ? Math.round((up / total) * 100) : null;

  return { total, up, down, issues, uptimePercent };
};

const InstanceCard = ({ instance, monitors = [], onClick }) => {
  const { name } = instance;

  const { total, up, down, issues, uptimePercent } = useMemo(
    () => countStatus(monitors),
    [monitors]
  );

  // Severidad visual
  let severity = "ok"; // ok | issues | down
  if (down > 0) {
    severity = "down";
  } else if (issues > 0) {
    severity = "issues";
  }

  const statusLabel =
    severity === "down"
      ? "Incidencias críticas"
      : severity === "issues"
      ? "En observación"
      : "Operativa";

  const pillText =
    severity === "down"
      ? `${down} DOWN`
      : severity === "issues"
      ? `${issues} con posibles problemas`
      : "Sin incidencias";

  const handleClick = () => {
    if (onClick && name) {
      onClick(name);
    }
  };

  const firstLetter = name ? name.charAt(0).toUpperCase() : "?";

  return (
    <article
      className={`service-card instance-card instance-card--${severity}`}
      onClick={handleClick}
      tabIndex={0}
      role="button"
      aria-label={`Sede ${name}. ${total} monitores, ${down} DOWN, ${issues} con posibles problemas.`}
      onKeyDown={(event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          handleClick();
        }
      }}
    >
      {/* Cabecera: avatar + estado corto */}
      <header className="instance-card-header">
        <div className="instance-card-avatar" aria-hidden="true">
          {firstLetter}
        </div>

        <div className="instance-card-header-text">
          <h2 className="instance-card-title">{name}</h2>
          <p className="instance-card-status-label">{statusLabel}</p>
        </div>
      </header>

      {/* Métricas */}
      <p className="instance-card-meta">
        {total} monitores · {down} DOWN · {issues} con posibles problemas
      </p>

      {uptimePercent !== null && (
        <p className="instance-card-uptime">
          Uptime estimado: <strong>{uptimePercent}%</strong>
        </p>
      )}

      {/* Pill de estado principal */}
      <span
        className={`instance-card-pill instance-card-pill--${severity}`}
      >
        {pillText}
      </span>
    </article>
  );
};

export default InstanceCard;
