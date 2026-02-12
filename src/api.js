// src/api.js - VERSIÓN CORREGIDA
const API_BASE = 'http://10.10.31.31:8080/api';

export async function fetchAll() {
  try {
    const url = `${API_BASE}/summary?t=${Date.now()}`;
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (error) {
    console.error('[API] Error en fetchAll:', error);
    return { instances: [], monitors: [] };
  }
}

export async function getBlocklist() {
  try {
    const url = `${API_BASE}/blocklist?t=${Date.now()}`;
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) {
      if (res.status === 404) {
        console.log('[API] Blocklist no implementada (404) - usando array vacío');
        return { monitors: [] };
      }
      return null;
    }
    return await res.json().catch(() => ({ monitors: [] }));
  } catch (error) {
    console.error('[API] Error en getBlocklist:', error);
    return { monitors: [] };
  }
}

export async function saveBlocklist(payload) {
  try {
    const url = `${API_BASE}/blocklist`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok && res.status === 404) {
      console.log('[API] Blocklist no implementada (404)');
      return { success: false, message: 'Not implemented' };
    }
    return await res.json().catch(() => ({ success: false }));
  } catch (error) {
    console.error('[API] Error en saveBlocklist:', error);
    return { success: false };
  }
}
