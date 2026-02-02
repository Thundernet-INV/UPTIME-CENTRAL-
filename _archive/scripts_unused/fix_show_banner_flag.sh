#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

echo "== Backup =="
cp "$APP" "$APP.bak_showbanner_$(date +%Y%m%d_%H%M%S)"

echo "== 1) Eliminar TODAS las declaraciones duplicadas de SHOW_BANNER =="
# Borra cualquier línea que declare la constante, esté donde esté
sed -i '/^\s*const\s\+SHOW_BANNER\s*=\s*.*;.*$/d' "$APP"

echo "== 2) Insertar UNA sola declaración, después del último import =="
# Detecta la última línea 'import ...' y añade el flag justo después
awk '
  BEGIN{lastImport=0; n=0}
  { n++; print; if ($0 ~ /^import /) lastImport=n }
  END{
    # Volvemos a imprimir el archivo pero insertando tras la última import
  }
' "$APP" > "$APP.__tmp1"

# Creamos archivo final con la constante insertada tras la última import real
awk '
  BEGIN{lastImport=0; n=0}
  /^import /{ lastImport=NR }
  { lines[NR]=$0; n=NR }
  END{
    for(i=1;i<=n;i++){
      print lines[i]
      if(i==lastImport){
        print "const SHOW_BANNER = false; // Oculta el banner superior de alertas"
      }
    }
  }
' "$APP.__tmp1" > "$APP.__tmp2" && mv "$APP.__tmp2" "$APP"

rm -f "$APP.__tmp1"

echo "== 3) Envolver el render de AlertsBanner una sola vez con el flag =="
# Normalizamos a una sola forma: {SHOW_BANNER && (<AlertsBanner ... />)}
# 3.1 Primero, reemplaza cualquier wrapper previo por un marcador único
sed -i 's/{SHOW_BANNER\s*&&\s*(<AlertsBanner[^}]*>[^}]*<\/AlertsBanner>)}/__ALERT_BANNER_MARKER__/g' "$APP"
sed -i 's/{SHOW_BANNER\s*&&\s*(<AlertsBanner[^}]*\/>)}/__ALERT_BANNER_MARKER__/g' "$APP"

# 3.2 Después, marca todas las ocurrencias "planas" de AlertsBanner
#     (las convertiremos a marcador también para consolidar a una sola)
awk '
  BEGIN{ }
  {
    line=$0
    # Si hay AlertsBanner auto-cerrado:
    if (line ~ /<AlertsBanner[^>]*\/>/) {
      gsub(/<AlertsBanner[^>]*\/>/, "__ALERT_BANNER_MARKER__", line)
      print line
      next
    }
    # Si hay AlertsBanner con apertura/cierre en la misma línea (raro en tu código, pero por si acaso)
    if (line ~ /<AlertsBanner[^>]*>.*<\/AlertsBanner>/) {
      gsub(/<AlertsBanner[^>]*>.*<\/AlertsBanner>/, "__ALERT_BANNER_MARKER__", line)
      print line
      next
    }
    print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 3.3 Mantener SOLO un marcador (la primera ocurrencia), eliminando los demás
FIRST=1
awk '
  BEGIN{first=1}
  {
    if ($0 ~ /__ALERT_BANNER_MARKER__/) {
      if (first==1) { print; first=0 } else { next }
    } else {
      print
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 3.4 Sustituir el marcador por el wrapper correcto con el flag
sed -i 's#__ALERT_BANNER_MARKER__#{SHOW_BANNER && (<AlertsBanner alerts={alerts} onClose={(id)=>setAlerts(a=>a.filter(x=>x.id!==id))} autoCloseMs={ALERT_AUTOCLOSE_MS} />)}#' "$APP"

echo "== 4) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Arreglado: 1 sola constante SHOW_BANNER y 1 solo wrapper; banner ocultable."
