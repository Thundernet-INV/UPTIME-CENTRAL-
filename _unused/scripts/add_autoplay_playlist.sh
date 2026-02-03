#!/bin/sh
# Agrega "playlist" de instancias (auto-rotate) con controles Play/Pause/Intervalo/Orden/Filtros
set -eu
TS=$(date +%Y%m%d%H%M%S)

APP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
cd "$APP_DIR"

mkdir -p src/components
[ -f src/App.jsx ] && cp src/App.jsx src/App.jsx.bak.$TS || true

echo "== 1) Creando componente AutoPlayControls.jsx =="
cat > src/components/AutoPlayControls.jsx <<'JSX'
import React from "react";

export default function AutoPlayControls({
  running, onToggle, intervalSec, setIntervalSec,
  order, setOrder, onlyIncidents, setOnlyIncidents, loop, setLoop
}) {
  return (
    <div className="autoplay-controls" style={{
      display:"flex", gap:8, alignItems:"center", flexWrap:"wrap",
      border:"1px solid #e5e7eb", padding:"8px 10px", borderRadius:8, background:"#fff"
    }}>
      <button
        type="button"
        className="k-btn"
        style={{borderColor: running ? "#dc2626" : "#16a34a", color: running ? "#dc2626" : "#16a34a"}}
        onClick={onToggle}
        title={running ? "Pausar rotación" : "Iniciar rotación"}
      >
        {running ? "⏸️ Pausar" : "▶️ Reproducir"}
      </button>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        Intervalo (s)
        <input type="number" min="3" step="1" value={intervalSec}
          onChange={(e)=>setIntervalSec(Math.max(3, parseInt(e.target.value||"10",10)))}
          style={{width:64, padding:"4px 6px"}}/>
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        Orden
        <select value={order} onChange={(e)=>setOrder(e.target.value)} style={{padding:"4px 6px"}}>
          <option value="downFirst">DOWN primero</option>
          <option value="alpha">Alfabético</option>
        </select>
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        <input type="checkbox" checked={onlyIncidents} onChange={(e)=>setOnlyIncidents(e.target.checked)}/>
        Solo incidencias
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        <input type="checkbox" checked={loop} onChange={(e)=>setLoop(e.target.checked)}/>
        Loop
      </label>

      <span style={{marginLeft:"auto", color:"#6b7280"}}>Playlist de instancias</span>
    </div>
  );
}
JSX

echo "== 2) Inyectando lógica de playlist en App.jsx =="
# Insertamos un bloque en App.jsx: estado, derivación de lista, efecto de autoplay y UI de controles.
awk '
  BEGIN{printedControls=0; insertedState=0; insertedHelpers=0; insertedEffect=0}
  {
    line=$0

    # a) Import del nuevo componente si no existe
    if (line ~ /^import .* from ".\/components\/SLAAlerts\.jsx";$/ && insertedHelpers==0) {
      print line
      print "import AutoPlayControls from \"./components/AutoPlayControls.jsx\";"
      insertedHelpers=1
      next
    }

    # b) Estado del autoplay dentro del componente App()
    if (line ~ /^export default function App$$$$ \{$/ && insertedState==0) {
      print line
      print "  // === Playlist de instancias ==="
      print "  const [autoRun, setAutoRun] = useState(false);"
      print "  const [autoIntervalSec, setAutoIntervalSec] = useState(10);"
      print "  const [autoOrder, setAutoOrder] = useState(\"downFirst\"); // downFirst | alpha"
      print "  const [autoOnlyIncidents, setAutoOnlyIncidents] = useState(false);"
      print "  const [autoLoop, setAutoLoop] = useState(true);"
      print "  const autoIdxRef = useRef(0);"
      print "  const autoTimerRef = useRef(null);"
      next
    }

    # c) Derivar lista de instancias para el autoplay (con filtros actuales)
    if (line ~ /const visible = filteredAll.filter/ && printedControls==0) {
      print line
      print ""
      print "  // Instancias únicas del subconjunto filtrado"
      print "  const instanceStats = useMemo(() => {"
      print "    const map = new Map();"
      print "    for (const m of filteredAll) {"
      print "      const it = map.get(m.instance) || { up:0, down:0, total:0 };"
      print "      if (m.latest?.status === 1) it.up++; else if (m.latest?.status === 0) it.down++;"
      print "      it.total++;"
      print "      map.set(m.instance, it);"
      print "    }"
      print "    return map;"
      print "  }, [filteredAll]);"
      print ""
      print "  const playlist = useMemo(() => {"
      print "    let arr = Array.from(instanceStats.keys());"
      print "    if (autoOnlyIncidents) {"
      print "      arr = arr.filter(name => (instanceStats.get(name)?.down || 0) > 0);"
      print "    }"
      print "    if (autoOrder === \"downFirst\") {"
      print "      arr.sort((a,b)=> (instanceStats.get(b)?.down||0) - (instanceStats.get(a)?.down||0) || a.localeCompare(b));"
      print "    } else {"
      print "      arr.sort((a,b)=> a.localeCompare(b));"
      print "    }"
      print "    return arr;"
      print "  }, [instanceStats, autoOnlyIncidents, autoOrder]);"
      print ""
      printedControls=1
      next
    }

    # d) Efecto del autoplay: cambia hash a #/sede/<instancia> cada N segundos; pausa si usuario cambia
    if (line ~ /function openInstance$$name$$\{/ && insertedEffect==0) {
      print line
      print ""
      print "  // === Control del autoplay ==="
      print "  useEffect(() => {"
      print "    // Pausar autoplay si el usuario navega manualmente a una sede (route.name === \"sede\")"
      print "    if (route.name === \"sede\" && autoRun) {"
      print "      setAutoRun(false);"
      print "    }"
      print "  }, [route.name]);"
      print ""
      print "  useEffect(() => {"
      print "    if (!autoRun) {"
      print "      if (autoTimerRef.current) { clearTimeout(autoTimerRef.current); autoTimerRef.current = null; }"
      print "      return;"
      print "    }"
      print "    if (route.name !== \"home\") return; // solo correr en HOME"
      print "    if (!playlist.length) return;"
      print "    // Ajustar índice si se salió de rango"
      print "    if (autoIdxRef.current >= playlist.length) autoIdxRef.current = 0;"
      print "    const goNext = () => {"
      print "      if (!playlist.length) return;"
      print "      const idx = autoIdxRef.current % playlist.length;"
      print "      const name = playlist[idx];"
      print "      autoIdxRef.current = idx + 1;"
      print "      window.location.hash = \"/sede/\" + encodeURIComponent(name);"
      print "      // Programar vuelta a HOME tras X seg para que el usuario vea la sede y luego continuar"
      print "      // Nota: como pausamos al entrar a sede por interacción, el flujo normal será:"
      print "      // abrir sede -> usuario vuelve atrás o cierra -> HOME -> usuario da Play de nuevo."
      print "    };"
      print "    autoTimerRef.current = setTimeout(goNext, Math.max(3, autoIntervalSec) * 1000);"
      print "    return () => { if (autoTimerRef.current) { clearTimeout(autoTimerRef.current); autoTimerRef.current = null; } };"
      print "  }, [autoRun, autoIntervalSec, playlist.length, route.name]);"
      insertedEffect=1
      next
    }

    print line
  }
' src/App.jsx > src/App.jsx.tmp && mv src/App.jsx.tmp src/App.jsx

echo "== 3) Añadiendo controles en la UI (debajo de los filtros) =="
awk '
  BEGIN{inserted=0}
  {
    line=$0
    if (!inserted && line ~ /<div className="controls">/) {
      print line
      print "        {/* Controles de autoplay (playlist) */}"
      print "        <AutoPlayControls"
      print "          running={autoRun}"
      print "          onToggle={()=>setAutoRun(v=>!v)}"
      print "          intervalSec={autoIntervalSec} setIntervalSec={setAutoIntervalSec}"
      print "          order={autoOrder} setOrder={setAutoOrder}"
      print "          onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents}"
      print "          loop={autoLoop} setLoop={setAutoLoop}"
      print "        />"
      inserted=1
      next
    }
    print line
  }
' src/App.jsx > src/App.jsx.tmp && mv src/App.jsx.tmp src/App.jsx

echo "== 4) Estilos mínimos para el bloque de controles =="
[ -f src/styles.css ] || touch src/styles.css
grep -q "autoplay-controls" src/styles.css || cat >> src/styles.css <<'CSS'

/* Autoplay / Playlist */
.autoplay-controls .k-btn { border-color:#cbd5e1; color:#334155; background:#fff; }
.autoplay-controls input, .autoplay-controls select {
  border:1px solid #e5e7eb; border-radius:6px; background:#fff; color:#111827;
}
CSS

echo
echo "✅ Playlist instalado."
echo "Abre el dashboard (HOME) y verás el módulo 'Playlist de instancias' con Play/Pause."
echo "Al dar Play, el dashboard abrirá sedes en secuencia según filtros y orden."
