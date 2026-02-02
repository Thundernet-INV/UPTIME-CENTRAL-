// src/lib/sla.js
export function uptimePct(points = []) {
  if (!points.length) return 100;
  const up = points.filter(p => p?.status === 1).length;
  return +(100 * up / points.length).toFixed(2);
}

export function breaches(points = [], config = {}) {
  const { uptimeTarget = 99.9, maxLatencyMs = 800 } = config;
  const upPct = uptimePct(points);

  const rts = points.map(p => p?.responseTime).filter(v => Number.isFinite(v)).sort((a, b) => a - b);
  const pick = (p) => {
    if (!rts.length) return undefined;
    const idx = Math.min(rts.length - 1, Math.floor((p / 100) * rts.length));
    return rts[idx];
  };
  const p95 = pick(95);
  const p99 = pick(99);

  const issues = [];
  if (upPct < uptimeTarget) issues.push(`Uptime ${upPct}% < objetivo ${uptimeTarget}%`);
  if (p95 != null && p95 > maxLatencyMs) issues.push(`P95 ${p95} ms > ${maxLatencyMs} ms`);
  if (p99 != null && p99 > maxLatencyMs * 1.2) issues.push(`P99 ${p99} ms > ${Math.round(maxLatencyMs * 1.2)} ms`);

  return { ok: issues.length === 0, issues, details: { uptime: upPct, p95, p99 } };
}
