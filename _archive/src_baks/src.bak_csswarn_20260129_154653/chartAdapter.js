import History from './historyEngine';

// Adaptador para series de "promedio por sede"
export async function getInstanceAvgXY(instance, minutes=15) {
  const arr = await History.getAvgSeriesByInstance(instance, minutes*60*1000);
  // Aseguramos pares [x,y] en segundos y un objeto 'dataset' con llaves comunes
  const xy = (arr || []).map(p => [p.x ?? p.ts, (p.y ?? (p.ms/1000) ?? p.sec ?? 0)]);
  const ds = (arr || []).map(p => ({
    x: p.x ?? p.ts,
    y: p.y ?? ((p.ms ?? p.avgMs) / 1000) ?? p.sec ?? 0,
    ms: p.ms ?? p.avgMs ?? (p.y*1000) ?? null,
  }));
  // Exponer para depuración rápida
  try { if (typeof window !== 'undefined') window.__chartData = { xy, ds, len: ds.length }; } catch {}
  console.log('[ADAPTER] getInstanceAvgXY', instance, '->', ds.length, 'points');
  return { xy, ds };
}
