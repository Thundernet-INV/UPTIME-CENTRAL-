// src/api.js
const API_BASE = 'http://10.10.31.31:8080/api';

export async function fetchAll() {
  const url = `${API_BASE}/summary?t=${Date.now()}`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

export async function getBlocklist() {
  const url = `${API_BASE}/blocklist?t=${Date.now()}`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) return null;
  return res.json().catch(() => null);
}

export async function saveBlocklist(payload) {
  const url = `${API_BASE}/blocklist`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return res.json().catch(() => null);
}
