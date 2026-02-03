import React from 'react';

const STATUS_LABEL = {
  ok: 'Sin problemas',
  issues: 'Posibles problemas',
  down: 'Fuera de servicio',
};

const getStatusInfo = (service) => {
  const latest = service.latest || {};
  const responseTime = latest.responseTime;
  const numericStatus =
    typeof latest.status === 'number' ? latest.status : null;

  let statusKey = 'ok';

  if (numericStatus === 0 || responseTime === -1) {
    statusKey = 'down';
  } else if (numericStatus !== 1) {
    statusKey = 'issues';
  } else if (typeof responseTime === 'number' && responseTime > 1500) {
    statusKey = 'issues';
  }

  return {
    statusKey,
    label: STATUS_LABEL[statusKey] || 'Estado desconocido',
  };
};

const formatResponseTime = (value) => {
  if (value == null || Number.isNaN(value)) return '—';
  const num = Number(value);
  if (num < 1 && num > 0) {
    return `${num.toFixed(2)} ms`;
  }
  return `${Math.round(num)} ms`;
};

const getLogoUrl = (service) => {
  const url = service.info?.monitor_url;
  if (!url || url === 'https://' || url === 'http://') {
    return null;
  }
  try {
    const withProtocol = url.startsWith('http') ? url : `https://${url}`;
    const domain = new URL(withProtocol).hostname;
    return `https://www.google.com/s2/favicons?sz=64&domain=${domain}`;
  } catch (e) {
    return null;
  }
};

const ServiceCard = ({ service }) => {
  const monitorName =
    service.info?.monitor_name || service.name || 'Servicio sin nombre';
  const monitorType = service.info?.monitor_type || '';
  const latest = service.latest || {};
  const { statusKey, label } = getStatusInfo(service);
  const logoUrl = getLogoUrl(service);

  return (
    <article className={`service-card service-card--${statusKey}`}>
      <div className="service-card-header">
        {logoUrl ? (
          <img
            src={logoUrl}
            alt={`Logo de ${monitorName}`}
            className="service-logo"
          />
        ) : (
          <div className="service-avatar" aria-hidden="true">
            {monitorName ? monitorName.charAt(0).toUpperCase() : '?'}
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

      <p className="service-card-status">{label}</p>

      <div className="service-card-footer">
        <span className="service-card-latency-label">Latencia</span>
        <span className="service-card-latency-value">
          {formatResponseTime(latest.responseTime)}
        </span>
      </div>

      <div className="service-card-mini-chart" aria-hidden="true" />
    </article>
  );
};

export default ServiceCard;
