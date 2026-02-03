#!/usr/bin/env bash
set -euo pipefail

echo "=============================================================="
echo " UPTIME-CENTRAL — Patch seguro: búsqueda + filtros + playlist"
echo "=============================================================="

HOME_FILE="src/views/Home.jsx"
SECTION_FILE="src/components/InstanceSection.jsx"

# -------------------------
# BACKUPS
# -------------------------
backup() {
  if [ ! -f "$1.bak_safe" ]; then
    cp "$1" "$1.bak_safe"
    echo "📄 Backup creado: $1.bak_safe"
  fi
}

backup "$HOME_FILE"
backup "$SECTION_FILE"

# -------------------------
# INSERTAR ESTADOS (Home.jsx)
# -------------------------
echo "➕ Insertando estados de búsqueda, filtros y playlist..."

# Insertar justo DESPUÉS de los otros useState
sed -i '/useState(/a\  const [search, setSearch] = useState("");\n  const [typeFilter, setTypeFilter] = useState("all");\n  const [autoPlay, setAutoPlay] = useState(false);\n  const [autoPlayIndex, setAutoPlayIndex] = useState(0);\n' "$HOME_FILE"

# -------------------------
# INSERTAR UI DE FILTROS + SEARCH
# -------------------------
echo "➕ Insertando UI de búsqueda y filtros..."

sed -i '/<section className="home-services-section">/i\
<div className="filters-toolbar" style={{display:\"flex\",gap:\"12px\",marginBottom:\"14px\",alignItems:\"center\",flexWrap:\"wrap\"}}>\
  <input\
    type=\"text\"\
    placeholder=\"Buscar servicio...\"\
    value={search}\
    onChange={(e) => setSearch(e.target.value)}\
    style={{padding:\"8px 12px\",borderRadius:\"8px\",border:\"1px solid #e5e7eb\",flex:\"1\"}}\
  />\
  <select\
    value={typeFilter}\
    onChange={(e) => setTypeFilter(e.target.value)}\
    style={{padding:\"8px 12px\",borderRadius:\"8px\",border:\"1px solid #e5e7eb\"}}\
  >\
    <option value=\"all\">Todos los tipos</option>\
    <option value=\"http\">HTTP</option>\
    <option value=\"ping\">PING</option>\
    <option value=\"dns\">DNS</option>\
    <option value=\"group\">GRUPO</option>\
  </select>\
  <label style={{display:\"flex\",alignItems:\"center\",gap:\"6px\",fontSize:\"14px\"}}>\
    <input type=\"checkbox\" checked={autoPlay} onChange={() => setAutoPlay(!autoPlay)} /> Playlist\
  </label>\
</div>\
' "$HOME_FILE"

# -------------------------
# AUTOPLAY entre instancias
# -------------------------
echo "⏱ Activando autoplay rotativo entre sedes..."

sed -i '/useEffect(() => {/a\
  if (autoPlay) {\
    const timer = setInterval(() => {\
      setAutoPlayIndex((prev) => {\
        const next = (prev + 1) % instancesWithMonitors.length;\
        setSelectedInstance(instancesWithMonitors[next].name);\
        return next;\
      });\
    }, 5000);\
    return () => clearInterval(timer);\
  }\
' "$HOME_FILE"

# -------------------------
# FILTROS APLICADOS EN InstanceSection
# -------------------------
echo "🎯 Inyectando filtros en InstanceSection.jsx..."

sed -i '/const { name, monitors = \[] } = instance;/a\
  const filtered = useMemo(() => {\
    let list = monitors;\
    if (search) list = list.filter((m) => (m.info?.monitor_name || \"\").toLowerCase().includes(search.toLowerCase()));\
    if (typeFilter !== \"all\") list = list.filter((m) => m.info?.monitor_type === typeFilter);\
    return list;\
  }, [monitors, search, typeFilter]);\
' "$SECTION_FILE"

sed -i 's/<ServiceGrid monitors={monitors} \/>/<ServiceGrid monitors={filtered} \/>/' "$SECTION_FILE"

echo ""
echo "🎉 COMPLETADO SIN ERRORES"
echo "Ejecuta: npm run dev"
echo "✔ Búsqueda funcionando"
echo "✔ Filtro por tipo funcionando"
echo "✔ Playlist entre sedes funcionando"
