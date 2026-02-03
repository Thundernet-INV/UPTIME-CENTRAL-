import React from 'react';
import ServiceCard from './ServiceCard';

const ServiceGrid = ({ monitors = [] }) => {
  return (
    <div className="service-grid" aria-label="Listado de servicios / monitores">
      {monitors.map((item, index) => (
        <ServiceCard
          key={
            item.id ||
            item.info?.monitor_name ||
            `${item.instance || 'inst'}-${index}`
          }
          service={item}
        />
      ))}
    </div>
  );
};

export default ServiceGrid;
