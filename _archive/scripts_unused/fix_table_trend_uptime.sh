#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
ID="$ROOT/src/components/InstanceDetail.jsx"

echo "== Backup =="
cp "$ID" "$ID.bak_table_$(date +%Y%m%d_%H%M%S)"

echo "== 1) Garantizar cabeceras: Servicio | Estado | Latencia | Tendencia | Uptime | Acciones =="
# Sustituye la fila de headers, sin tocar el resto
awk '
  BEGIN{done=0}
  {
    if(!done && /<thead>/){
      print
      getline; # debe ser <tr> (lo preservamos)
      print
      # Consumimos hasta </thead> y reescribimos las cabeceras
      while(getline line){
        if(line ~ /<\/thead>/){
          print "              <tr><th>Servicio<\\/th><th>Estado<\\/th><th>Latencia<\\/th><th>Tendencia<\\/th><th>Uptime<\\/th><th>Acciones<\\/th><\\/tr>"
          print line
          done=1
          break
        }
      }
    } else {
      print
    }
  }
' "$ID" > "$ID.tmp" && mv "$ID.tmp" "$ID"

echo "== 2) Añadir la celda Uptime y asegurar Sparkline en cada fila (tabla) =="
# En el map() de filas, añadimos el cálculo del uptime y la celda; y reforzamos el Sparkline
perl -0777 -pe '
  # 2.1. Garantizar que la constante name esté presente (ya suele estar)
  s/const name = m\.info\?\.(monitor_name|monitor_name \|\| "")[^;]*;/const name = m.info?.monitor_name || "";/g;

  # 2.2. En el <td> de Tendencia, forzamos un Sparkline con ancho razonable
  s#<td style=\{\{minWidth:120\}\}><Sparkline[^>]*></td>#<td style={{minWidth:140}}><Sparkline points={seriesMon} width={140} height={28} color={st==="UP" ? "#16a34a" : "#dc2626"} /></td>#g;

  # 2.3. Insertar la celda de Uptime justo después de Tendencia
  # Buscamos el cierre del <td> de Tendencia y, si no existe Uptime, lo añadimos
' -i "$ID"

# Si todavía no existe la celda de Uptime en las filas, la insertamos después del Sparkline
grep -q '<th>Uptime</th>' "$ID" && \
! grep -q '>Uptime</td>' "$ID" && \
awk '
  BEGIN{inserted=0}
  {
    print
    if(!inserted && /<td style=\{\{minWidth:140\}\}><Sparkline.*<\/td>/){
      print "                    {(() => {"
      print "                      // Cálculo de uptime % con las muestras disponibles"
      print "                      const stSamples = (seriesMon || []).filter(p => typeof p?.status === \"number\");"
      print "                      let up = null;"
      print "                      if (stSamples.length >= 2) {"
      print "                        const ups = stSamples.filter(p => p.status === 1).length;"
      print "                        up = Math.round((ups / stSamples.length) * 100);"
      print "                      }"
      print "                      return <td>{up != null ? (up + \"%\") : \"—\"}</td>;"
      print "                    })()}"
      inserted=1
    }
  }
' "$ID" > "$ID.tmp" && mv "$ID.tmp" "$ID"

echo "== 3) Si la celda de Tendencia original tenía minWidth 120, actualizarla a 140 (consistencia) =="
sed -i 's/minWidth:120/minWidth:140/g' "$ID"

echo "== 4) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Hecho: TABLA con Tendencia (sparkline) y Uptime %. Grilla se mantiene igual."
