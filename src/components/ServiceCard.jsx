import React from "react";
import Sparkline from "./Sparkline.jsx";

const STATUS_LABEL = {
  ok: "Sin problemas",
  issues: "Posibles problemas",
  down: "Fuera de servicio",
};

function getStatusInfo(service) {
  const latest = service.latest || {};
  const responseTime = latest.responseTime;
  const numericStatus =
    typeof latest.status === "number" ? latest.status : null;

  let statusKey = "ok";

  if (numericStatus === 0 || responseTime === -1) {
    statusKey = "down";
  } else if (numericStatus !== 1) {
    statusKey = "issues";
  } else if (typeof responseTime === "number" && responseTime > 1500) {
    statusKey = "issues";
  }

  return {
    statusKey,
    label: STATUS_LABEL[statusKey] || "Estado desconocido",
  };
}

function formatResponseTime(value) {
  if (value == null || Number.isNaN(value)) return "—";
  const num = Number(value);
  if (num < 1 && num > 0) {
    return `${num.toFixed(2)} ms`;
  }
  return `${Math.round(num)} ms`;
}

function getLogoUrl(service) {
  const url = service.info?.monitor_url;
  if (!url || url === "https://" || url === "http://") {
    return null;
  }
  try {
    const withProtocol = url.startsWith("http") ? url : `https://${url}`;
    const domain = new URL(withProtocol).hostname;
    return `https://www.google.com/s2/favicons?sz=64&domain=${domain}`;
  } catch (e) {
    return null;
  }
}

/**
 * ServiceCard
 *  - service: objeto monitor (como viene de fetchAll)
 *  - series: array de puntos de historial (para Sparkline), opcional
 */
const ServiceCard = ({ service, series = [] }) => {
  const monitorName =
    service.info?.monitor_name || service.name || "Servicio sin nombre";
  const monitorType = service.info?.monitor_type || "";
  const latest = service.latest || {};

  const { statusKey, label } = getStatusInfo(service);
  const logoUrl = getLogoUrl(service);

  return (
    <article className={`service-card service-card--${statusKey}`}>
      {/* Header: logo + textos */}
      <div className="service-card-header">
        {logoUrl ? (
          <img
            src={logoUrl}
            alt={`Logo de ${monitorName}`}
            className="service-logo"
          />
        ) : (
          <div className="service-avatar" aria-hidden="true">
            {monitorName ? monitorName.charAt(0).toUpperCase() : "?"}
          </div>
        )}

        <div className="service-card-header-text">
          <h3 className="service-card-title" title={monitorName}>
            {monitorName}
          </h3>
          {monitorType && (
            <span className="service-card-type">
              {monitorType.toUpperCase()}
            </span>
          )}
        </div>
      </div>

      {/* Estado textual */}
      <p className="service-card-status">{label}</p>

      {/* Latencia */}
      <div className="service-card-footer">
        <span className="service-card-latency-label">Latencia</span>
        <span className="service-card-latency-value">
          {formatResponseTime(latest.responseTime)}
        </span>
      </div>
{/* Tendencia (Sparkline) dentro de la card */}
      <div className="service-card-mini-chart" aria-hidden="true">
        {Array.isArray(series) && series.length > 0 ? (
          <Sparkline
            points={series}
            color={statusKey === "down" ? "#dc2626" : "#16a34a"}
            width={300}
            height={70}
          />
        ) : null}
      </div>
     </article>
  );
};

export default ServiceCard;
