// src/api.js

// === UPTIME-CENTRAL: Configuración de base de API ===
// Si existe VITE_API_BASE_URL, úsala.
// Si no, usamos "/api" para trabajar con proxy (Vite en dev, Nginx en prod).
const API_BASE =
  (typeof import.meta !== "undefined" &&
    import.meta.env &&
    import.meta.env.VITE_API_BASE_URL)
    ? import.meta.env.VITE_API_BASE_URL
    : "/api";

// --- Summary principal (dashboard) ---
export async function fetchAll() {
  const url = `${API_BASE}/summary?t=${Date.now()}`;
  const res = await fetch(url, {
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

// --- Blocklist: obtener ---
export async function getBlocklist() {
  const url = `${API_BASE}/blocklist?t=${Date.now()}`;
  const res = await fetch(url, {
    cache: "no-store",
  });
  if (!res.ok) return null;
  return res.json().catch(() => null);
}

// --- Blocklist: guardar ---
export async function saveBlocklist(payload) {
  const url = `${API_BASE}/blocklist`;
  const res = await fetch(url, {
    method: "POST",
    body: JSON.stringify(payload),
  });
  return res.json().catch(() => null);
}
