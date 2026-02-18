// Auto-generado por fix-energia-imports.v4.sh
// Provee un export default robusto desde Energia.jsx sin modificarlo.
import * as EnergiaModule from './Energia.jsx';
import React from 'react';

// Heurística para resolver el componente:
const pickFirstFunction = (mod) => {
  try {
    const vals = Object.values(mod);
    for (const v of vals) {
      if (typeof v === 'function') return v;
      if (v && typeof v === 'object' && typeof v.$$typeof !== 'undefined') return v; // React.forwardRef, memo, etc.
    }
    return null;
  } catch {
    return null;
  }
};

const resolved =
  (('default' in EnergiaModule) ? EnergiaModule.default : undefined) ??
  EnergiaModule.Energia ??
  pickFirstFunction(EnergiaModule);

const Energia = resolved ?? (() => null);

export default Energia;
export { Energia };
