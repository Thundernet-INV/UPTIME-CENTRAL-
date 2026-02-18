// src/views/Energia.metrics.helpers.js
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
  const has = (x) => tags.includes(x);
  if (has('AVR')) return 'avr';
  if (has('PLANTAS') || has('PLANTAS AP') || has('PLANTAS_AP') || has('PLANTA')) return 'plantas';
  if (has('CORPOELEC')) return 'corpoelec';
  if (has('INVERSOR') || has('INVERTER')) return 'inversor';
  return 'otros';
}

export const CATEGORY_LABEL = {
  avr: 'AVR',
  plantas: 'PLANTAS',
  corpoelec: 'CORPOELEC',
  inversor: 'INVERSOR',
  otros: 'OTROS'
};

export function computeMetrics(items = []) {
  const total = items.length;
  let up = 0, down = 0;
  for (const m of items) {
    const s = getStatus(m);
    if (s === 'up') up++; else down++;
  }
  const uptime = total > 0 ? Math.round((up / total) * 100) : 0;
  return { total, up, down, uptime };
}
