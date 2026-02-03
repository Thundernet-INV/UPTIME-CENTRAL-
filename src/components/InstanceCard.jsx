import React, { useMemo } from 'react';

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

const InstanceCard = ({ instance, onClick }) => {
  const { name, monitors = [] } = instance;

  const { total, down, issues } = useMemo(
    () => countStatus(monitors),
    [monitors],
  );

  let pillStatus = 'ok';
  if (down > 0) {
    pillStatus = 'down';
  } else if (issues > 0) {
    pillStatus = 'issues';
  }

  const pillText =
    pillStatus === 'down'
      ? `${down} DOWN`
      : pillStatus === 'issues'
      ? `${issues} con posibles problemas`
      : 'Sin incidencias';

  const handleClick = () => {
    if (onClick) {
      onClick(name);
    }
  };

  return (
    <article
      className={`instance-card instance-card--${pillStatus}`}
      onClick={handleClick}
      role="button"
      tabIndex={0}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          handleClick();
        }
      }}
    >
      <div className="instance-card-header">
        <div className="instance-avatar" aria-hidden="true">
          {name ? name.charAt(0).toUpperCase() : '?'}
        </div>
        <h3 className="instance-card-title">{name}</h3>
      </div>
      <p className="instance-card-meta">
        {total} monitores · {down} DOWN · {issues} con posibles problemas
      </p>
      <div
        className={`instance-card-pill instance-card-pill--${pillStatus}`}
      >
        {pillText}
      </div>
    </article>
  );
};

export default InstanceCard;
