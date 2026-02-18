// src/views/EnergiaCategoryDetail.jsx
import React, { useMemo } from 'react';
import { belongsToInstance, categoryOf, CATEGORY_LABEL, computeMetrics, getStatus } from './Energia.metrics.helpers.js';
import './energia-cards-v5.css';

let MultiServiceView = null;
try {
  MultiServiceView = require('./MultiServiceView.jsx').default || null;
} catch (e) { /* noop */ }

export default function EnergiaCategoryDetail({ items = [], slug }) {
  const filtered = useMemo(() => {
    const base = (items || []).filter(belongsToInstance);
    return base.filter(m => categoryOf(m) === slug);
  }, [items, slug]);

  const metrics = computeMetrics(filtered);
  const goBack = () => { location.hash = '#/energia'; };

  return (
    <div className="energia-detail">
      <div className="detail-header">
        <button className="btn" onClick={goBack}>← Volver</button>
        <h2>{CATEGORY_LABEL[slug]} · <small>Instancia: energía</small></h2>
        <div className="detail-stats">{metrics.total} sensores · {metrics.up} UP · {metrics.down} DOWN · SLA: <b>{metrics.uptime}%</b></div>
      </div>

      {MultiServiceView ? (
        <div className="detail-charts">
          <MultiServiceView monitors={filtered} title={`${CATEGORY_LABEL[slug]} · Gráficas`} />
        </div>
      ) : null}

      <div className="detail-list">
        <ul>
          {filtered.map((m, i) => {
            const id = m?.id ?? m?.key ?? `${m?.name || 'item'}-${i}`;
            const label = m?.name || m?.displayName || m?.title || m?.host || String(id);
            const st = getStatus(m);
            return (
              <li key={id} className={`eq-item ${st}`}>
                <span className={`dot ${st}`} />
                <span className="label">{label}</span>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
