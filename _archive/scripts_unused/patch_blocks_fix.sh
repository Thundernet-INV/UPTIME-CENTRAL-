#!/bin/sh
set -eu
APP="src/App.jsx"
cp "$APP" "$APP.bak.$(date +%Y%m%d_%H%M%S)"

# 1) Reemplazar el bloque baseMonitors (con template literal correcto)
awk '
  BEGIN{inblk=0}
  {
    if (!inblk && $0 ~ /const baseMonitors = useMemo/){
      inblk=1
      print "  // ===== Filtros base (sin estado UP/DOWN) ====="
      print "  const baseMonitors = useMemo(() => monitors.filter(m => {"
      print "    if (filters.instance && m.instance !== filters.instance) return false;"
      print "    if (filters.type && m.info?.monitor_type !== filters.type) return false;"
      print "    if (filters.q) {"
      print "      const hay = ${m.info?.monitor_name ?? \"\"} ${m.info?.monitor_url ?? \"\"}.toLowerCase();"
      print "      if (!hay.includes(filters.q.toLowerCase())) return false;"
      print "    }"
      print "    return true;"
      print "  }), [monitors, filters.instance, filters.type, filters.q]);"
      next
    }
    if (inblk){
      # saltar hasta la línea con el cierre del useMemo original
      if ($0 ~ /\]\s*,\s*$$monitors,\s*filters\.instance,\s*filters\.type,\s*filters\.q$$\s*\)\s*;\s*$/){
        inblk=0
      }
      next
    }
    print
  }' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 2) Reemplazar el bloque filteredAll (con llaves y return true)
awk '
  BEGIN{inblk=0}
  {
    if (!inblk && $0 ~ /const filteredAll = useMemo\(\s*.*baseMonitors\.filter/){
      inblk=1
      print "  // ===== Lista filtrada final ====="
      print "  const filteredAll = useMemo(() => baseMonitors.filter(m => {"
      print "    if (effectiveStatus === \"up\"   && m.latest?.status !== 1) return false;"
      print "    if (effectiveStatus === \"down\" && m.latest?.status !== 0) return false;"
      print "    return true;"
      print "  }), [baseMonitors, effectiveStatus]);"
      next
    }
    if (inblk){
      # saltar hasta el cierre original del useMemo filteredAll
      if ($0 ~ /\]\s*,\s*$$baseMonitors,\s*effectiveStatus$$\s*\)\s*;\s*$/){
        inblk=0
      }
      next
    }
    print
  }' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "✓ Bloques baseMonitors y filteredAll reparados."
