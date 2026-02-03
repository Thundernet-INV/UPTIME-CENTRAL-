
#!/usr/bin/env bash
set -euo pipefail

# =========================
#  Uptime Kuma - Health Check
# =========================
# Revisa:
#  - Aggregator (systemd + API + SSE)
#  - Nginx proxy /api
#  - instances.json y /metrics por sede
#  - blocklist
#  - Frontend en /var/www/kuma-dashboard
#
# Uso:
#   sudo bash check-kuma-env.sh [opciones]
#
# Opciones:
#   --docroot PATH           Docroot de Nginx (default: /var/www/kuma-dashboard)
#   --agg-host HOST          Host del agregador (default: 127.0.0.1)
#   --agg-port PORT          Puerto del agregador (default: 8080)
#   --instances PATH         Ruta del instances.json (default: /opt/kuma-central/kuma-aggregator/instances.json)
#   --blocklist PATH         Ruta del blocklist.json (default: /opt/kuma-central/kuma-aggregator/blocklist.json)
#   --clear-blocklist        Vacía el blocklist (peligro: reexpone todos los monitores)
#   --sse-sample             Lee 1 evento SSE (máx 5s) para verificar ‘tick’
#   --nginx-site PATH        Vhost Nginx (default: /etc/nginx/sites-available/kuma-dashboard)
#
# Salidas: PASSED/FAILED por sección y acciones sugeridas.

# ---------- Config ----------
DOCROOT="/var/www/kuma-dashboard"
AGG_HOST="127.0.0.1"
AGG_PORT="8080"
INSTANCES="/opt/kuma-central/kuma-aggregator/instances.json"
BLOCKLIST="/opt/kuma-central/kuma-aggregator/blocklist.json"
SITE_A="/etc/nginx/sites-available/kuma-dashboard"
DO_CLEAR_BL="no"
DO_SSE_SAMPLE="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docroot) DOCROOT="${2}"; shift 2 ;;
    --agg-host) AGG_HOST="${2}"; shift 2 ;;
    --agg-port) AGG_PORT="${2}"; shift 2 ;;
    --instances) INSTANCES="${2}"; shift 2 ;;
    --blocklist) BLOCKLIST="${2}"; shift 2 ;;
    --clear-blocklist) DO_CLEAR_BL="yes"; shift ;;
    --sse-sample) DO_SSE_SAMPLE="yes"; shift ;;
    --nginx-site) SITE_A="${2}"; shift 2 ;;
    *) echo "Opción no reconocida: $1"; exit 2 ;;
  esac
done

# ---------- Estética ----------
RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; CYA=$'\e[36m'; BLD=$'\e[1m'; CLR=$'\e[0m'
pass(){ echo -e "${GRN}[PASSED]${CLR} $*"; }
fail(){ echo -e "${RED}[FAILED]${CLR} $*"; }
warn(){ echo -e "${YLW}[WARN]${CLR} $*"; }
info(){ echo -e "${CYA}[INFO]${CLR} $*"; }

has_cmd(){ command -v "$1" >/dev/null 2>&1; }

JSON_PRETTY(){
  if has_cmd jq; then jq .; else python3 - <<'PY'
import sys, json
print(json.dumps(json.load(sys.stdin), indent=2, ensure_ascii=False))
PY
  fi
}

JSON_LEN(){
  if has_cmd jq; then jq 'length'; else python3 - <<'PY'
import sys, json
print(len(json.load(sys.stdin)))
PY
  fi
}

# ---------- 0) Dependencias ----------
info "Checando dependencias…"
for c in curl; do
  if ! has_cmd "$c"; then fail "No encontrado: $c"; exit 1; fi
done
has_cmd jq || warn "jq no instalado: salidas JSON serán en texto plano."

# ---------- 1) Aggregator (systemd) ----------
info "Verificando servicio systemd del agregador (kuma-aggregator)…"
if systemctl is-active --quiet kuma-aggregator; then
  pass "kuma-aggregator: activo"
else
  fail "kuma-aggregator NO está activo"; systemctl --no-pager --full status kuma-aggregator || true
fi

# ---------- 2) Aggregator API ----------
AGG_BASE="http://${AGG_HOST}:${AGG_PORT}"
info "Llamando al Aggregator API en ${AGG_BASE}…"
SUM_RAW="$(curl -sS -m 5 "${AGG_BASE}/api/summary" || true)"
MON_RAW="$(curl -sS -m 8 "${AGG_BASE}/api/monitors" || true)"

if [[ -n "$SUM_RAW" ]]; then
  SUM_LEN=${#SUM_RAW}
  pass "summary respondió (${SUM_LEN} bytes)"
else
  fail "summary NO respondió"; 
fi

if [[ -n "$MON_RAW" ]]; then
  MON_LEN=${#MON_RAW}
  echo "$MON_RAW" | JSON_LEN 2>/dev/null || true
  pass "monitors respondió (${MON_LEN} bytes)"
else
  fail "monitors NO respondió"
fi

if [[ "$DO_SSE_SAMPLE" == "yes" ]]; then
  info "Probando SSE (5s máx)…"
  if curl -sS -m 5 --no-buffer "${AGG_BASE}/api/stream" | head -n 4 | grep -q "event: tick"; then
    pass "SSE emite eventos tick"
  else
    fail "SSE no mostró evento tick en 5s"
  fi
fi

# ---------- 3) Nginx proxy /api ----------
info "Verificando Nginx proxy /api → ${AGG_BASE}/api/"
if [[ -f "$SITE_A" ]]; then
  if grep -q "location /api/" "$SITE_A" && grep -q "proxy_pass http://${AGG_HOST}:${AGG_PORT}/api/" "$SITE_A"; then
    pass "Vhost ${SITE_A} tiene bloque /api esperado"
  else
    warn "Revisar ${SITE_A}: bloque /api no coincide con ${AGG_BASE}/api/"
  fi
else
  warn "No existe vhost en ${SITE_A}"
fi

NGX_SUM="$(curl -sS -m 5 "http://localhost/api/summary" || true)"
if [[ -n "$NGX_SUM" ]]; then
  pass "Nginx /api/summary respondió (${#NGX_SUM} bytes)"
else
  fail "Nginx /api/summary NO respondió"
fi

# ---------- 4) instances.json + prueba /metrics por sede ----------
if [[ -f "$INSTANCES" ]]; then
  info "Leyendo sedes de ${INSTANCES}…"
  if has_cmd jq; then
    COUNT="$(jq 'length' "$INSTANCES")"
    echo "Total sedes declaradas: ${COUNT}"
    jq -r '.[] | "\(.name) \(.baseUrl)"' "$INSTANCES" || true
  else
    python3 - <<PY
import json; d=json.load(open("${INSTANCES}")); print("Total sedes:",len(d))
print("\n".join([f'{x.get("name")} {x.get("baseUrl")}' for x in d]))
PY
  fi

  info "Probando /metrics de cada sede (timeout 8s)…"
  if has_cmd jq; then
    mapfile -t LINES < <(jq -r '.[] | @base64' "$INSTANCES")
    for row in "${LINES[@]}"; do
      name="$(echo "$row" | base64 -d | jq -r '.name')"
      base="$(echo "$row" | base64 -d | jq -r '.baseUrl')"
      key="$(echo "$row" | base64 -d | jq -r '.apiKey')"
      printf "%s" "[${name}] "
      OUT="$(curl -sS -m 8 -u x:"$key" -w ' HTTP:%{http_code} TIME:%{time_total}' "${base}/metrics" | head -n 3 || true)"
      echo "$OUT" | head -n 1
    done
  else
    python3 - <<'PY'
import json, subprocess, shlex
d=json.load(open("${INSTANCES}"))
for x in d:
  name=x.get("name"); base=x.get("baseUrl"); key=x.get("apiKey")
  print(f"[{name}] ", end="")
  try:
    cmd=f'curl -sS -m 8 -u x:{shlex.quote(key)} -w " HTTP:%{{http_code}} TIME:%{{time_total}}" {shlex.quote(base)}/metrics'
    out=subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
    print(out.splitlines()[0])
  except subprocess.CalledProcessError as e:
    print("ERROR:", e.output.strip())
PY
  fi
else
  fail "No existe ${INSTANCES}. Agrega tus sedes y API keys."
fi

# ---------- 5) Blocklist ----------
if [[ -f "$BLOCKLIST" ]]; then
  info "Revisando blocklist (${BLOCKLIST})…"
  BL_COUNT="$( (has_cmd jq && jq '.monitors|length' "$BLOCKLIST") || (python3 - <<'PY'
import json; 
import sys
try:
  d=json.load(open(sys.argv[1])); 
  print(len(d.get("monitors",[])))
except Exception: 
  print(0)
PY "$BLOCKLIST") )"
  echo "Monitores ocultos: ${BL_COUNT}"
  if [[ "$DO_CLEAR_BL" == "yes" ]]; then
    info "Vaciando blocklist…"
    echo '{"monitors":[]}' | tee "$BLOCKLIST" >/dev/null
    systemctl restart kuma-aggregator
    pass "Blocklist vaciado y agregador reiniciado"
  fi
else
  warn "No existe ${BLOCKLIST} (se creará cuando ocultes algo)."
fi

# ---------- 6) Frontend en docroot ----------
info "Revisando frontend en ${DOCROOT}…"
if [[ -f "${DOCROOT}/index.html" ]]; then
  if grep -q '/assets/ 0  
3) **Nginx /api/summary** → bytes > 0 (ideal, mismo JSON que el agregador directo)  
4) **Docroot** → `index.html` referencia `/assets/` y hay **assets** (JS/CSS)  
5) **Instances** → declarado y probadas las sedes (`/metrics` HTTP:200 y primeras líneas)  
6) **Blocklist** → 0 (o ejecútalo con `--clear-blocklist`)

---

