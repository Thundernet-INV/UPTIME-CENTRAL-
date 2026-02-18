// src/views/EnergiaCards.jsx
import React from 'react';
import { belongsToInstance, categoryOf, groupByTag, ORDER, getStatus } from './Energia.cards.helpers.js';
import './energia-cards.css';

function StatusDot({ status }) {
  const st = (status || '').toLowerCase();
  const cls = st === 'up' ? 'dot up' : 'dot down';
  return <span className={cls} title={st.toUpperCase()} />;
}

export default function EnergiaCards({ items = [] }) {
  const filtered = (items || []).filter(belongsToInstance);

  // Bucket por categoría
  const buckets = {};
  for (const m of filtered) {
    const cat = categoryOf(m);
    (buckets[cat] ||= []).push(m);
  }

  // Ordenar categorías con ORDER y luego las desconocidas
  const categories = [
    ...ORDER.filter(k => Array.isArray(buckets[k]) && buckets[k].length > 0),
    ...Object.keys(buckets).filter(k => !ORDER.includes(k))
  ];

  if (categories.length === 0) {
    return <div className="energia-cards"><div className="empty">No hay datos para la instancia ENERGIA.</div></div>;
  }

  return (
    <div className="energia-cards">
      {categories.map(cat => {
        const byTag = groupByTag(buckets[cat]);
        return (
          <div key={cat} className="card">
            <div className="card-header">{cat}</div>
            <div className="card-body">
              {Object.entries(byTag).map(([tag, list]) => (
                <div key={tag} className="tag-block">
                  <div className="tag-title">{tag}</div>
                  <ul className="tag-list">
                    {list.map((m, i) => {
                      const id = m?.id ?? m?.key ?? `${m?.name || m?.displayName || 'item'}-${i}`;
                      const label = m?.name || m?.displayName || m?.title || m?.host || String(id);
                      const status = getStatus(m);
                      return (
                        <li key={id} className="item">
                          <StatusDot status={status} />
                          <span className="label">{label}</span>
                        </li>
                      );
                    })}
                  </ul>
                </div>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}
