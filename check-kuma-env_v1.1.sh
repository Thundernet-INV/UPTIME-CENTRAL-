#!/usr/bin/env bash
set -euo pipefail

# =========================
#  Uptime Kuma - Health Check (v1.1)
# =========================

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
  pass "summary respondió (${#SUM_RAW} bytes)"
else
  fail "summary NO respondió"
fi

if [[ -n "$MON_RAW" ]]; then
  pass "monitors respondió (${#MON_RAW} bytes)"
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
    INSTANCES_PATH="$INSTANCES" python3 - <<'PY'
import json, os
p=os.environ["INSTANCES_PATH"]
d=json.load(open(p))
print("Total sedes:",len(d))
for x in d:
  print(x.get("name"), x.get("baseUrl"))
PY
  fi

  info "Probando /metrics de cada sede (timeout 8s)…"
  if has_cmd jq; then
    mapfile -t LINES < <(jq -r '.[] | @base64' "$INSTANCES")
    for row in "${LINES[@]}"; do
      name="$(echo "$row" | base64 -d | jq -r '.name')"
      base="$(echo "$row" | base64 -d | jq -r '.baseUrl')"
      key="$(echo "$row" | base64 -d | jq -r '.apiKey')"
      printf "%s " "[$name]"
      curl -sS -m 8 -u x:"$key" -w 'HTTP:%{http_code} TIME:%{time_total}\n' "${base}/metrics" | head -n 1
    done
  else
    INSTANCES_PATH="$INSTANCES" python3 - <<'PY'
import json, os, subprocess, shlex
p=os.environ["INSTANCES_PATH"]
d=json.load(open(p))
for x in d:
  name=x.get("name"); base=x.get("baseUrl"); key=x.get("apiKey")
  print(f"[{name}] ", end="")
  try:
    cmd=f'curl -sS -m 8 -u x:{shlex.quote(key)} -w "HTTP:%{{http_code}} TIME:%{{time_total}}\\n" {shlex.quote(base)}/metrics'
    out=subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
    print(out.splitlines()[0])
  except subprocess.CalledProcessError as e:
    print("ERROR:", e.output.splitlines()[0] if e.output else "ERROR")
PY
  fi
else
  fail "No existe ${INSTANCES}. Agrega tus sedes y API keys."
fi

# ---------- 5) Blocklist ----------
if [[ -f "$BLOCKLIST" ]]; then
  info "Revisando blocklist (${BLOCKLIST})…"
  if has_cmd jq; then
    BL_COUNT="$(jq '.monitors|length' "$BLOCKLIST" 2>/dev/null || echo 0)"
  else
    BLOCKLIST_PATH="$BLOCKLIST" python3 - <<'PY'
import json, os
try:
  p=os.environ["BLOCKLIST_PATH"]; d=json.load(open(p)); print(len(d.get("monitors",[])))
except Exception: print(0)
PY
    BL_COUNT="$(tail -n1 <<<"$BL_COUNT")"
  fi
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
  if grep -q '/assets/ 0 ✅  
- **instances.json** → cuántas sedes reconocidas  
- **/metrics por sede** → `HTTP:200` en las que están OK (si alguna da `timeout`, como Tucacas, allí está el cuello)  
- **blocklist** → si tiene items (y luego puedes vaciarlo)

---

## 🎯 Acciones inmediatas (si la UI sigue en 0)

1) **Rellena** `instances.json` con **todas** tus sedes **reales** (IP:3001 y API keys completas).  
   ```bash
   sudo nano /opt/kuma-central/kuma-aggregator/instances.json
   sudo systemctl restart kuma-aggregator
 

Prueba  /metrics  de una sede que funcione (con su API key):
 
curl -sS -u x:'uk1_TU_API_KEY' http://<IP-SEDE>:3001/metrics | head
 

Vacía blocklist (si ocultaste todo sin querer):
 
echo '{"monitors":[]}' | sudo tee /opt/kuma-central/kuma-aggregator/blocklist.json >/dev/null
sudo systemctl restart kuma-aggregator
