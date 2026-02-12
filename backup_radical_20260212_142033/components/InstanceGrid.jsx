import React from 'react';
import InstanceCard from './InstanceCard';

const InstanceGrid = ({ instances = [], onSelectInstance }) => {
  return (
    <div className="instance-grid" aria-label="Listado de sedes / instancias">
      {instances.map((inst) => (
        <InstanceCard
          key={inst.name}
          instance={inst}
          onClick={onSelectInstance}
        />
      ))}
    </div>
  );
};

export default InstanceGrid;
