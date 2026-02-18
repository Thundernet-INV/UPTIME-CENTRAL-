import React, { useEffect, useMemo, useRef } from "react";

/**
 * AutoPlayer v7 (SEDE -> SEDE robusto)
 * - Un solo tiempo: sec (s).
 * - HOME: primer salto ~300ms.
 * - SEDE: tras sec s -> siguiente sede (loop), sin pasar por HOME.
 * - Determina la sede actual desde location.hash (no depende de route.instance).
 * - Normaliza a minúsculas para comparar nombres.
 * - Logs de programación y salto para diagnóstico.
 */
export default function AutoPlayer({
  enabled=false,
  sec=10,
  order="downFirst",
  onlyIncidents=false,
  loop=true,
  filteredAll=[],
  route,           // opcional (no dependemos de él para decidir la siguiente)
  openInstance     // opcional
}) {
  const idxRef = useRef(0);
  const timerRef = useRef(null);

  // Estadísticas por instancia (para orden y filtro "solo incidencias")
  const instanceStats = useMemo(() => {
    const map = new Map();
    for (const m of filteredAll) {
      const it = map.get(m.instance) || { up:0, down:0, total:0 };
      if (m.latest?.status === 1) it.up++; else if (m.latest?.status === 0) it.down++;
      it.total++;
      map.set(m.instance, it);
    }
    return map;
  }, [filteredAll]);

  // Playlist ordenado según configuración actual
  const playlist = useMemo(() => {
    let arr = Array.from(instanceStats.keys());
    if (onlyIncidents) arr = arr.filter(n => (instanceStats.get(n)?.down || 0) > 0);
    if (order === "downFirst") {
      arr.sort((a,b)=> (instanceStats.get(b)?.down||0) - (instanceStats.get(a)?.down||0) || a.localeCompare(b));
    } else {
      arr.sort((a,b)=> a.localeCompare(b));
    }
    return arr;
  }, [instanceStats, onlyIncidents, order]);

  // Mapa normalizado nombre -> índice
  const nameToIndex = useMemo(() => {
    const map = new Map();
    playlist.forEach((name, i) => map.set(String(name || '').toLowerCase(), i));
    return map;
  }, [playlist]);

  // Normalizar: nombre desde el hash actual
  const getNameFromHash = () => {
    try {
      const parts = (window.location.hash || "").slice(1).split("/").filter(Boolean);
      if (parts[0] === "sede" && parts[1]) return decodeURIComponent(parts[1]);
    } catch {}
    return null;
  };

  // Navegar a sede por hash (si no se pasó openInstance)
  const goByHash = (name) => { window.location.hash = "/sede/" + encodeURIComponent(name); };

  // Sincronizar idxRef con una sede dada (si está en el playlist)
  const syncIndexWithName = (name) => {
    const key = String(name || '').toLowerCase();
    const i = nameToIndex.has(key) ? nameToIndex.get(key) : -1;
    if (i >= 0) idxRef.current = i;
    return i;
  };

  // Obtener la siguiente sede a partir de una "actual" (por nombre)
  const getNextFromName = (currentName) => {
    const i = syncIndexWithName(currentName);
    let nextIdx = (i >= 0) ? (i + 1) : idxRef.current; // si no se encontró, usa el índice interno
    if (nextIdx >= playlist.length) {
      if (!loop) return null;
      nextIdx = 0;
    }
    return playlist[nextIdx] || null;
  };

  // Mantener idxRef dentro de rango si cambia el tamaño del playlist
  useEffect(() => {
    if (idxRef.current >= playlist.length) idxRef.current = 0;
  }, [playlist.length]);

  // Exponer estado debug
  useEffect(() => {
    if (typeof window !== "undefined") {
      window.__apDebug = {
        enabled,
        route: route?.name,
        instance: route?.instance || getNameFromHash(),
        count: playlist.length,
        currentIdx: idxRef.current,
        next: (playlist.length ? playlist[idxRef.current % playlist.length] : null),
        sec, onlyIncidents, order, loop
      };
    }
  }, [enabled, route?.name, route?.instance, playlist.length, sec, onlyIncidents, order, loop]);

  // Programación de saltos
  useEffect(() => {
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; }
    if (!enabled || !playlist.length) return;

    const SEC = Math.max(1, Number(sec) || 10);

    const gotoNextFromHash = () => {
      const current = getNameFromHash();
      // Si no hay sede actual (estábamos en HOME), toma la que apunte idxRef
      const nextName = current ? getNextFromName(current) : playlist[idxRef.current];
      if (!nextName) return;
      // Mueve el índice a la elegida
      syncIndexWithName(nextName);
      console.log("[APv7] gotoNext:", { from: current || "(home)", to: nextName, sec: SEC });
      if (typeof openInstance === "function") openInstance(nextName); else goByHash(nextName);
    };

    const routeName = route?.name || (getNameFromHash() ? "sede" : "home");
    if (routeName === "home") {
      console.log("[APv7] schedule@home:", 300, "ms", { sec: SEC, items: playlist.length, idx: idxRef.current });
      timerRef.current = setTimeout(gotoNextFromHash, 300);
    } else {
      console.log("[APv7] schedule@sede:", SEC * 1000, "ms", { sec: SEC, current: getNameFromHash() });
      timerRef.current = setTimeout(gotoNextFromHash, SEC * 1000);
    }

    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; } };
  }, [enabled, sec, playlist.length, loop, order, onlyIncidents, route?.name, route?.instance]);

  return null;
}
