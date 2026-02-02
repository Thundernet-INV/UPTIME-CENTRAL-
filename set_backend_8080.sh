#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Configura el frontend para que:
#  - Opción A: Vite proxy /api y /stream -> http://10.10.31.31:8080
#  - Opción B: Usar VITE_API_BASE=http://10.10.31.31:8080/ (sin proxy)
# Además, asegura que EventSource use correctamente el base (API) en api.js
# Uso:
#   chmod +x ./set_backend_8080.sh
#   ./set_backend_8080.sh
#   npm run dev
# ------------------------------------------------------------

FRONT_ROOT="$(pwd)"
if [[ ! -f "${FRONT_ROOT}/package.json" ]]; then
  echo "[ERROR] Ejecuta este script en la carpeta del frontend (donde está package.json)." >&2
  exit 1
fi

read -r -p $'\n¿Quieres usar proxy de Vite hacia 8080 (A) o VITE_API_BASE directo (B)? [A/B]: ' MODE
MODE="${MODE^^}"
if [[ "${MODE}" != "A" && "${MODE}" != "B" ]]; then
  echo "Opción inválida. Responde A o B."
  exit 1
fi

ts="$(date +%Y%m%d%H%M%S)"

# 1) Ajustar vite.config.js según el modo
if [[ -f vite.config.js ]]; then
  cp vite.config.js "vite.config.js.bak.${ts}"
  echo "[backup] vite.config.js -> vite.config.js.bak.${ts}"
else
  echo "[WARN] No hay vite.config.js. (¿Usas vite.config.ts? Si sí, avísame y lo adapto.)"
fi

if [[ "${MODE}" == "A" ]]; then
  # Proxy hacia :8080
  node - <<'JS'
const fs = require('fs');
if (!fs.existsSync('vite.config.js')) process.exit(0);
let s = fs.readFileSync('vite.config.js','utf8');
if (!/export default defineConfig\(/.test(s)) {
  console.error('[ERROR] vite.config.js no parece válido'); process.exit(1);
}
if (!/server:\s*\{[\s\S]*?\}/.test(s)) {
  s = s.replace(/export default defineConfig\(\{([\s\S]*?)plugins:\s*\[react\(\)\],?/,
`export default defineConfig({$1plugins: [react()],
  server: {
    host: '10.10.31.31',
    port: 5173,
    strictPort: true,
    proxy: {
      '/api': { target: 'http://10.10.31.31:8080', changeOrigin: true },
      '/stream': { target: 'http://10.10.31.31:8080', changeOrigin: true },
    },
  },`);
} else {
  // inyectar/actualizar proxy
  if (/proxy:\s*\{[\s\S]*?\}/.test(s)) {
    s = s.replace(/proxy:\s*\{[\s\S]*?\}/,
`proxy: {
      '/api': { target: 'http://10.10.31.31:8080', changeOrigin: true },
      '/stream': { target: 'http://10.10.31.31:8080', changeOrigin: true },
    }`);
  } else {
    s = s.replace(/server:\s*\{([\s\S]*?)\}/, (m, inner) =>
`server: {${inner}
    proxy: {
      '/api': { target: 'http://10.10.31.31:8080', changeOrigin: true },
      '/stream': { target: 'http://10.10.31.31:8080', changeOrigin: true },
    }
  }`);
  }
  // normaliza host/port/strictPort
  s = s.replace(/server:\s*\{([\s\S]*?)\}/, (m, inner) => {
    let x = inner;
    if (!/host:/.test(x)) x = `host: '10.10.31.31',\n` + x;
    x = x.replace(/host:\s*['"][^'"]*['"]/g, `host: '10.10.31.31'`);
    if (!/port:/.test(x)) x = x.replace(/\{/, `{\n    port: 5173,`);
    x = x.replace(/port:\s*\d+/g, 'port: 5173');
    if (!/strictPort:/.test(x)) x = x + `\n    strictPort: true,`;
    return `server: {${x}}`;
  });
}
fs.writeFileSync('vite.config.js', s);
console.log('[ok] vite.config.js: proxy /api y /stream -> http://10.10.31.31:8080');
JS
else
  # 2) Escribir/actualizar .env con la base directa
  if [[ -f .env ]]; then
    cp .env ".env.bak.${ts}"
    echo "[backup] .env -> .env.bak.${ts}"
  fi
  # escribe VITE_API_BASE (sobrescribe o añade)
  awk 'BEGIN{found=0} /^VITE_API_BASE=/{print "VITE_API_BASE=http://10.10.31.31:8080/"; found=1; next} {print} END{if(!found) print "VITE_API_BASE=http://10.10.31.31:8080/"}' .env 2>/dev/null > .env.tmp || echo "VITE_API_BASE=http://10.10.31.31:8080/" > .env.tmp
  mv .env.tmp .env
  echo "[ok] .env: VITE_API_BASE=http://10.10.31.31:8080/"
fi

# 3) Asegurar que EventSource use correctamente la base (API) y no fuerce relativo
if [[ -f src/api.js ]]; then
  cp src/api.js "src/api.js.bak.${ts}"
  echo "[backup] src/api.js -> src/api.js.bak.${ts}"

  node - <<'JS'
const fs = require('fs');
const f = 'src/api.js';
if (!fs.existsSync(f)) process.exit(0);
let s = fs.readFileSync(f,'utf8');

// A) Priorizar /stream
s = s.replace(/const\s+PATHS\s*=\s*\[[^\]]*\]/m, 'const PATHS = ["/stream", "/api/stream", "/api/sse", "/events"]');

// B) Si construye EventSource con API + path, ya está OK. Si no, lo forzamos:
if (/new\s+EventSource\(\s*API\s*\+\s*path\s*\)/.test(s) === false) {
  // Cambia new EventSource(path) -> new EventSource(API + path)
  s = s.replace(/new\s+EventSource\(\s*path\s*\)/g, 'new EventSource(API + path)');
}

// C) fetchJSON ya usa API + path; nos aseguramos que no haya URLs absolutas hardcodeadas
// (no tocamos si el usuario tiene algo específico)

fs.writeFileSync(f, s);
console.log('[ok] src/api.js: PATHS con /stream primero y EventSource(API + path)');
JS
else
  echo "[WARN] No se encontró src/api.js; omito ajuste de SSE."
fi

echo -e "\n✅ Hecho."
if [[ "${MODE}" == "A" ]]; then
  echo "Modo A (PROXY): ejecuta ahora -> npm run dev"
  echo "En Network verás 5173, pero Vite reenvía a 10.10.31.31:8080 internamente."
else
  echo "Modo B (BASE DIRECTA): ejecuta ahora -> npm run dev"
  echo "Las peticiones irán directo a 10.10.31.31:8080 (requiere CORS habilitado en backend)."
fi
