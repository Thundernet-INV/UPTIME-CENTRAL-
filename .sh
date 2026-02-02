#!/usr/bin/env bash
set -euo pipefail

# Inserta/actualiza el proxy de Vite para /api → http://<host>:<port>
# Uso: ./patch_vite_proxy.sh 10.10.31.31 8080

HOST=${1:? "Falta host (ej: 10.10.31.31)"}
PORT=${2:? "Falta puerto (ej: 8080)"}
CFG="vite.config.js"

if [[ ! -f "$CFG" ]]; then
  echo "No se encontró $CFG en el directorio actual" >&2
  exit 1
fi

node - "$HOST" "$PORT" <<'JS'
const fs = require('fs');
const host = process.argv[2];
const port = process.argv[3];
let s = fs.readFileSync('vite.config.js', 'utf8');

if (!/export default defineConfig\(/.test(s)) {
  console.error('[ERROR] vite.config.js no parece ser un archivo de Vite válido');
  process.exit(1);
}

// Asegura bloque server
if (!/server:\s*\{[\s\S]*?\}/.test(s)) {
  s = s.replace(/export default defineConfig\(\{([\s\S]*?)plugins:\s*\[react\(\)\],?/,
`export default defineConfig({$1plugins: [react()],
  server: {
    host: '10.10.31.31',
    port: 5173,
    strictPort: true,
    proxy: {
      '/api': {
        target: 'http://${host}:${port}',
        changeOrigin: true,
      },
    },
  },`);
} else {
  // Actualiza/inyecta proxy dentro de server
  if (/proxy:\s*\{[\s\S]*?\}/.test(s)) {
    s = s.replace(/proxy:\s*\{[\s\S]*?\}/,
`proxy: {
      '/api': {
        target: 'http://${host}:${port}',
        changeOrigin: true,
      },
    }`);
  } else {
    s = s.replace(/server:\s*\{([\s\S]*?)\}/,
(match, inner) => `server: {${inner}
    proxy: {
      '/api': {
        target: 'http://${host}:${port}',
        changeOrigin: true,
      },
    }
  }`);
  }
  // Asegura host/port/strictPort
  s = s.replace(/server:\s*\{([\s\S]*?)\}/,
(match, inner) => {
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
console.log(`[vite] server.proxy '/api' → http://${host}:${port}`);
JS

echo "Listo. Reinicia Vite: npm run dev"
