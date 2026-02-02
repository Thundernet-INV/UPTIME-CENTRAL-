
#!/bin/sh
# Añade soporte de token + onAny (captura todos los eventos) al WS de Socket.IO
# Uso:
#   chmod +x ./patch_socket_debug.sh
#   ./patch_socket_debug.sh
#   # (opcional) token en .env: echo "VITE_WS_TOKEN=TU_TOKEN" >> .env
#   npm run dev

set -eu
TS=$(date +%Y%m%d%H%M%S)

if [ ! -f src/api.js ]; then
  echo "[ERROR] src/api.js no encontrado. Ejecuta en la carpeta del frontend." >&2
  exit 1
fi

cp src/api.js src/api.js.bak.$TS
awk '1' src/api.js > src/api.tmp.$TS

# 1) Inserta helpers: lectura de token y onAny logger justo después de 'const API ...'
sed -i "0,/^const API /s//const API = (typeof import.meta !== \"undefined\" && import.meta.env?.VITE_API_BASE) || \"\/\";\n\nconst WS_TOKEN = (typeof import.meta !== 'undefined' && import.meta.env?.VITE_WS_TOKEN) || (typeof localStorage !== 'undefined' ? localStorage.getItem('KUMA_WS_TOKEN') : null);\nconst onAnyLog = (socket, forward) => { if (!socket || !socket.onAny) return; socket.onAny((ev, ...args) => { const payload = (args && args.length ? args[0] : undefined); try { console.info('[kuma-ws:any]', ev, payload); } catch(e){} try { if (forward) forward(payload); } catch(e){} }); };/g" src/api.tmp.$TS

# 2) Reemplaza el constructor del socket para incluir token (auth+query) y withCredentials
python3 - <<'PY'
import re, glob
fn = sorted(glob.glob('src/api.tmp.*'))[-1]
s  = open(fn,'r',encoding='utf-8').read()
pat = re.compile(r"const\s+socket\s*=\s*io\((?:.|\n)*?\);", re.M)
rep = (
"const socket = io(base || undefined, {\n"
"      path: \"/socket.io\",\n"
"      transports: [\"websocket\"],\n"
"      withCredentials: true,\n"
"      auth: WS_TOKEN ? { token: WS_TOKEN } : undefined,\n"
"      query: WS_TOKEN ? { token: WS_TOKEN } : undefined,\n"
"    });"
)
open('src/api.js','w',encoding='utf-8').write(pat.sub(rep, s))
PY

# 3) Añade listeners de error, onAny (y emits opcionales de 'auth'/'subscribe')
python3 - <<'PY'
s = open('src/api.js','r',encoding='utf-8').read()
needle = 'socket.on("connect", () => log("WS conectado", socket.id));'
if needle in s:
    s = s.replace(
        needle,
        'socket.on("connect", () => log("WS conectado", socket.id));\n\n'
        '    // Logs de error + captura de cualquier evento y reenvío al onMessage\n'
        '    socket.on("connect_error", (e)=> warn("WS connect_error:", e && (e.message || e)));\n'
        '    socket.on("error", (e)=> warn("WS error:", e));\n'
        '    onAnyLog(socket, (payload)=>{ try { onMessage?.(payload); } catch(e){} });\n'
        '    // Si el backend exige handshake de auth/subscripción, lo intentamos (si hay token)\n'
        '    if (WS_TOKEN) {\n'
        '      try { socket.emit("auth", { token: WS_TOKEN }); } catch {}\n'
        '      try { socket.emit("subscribe", { token: WS_TOKEN }); } catch {}\n'
        '    }'
    )
open('src/api.js','w',encoding='utf-8').write(s)
PY

mv src/api.tmp.$TS /tmp/src_api_$TS.tmp 2>/dev/null || true
echo "[ok] src/api.js parcheado: token + onAny (reenvía al onMessage)."
echo "Sugerencia: persiste token con:  echo 'VITE_WS_TOKEN=TU_TOKEN' >> .env"

