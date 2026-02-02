#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
ID="$ROOT/src/components/InstanceDetail.jsx"

echo "== Backup =="
cp "$ID" "$ID.bak_trend_uptime_$(date +%Y%m%d_%H%M%S)"

# 1) Garantizar cabeceras completas
awk '
  BEGIN{inHead=0; printed=0}
  {
    if ($0 ~ /<thead>/) { inHead=1; print; next }
    if (inHead) {
      if ($0 ~ /<\/thead>/) {
        print "            <tr><th>Servicio</th><th>Estado</th><th>Latencia</th><th>Tendencia</th><th>Uptime</th><th>Acciones</th></tr>"
        print
        inHead=0; printed=1; next
      } else {
        # saltamos lo que haya dentro para reescribir cabeceras limpias
        next
      }
    }
    print
  }
' "$ID" > "$ID.tmp" && mv "$ID.tmp" "$ID"

# 2) Asegurar minWidth de la celda de tendencia a 140
sed -i 's/minWidth:120/minWidth:140/g' "$ID"

# 3) Asegurar que el Sparkline esté en esa celda (no tocamos props si ya existen)
#    (no usamos perl con comillas complicadas, sólo reforzamos el minWidth que ya hicimos)

# 4) Insertar la celda Uptime justo DESPUÉS de la celda tendencia (sparkline)
#    Buscamos la línea que cierra la celda de tendencia y añadimos una <td> con el cálculo de uptime
awk '
  BEGIN{added=0}
  {
    print
    # Detecta cierre de la celda tendencia (Sparkline) en tabla:
    if ($0 ~ /<td[^>]*>.*Sparkline.*<\/td>/ && added==0) {
      print "                    {(() => {"
      print "                      const stSamples = (seriesMon || []).filter(p => typeof p?.status === \"number\");"
      print "                      let up = null;"
      print "                      if (stSamples.length >= 2) {"
      print "                        const ups = stSamples.filter(p => p.status === 1).length;"
      print "                        up = Math.round((ups / stSamples.length) * 100);"
      print "                      }"
      print "                      return <td>{up != null ? (up + \"%\") : \"—\"}</td>;"
      print "                    })()}"
      added=1
    }
  }
' "$ID" > "$ID.tmp" && mv "$ID.tmp" "$ID"

# 5) Compilar y desplegar
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ TABLA: Tendencia + Uptime activados. Grilla permanece igual."
