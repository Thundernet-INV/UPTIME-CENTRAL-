// src/views/EnergiaOverviewCards.jsx
import React from 'react';
import { belongsToInstance, categoryOf, CATEGORY_LABEL, computeMetrics } from './Energia.metrics.helpers.js';
import './energia-cards-v5.css';

const ORDER = ['avr','corpoelec','plantas','inversor'];

function Badge({ down }) {
  if (down > 0) return <span className="badge danger">{down} DOWN</span>;
  return <span className="badge ok">Sin incidencias</span>;
}

export default function EnergiaOverviewCards({ items = [] }) {
  const filtered = (items || []).filter(belongsToInstance);
  const byCat = {};
  for (const m of filtered) {
    const c = categoryOf(m);
    if (!['avr','corpoelec','plantas','inversor'].includes(c)) continue;
    (byCat[c] ||= []).push(m);
  }
  const categories = ORDER.filter(c => Array.isArray(byCat[c]));

  return (
    <div className="instances-grid energia">
      {categories.map(c => {
        const metrics = computeMetrics(byCat[c]);
        const go = () => {
          const slug = c;
          const base = '#/energia';
          if (location.hash.startsWith(base)) {
            location.hash = `${base}/${slug}`;
          } else {
            location.hash = `${base}`;
            setTimeout(() => { location.hash = `${base}/${slug}`; }, 0);
          }
        };
        return (
          <div key={c}
               className="instance-card energia-card"
               onClick={go}
               role="button"
               tabIndex={0}
               onKeyDown={(e)=> (e.key==='Enter'||e.key===' ') && go()}>
            <div className="inst-head">
              <div className="inst-avatar">{CATEGORY_LABEL[c][0]}</div>
              <div className="inst-title">{CATEGORY_LABEL[c]}</div>
              <div className="inst-subtitle">Instancia: energía</div>
            </div>
            <div className="inst-body">
              <div className="inst-metric">{metrics.total} sensores · {metrics.up} UP · {metrics.down} DOWN</div>
              <div className="inst-uptime">Uptime estimado: <b>{metrics.uptime}%</b></div>
            </div>
            <div className="inst-footer">
              <Badge down={metrics.down} />
            </div>
          </div>
        );
      })}
    </div>
  );
}
