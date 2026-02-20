// src/components/AutoPlayer.jsx (versión mejorada con más logs)
import React, { useEffect, useMemo, useRef } from "react";

export default function AutoPlayer({
  enabled = false,
  sec = 10,
  order = "downFirst",
  onlyIncidents = false,
  loop = true,
  filteredAll = [],
  route,
  openInstance
}) {
  const idxRef = useRef(0);
  const timerRef = useRef(null);

  // Estadísticas por instancia
  const instanceStats = useMemo(() => {
    const map = new Map();
    for (const m of filteredAll) {
      const it = map.get(m.instance) || { up: 0, down: 0, total: 0 };
      if (m.latest?.status === 1) it.up++;
      else if (m.latest?.status === 0) it.down++;
      it.total++;
      map.set(m.instance, it);
    }
    return map;
  }, [filteredAll]);

  // Playlist ordenado
  const playlist = useMemo(() => {
    let arr = Array.from(instanceStats.keys());
    if (onlyIncidents) {
      arr = arr.filter(n => (instanceStats.get(n)?.down || 0) > 0);
    }
    if (order === "downFirst") {
      arr.sort((a, b) => 
        (instanceStats.get(b)?.down || 0) - (instanceStats.get(a)?.down || 0) || 
        a.localeCompare(b)
      );
    } else {
      arr.sort((a, b) => a.localeCompare(b));
    }
    return arr;
  }, [instanceStats, onlyIncidents, order]);

  const nameToIndex = useMemo(() => {
    const map = new Map();
    playlist.forEach((name, i) => map.set(String(name || '').toLowerCase(), i));
    return map;
  }, [playlist]);

  const getNameFromHash = () => {
    try {
      const parts = (window.location.hash || "").slice(1).split("/").filter(Boolean);
      if (parts[0] === "sede" && parts[1]) return decodeURIComponent(parts[1]);
    } catch {}
    return null;
  };

  const syncIndexWithName = (name) => {
    const key = String(name || '').toLowerCase();
    const i = nameToIndex.has(key) ? nameToIndex.get(key) : -1;
    if (i >= 0) idxRef.current = i;
    return i;
  };

  const getNextFromName = (currentName) => {
    const i = syncIndexWithName(currentName);
    let nextIdx = (i >= 0) ? (i + 1) : idxRef.current;
    if (nextIdx >= playlist.length) {
      if (!loop) return null;
      nextIdx = 0;
    }
    return playlist[nextIdx] || null;
  };

  useEffect(() => {
    if (idxRef.current >= playlist.length) idxRef.current = 0;
  }, [playlist.length]);

  // Logs para debugging
  useEffect(() => {
    if (enabled) {
      console.log(`[AutoPlayer] Playlist actual:`, {
        tamaño: playlist.length,
        orden: order,
        soloIncidencias: onlyIncidents,
        loop,
        instancias: playlist.slice(0, 5) // mostrar primeras 5
      });
    }
  }, [enabled, playlist, order, onlyIncidents, loop]);

  // Programación de saltos
  useEffect(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
    
    if (!enabled || !playlist.length || route.name === "energia") return;

    const SEC = Math.max(3, Number(sec) || 10);

    const gotoNext = () => {
      const current = getNameFromHash();
      let nextName;
      
      if (!current || current === "undefined") {
        // Estamos en home o ruta inválida
        nextName = playlist[idxRef.current];
        console.log(`[AutoPlayer] Desde HOME a: ${nextName}`);
      } else {
        nextName = getNextFromName(current);
        console.log(`[AutoPlayer] Desde ${current} a: ${nextName || "ninguna"}`);
      }
      
      if (!nextName) {
        if (!loop && idxRef.current >= playlist.length - 1) {
          console.log("[AutoPlayer] Fin del playlist, deteniendo");
          return;
        }
        return;
      }
      
      syncIndexWithName(nextName);
      console.log(`[AutoPlayer] Saltando a: ${nextName} en ${SEC}s`);
      
      if (typeof openInstance === "function") {
        openInstance(nextName);
      } else {
        window.location.hash = "/sede/" + encodeURIComponent(nextName);
      }
    };

    const delay = route.name === "home" ? 500 : SEC * 1000;
    console.log(`[AutoPlayer] Próximo salto en ${delay}ms`);
    timerRef.current = setTimeout(gotoNext, delay);

    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    };
  }, [enabled, sec, playlist, loop, order, onlyIncidents, route.name, openInstance]);

  return null;
}
