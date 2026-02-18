// src/views/Energia.cards.helpers.js
export const ONLY_INSTANCE = 'energia';

export function normalizeTags(m) {
  const arr = Array.isArray(m?.tags)
    ? m.tags
    : (typeof m?.tag === 'string' ? [m.tag] : []);
  return (arr || [])
    .filter(Boolean)
    .map(x => String(x).trim())
    .map(x => x.toUpperCase());
}

export function getStatus(m) {
  try {
    // Detectores comunes de estado
    const raw =
      (m?.status ?? m?.state ?? (m?.online === true ? 'up' : (m?.online === false ? 'down' : undefined)) ?? (m?.up ? 'up' : undefined));
    const s = String(raw).toLowerCase();
    if (raw === true) return 'up';
    if (raw === false) return 'down';
    if (['up', 'online', 'ok', 'green'].includes(s)) return 'up';
    return 'down';
  } catch {
    return 'down';
  }
}

export function belongsToInstance(m) {
  try {
    const iname = (m?.instance ?? m?.instanceName ?? m?.service ?? '').toString().toLowerCase();
    if (iname === ONLY_INSTANCE) return true;
    const tags = normalizeTags(m);
    return tags.includes(ONLY_INSTANCE.toUpperCase());
  } catch {
    return false;
  }
}

export function categoryOf(m) {
  const tags = normalizeTags(m);
  const status = getStatus(m); // 'up' | 'down'
  const has = (x) => tags.includes(x);

  if (has('AVR')) return `AVR ${status.toUpperCase()}`;
  if (has('CORPOELEC')) return `CORPOELEC ${status.toUpperCase()}`;
  if (has('PLANTAS AP') || has('PLANTAS_AP') || has('PLANTAS-AP') || has('PLANTAS')) {
    return status === 'down' ? 'PLANTAS AP DOWN' : 'PLANTAS AP UP';
  }
  return `OTROS ${status.toUpperCase()}`;
}

export function firstNonEnergiaTag(tags) {
  const t = (tags || []).filter(x => x !== 'ENERGIA');
  return t[0] || 'SIN_ETIQUETA';
}

export function groupByTag(items) {
  const g = {};
  for (const m of (items || [])) {
    const tag = firstNonEnergiaTag(normalizeTags(m));
    (g[tag] ||= []).push(m);
  }
  return g;
}

export const ORDER = [
  'AVR UP',
  'AVR DOWN',
  'CORPOELEC UP',
  'CORPOELEC DOWN',
  'PLANTAS AP DOWN',
  'PLANTAS AP UP',
  'OTROS UP',
  'OTROS DOWN'
];
