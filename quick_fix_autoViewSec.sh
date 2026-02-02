#!/bin/sh
set -eu
APP="/home/thunder/kuma-dashboard-clean/kuma-ui"
cd "$APP"

# 1) Backup
cp src/App.jsx src/App.jsx.bak.$(date +%Y%m%d%H%M%S)

# 2) Asegurar imports (solo si faltan)
grep -q 'AutoPlayControls' src/App.jsx || sed -i 's~import SLAAlerts from "./components/SLAAlerts.jsx";import SLAAlerts from "./components/SLAAlerts.jsx";\nimport AutoPlayControls from "./components/AutoPlayControls.jsx";\nimport AutoPlayer from "./components/AutoPlayer.jsx";' src/App.jsx

# 3) Inyectar todos los estados del playlist (incluye autoViewSec)
#    Se colocan justo al inicio del componente App()
awk '
  BEGIN{inserted=0}
  {
    print
    if (!inserted && $0 ~ /^export default function App$$$$ \{/) {
      print "  // === Playlist states (safe fix) ==="
      print "  const [autoRun, setAutoRun] = useState(typeof autoRun!==\"undefined\"?autoRun:false);"
      print "  const [autoIntervalSec, setAutoIntervalSec] = useState(typeof autoIntervalSec!==\"undefined\"?autoIntervalSec:10);"
      print "  const [autoOrder, setAutoOrder] = useState(typeof autoOrder!==\"undefined\"?autoOrder:\"downFirst\");"
      print "  const [autoOnlyIncidents, setAutoOnlyIncidents] = useState(typeof autoOnlyIncidents!==\"undefined\"?autoOnlyIncidents:false);"
      print "  const [autoLoop, setAutoLoop] = useState(typeof autoLoop!==\"undefined\"?autoLoop:true);"
      print "  const [autoViewSec, setAutoViewSec] = useState(typeof autoViewSec!==\"undefined\"?autoViewSec:10);"
      inserted=1
    }
  }
' src/App.jsx > src/App.jsx.tmp && mv src/App.jsx.tmp src/App.jsx

# 4) Garantizar que pasamos viewSec a los controles y al motor
# 4.1 Controls: agregar viewSec si falta
grep -q 'viewSec={autoViewSec}' src/App.jsx || \
sed -i 's/loop={autoLoop} setLoop={setAutoLoop}/loop={autoLoop} setLoop={setAutoLoop}\n          viewSec={autoViewSec} setViewSec={setAutoViewSec}/' src/App.jsx

# 4.2 AutoPlayer: agregar viewSec si falta (primera ocurrencia)
grep -q 'viewSec={autoViewSec}' src/App.jsx || \
sed -i '0,/<AutoPlayer/s/enabled={autoRun}/enabled={autoRun}\n        viewSec={autoViewSec}/' src/App.jsx

echo "OK: Estados e inyecciones corregidos. Compila con: npm run build"
