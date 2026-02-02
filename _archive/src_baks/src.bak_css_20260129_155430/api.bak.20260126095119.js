const API = (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE) || "/";

async function fetchJSON(path, init = {}) {
  const res = await fetch(API + path, {
    headers: { "Accept": "application/json", ...(init.headers || {}) },
    ...init,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} ${res.statusText} - ${text}`);
  }
  return res.json();
}

export async function fetchSummary() {
  return fetchJSON("api/summary");
}

export async function fetchMonitors() {
  return fetchJSON("api/monitors");
}

/**
 * Abre un SSE con auto-reconexión (retryMs base).
 * onMessage(payload) se llama cuando llega el evento "tick".
 * Devuelve una función close() para cerrar definitivamente.
 */
export function openStream(onMessage, { retryMs = 2000, maxRetryMs = 15000 } = {}) {
  let es;
  let stopped = false;
  let currRetry = retryMs;

  const start = () => {
    es = new EventSource(API + "api/stream");
    es.addEventListener("tick", (e) => {
      try {
        const payload = JSON.parse(e.data);
        onMessage?.(payload);
        currRetry = retryMs; // éxito ⇒ resetea backoff
      } catch {
        // ignora payload inválido
      }
    });
    es.onerror = () => {
      es?.close?.();
      if (!stopped) {
        const wait = currRetry;
        currRetry = Math.min(currRetry * 2, maxRetryMs);
        setTimeout(start, wait);
      }
    };
  };

  start();
  return () => {
    stopped = true;
    es?.close?.();
  };
}

export async function getBlocklist() {
  return fetchJSON("api/blocklist");
}

export async function saveBlocklist(b) {
  return fetchJSON("api/blocklist", {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(b),
  });
}
