export async function fetchAll() {
  const url = `/api/summary?t=${Date.now()}`;
  const res = await fetch(url, {
    cache: 'no-store',
    headers: {
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      'Pragma': 'no-cache'
    }
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

// (Opcional) blocklist endpoints – también sin caché
export async function getBlocklist() {
  const res = await fetch(`/api/blocklist?t=${Date.now()}`, { cache:'no-store', headers: {'Cache-Control':'no-store'} });
  if (!res.ok) return null;
  return res.json().catch(()=>null);
}
export async function saveBlocklist(payload) {
  const res = await fetch(`/api/blocklist`, {
    method:'POST',
    headers:{'Content-Type':'application/json','Cache-Control':'no-store'},
    body: JSON.stringify(payload)
  });
  return res.json().catch(()=>null);
}
