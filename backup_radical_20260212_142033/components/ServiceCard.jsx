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

// 🟢 FUNCIÓN CORREGIDA: Mostrar IP para monitores PING
function getDisplayUrl(service) {
  const url = service.info?.monitor_url;
  const hostname = service.info?.monitor_hostname;
  const type = service.info?.monitor_type;
  
  // Para monitores PING: mostrar la IP directamente
  if (type === 'ping' && hostname) {
    return hostname;
  }
  
  // Para monitores DNS: mostrar el hostname con prefijo
  if (type === 'dns' && hostname) {
    return `dns://${hostname}`;
  }
  
  // Para HTTP: mostrar dominio limpio
  if (url && url !== 'https://' && url !== 'http://') {
    try {
      const domain = new URL(url).hostname.replace(/^www\./, '');
      return domain;
    } catch (e) {
      return url;
    }
  }
  
  // Fallback
  return hostname || url || '—';
}

// 🟢 FUNCIÓN CORREGIDA: Logo para monitores PING
function getLogoUrl(service) {
  const url = service.info?.monitor_url;
  const hostname = service.info?.monitor_hostname;
  const type = service.info?.monitor_type;
  
  // Para monitores PING: buscar favicon por IP/dominio
  if (type === 'ping' && hostname) {
    return `https://www.google.com/s2/favicons?sz=64&domain=${hostname}`;
  }
  
  // Para monitores DNS: usar hostname
  if (type === 'dns' && hostname) {
    return `https://www.google.com/s2/favicons?sz=64&domain=${hostname}`;
  }
  
  // Para HTTP: usar URL
  if (url && url !== 'https://' && url !== 'http://') {
    try {
      const domain = new URL(url).hostname;
      return `https://www.google.com/s2/favicons?sz=64&domain=${domain}`;
    } catch (e) {
      return null;
    }
  }
  
  return null;
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
  const displayUrl = getDisplayUrl(service);
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
            onError={(e) => {
              e.target.style.display = 'none';
              const avatar = e.target.parentNode.querySelector('.service-avatar');
              if (avatar) avatar.style.display = 'flex';
            }}
          />
        ) : null}
        <div 
          className="service-avatar" 
          style={{ display: logoUrl ? 'none' : 'flex' }}
        >
          {monitorName ? monitorName.charAt(0).toUpperCase() : "?"}
        </div>

        <div className="service-card-header-text">
          <h3 className="service-card-title" title={monitorName}>
            {monitorName}
          </h3>
          {monitorType && (
            <span className="service-card-type">
              {monitorType.toUpperCase()}
            </span>
          )}
          {/* 🟢 NUEVO: Mostrar IP/Dirección */}
          {displayUrl && displayUrl !== '—' && (
            <span className="service-card-url" title={displayUrl}>
              {displayUrl}
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
