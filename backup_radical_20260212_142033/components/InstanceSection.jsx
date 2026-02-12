import React, { useMemo } from 'react';
import ServiceGrid from './ServiceGrid';

const countStatus = (monitors) => {
  let total = monitors.length;
  let down = 0;
  let issues = 0;

  for (const m of monitors) {
    const latest = m.latest || {};
    const status = typeof latest.status === 'number' ? latest.status : null;
    const rt = latest.responseTime;

    if (status === 0 || rt === -1) {
      down += 1;
    } else if (status !== 1 || (typeof rt === 'number' && rt > 1500)) {
      issues += 1;
    }
  }

  return { total, down, issues };
};

const InstanceSection = ({ instance, search = '', typeFilter = 'all' }) => {
  const { name, monitors = [] } = instance;

  // Filtrar monitores según búsqueda y tipo
  const filteredMonitors = useMemo(() => {
    let list = monitors;

    if (search) {
      const q = search.toLowerCase();
      list = list.filter((m) =>
        (m.info?.monitor_name || '').toLowerCase().includes(q),
      );
    }

    if (typeFilter !== 'all') {
      list = list.filter((m) => m.info?.monitor_type === typeFilter);
    }

    return list;
  }, [monitors, search, typeFilter]);

  const { total, down, issues } = useMemo(
    () => countStatus(filteredMonitors),
    [filteredMonitors],
  );

  let pillStatus = 'ok';
  if (down > 0) {
    pillStatus = 'down';
  } else if (issues > 0) {
    pillStatus = 'issues';
  }

  const pillText =
    pillStatus === 'down'
      ? `${down} monitores con fallas`
      : pillStatus === 'issues'
      ? `${issues} monitores con posibles problemas`
      : 'Sin incidencias';

  return (
    <section className="instance-section">
      <header className="instance-header">
        <div>
          <h2 className="instance-title">{name}</h2>
          <p className="instance-meta">
            {filteredMonitors.length} monitores (de {total} totales) ·{' '}
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

      <ServiceGrid monitors={filteredMonitors} />
    </section>
  );
};

export default InstanceSection;
