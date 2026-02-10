#!/bin/bash
# fix-history-range.sh - Cambia rangos temporales de 15 min a 60 min

echo "🔧 Iniciando corrección de rangos temporales..."

# Backup del directorio actual
BACKUP_DIR="./backup_history_ranges_$(date +%Y%m%d_%H%M%S)"
echo "📦 Creando backup en: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Archivos a modificar
declare -a FILES_TO_MODIFY=(
  "src/components/InstanceDetail.jsx"
  "src/components/MultiServiceView.jsx"
  "src/components/MonitorsTable.jsx"
  "src/views/Dashboard.jsx"
  "src/views/Dashboard.jsx.bak_autoplay"
  "src/views/Dashboard.jsx.bak_branding2"
  "src/views/Dashboard.jsx.bak_branding_clean"
  "src/views/Dashboard.jsx.bak_controls"
  "src/views/Dashboard.jsx.tmp_autoplay"
)

# 1. Crear backups
for file in "${FILES_TO_MODIFY[@]}"; do
  if [[ -f "$file" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$file")"
    cp "$file" "$BACKUP_DIR/$file"
    echo "  ✓ Backup: $file"
  else
    echo "  ⚠️ No existe: $file (se omitirá)"
  fi
done

echo ""
echo "🔄 Reemplazando rangos temporales..."

# 2. Reemplazar patrones específicos
# Patrón 1: 15 * 60 * 1000 → 60 * 60 * 1000
echo "  → 15*60*1000 → 60*60*1000 (15min → 60min)"
for file in "${FILES_TO_MODIFY[@]}"; do
  if [[ -f "$file" ]]; then
    # Contar ocurrencias antes
    count_before=$(grep -o "15 \* 60 \* 1000\|15\*60\*1000" "$file" | wc -l)
    
    # Hacer reemplazo
    sed -i 's/15 \* 60 \* 1000/60 \* 60 \* 1000/g' "$file"
    sed -i 's/15\*60\*1000/60\*60\*1000/g' "$file"
    
    # Contar después
    count_after=$(grep -o "60 \* 60 \* 1000\|60\*60\*1000" "$file" | wc -l)
    
    if [[ $count_before -gt 0 ]]; then
      echo "    ✓ $file: $count_before → $count_after cambios"
    fi
  fi
done

# Patrón 2: 15*60*1000 (sin espacios) → 60*60*1000
# (Ya se hizo arriba, pero por si acaso)

# Patrón 3: 900000 (15min en ms) → 3600000 (60min en ms)
echo ""
echo "  → 900000 → 3600000 (valores numéricos)"
for file in "${FILES_TO_MODIFY[@]}"; do
  if [[ -f "$file" ]]; then
    # Solo valores exactos de 900000 (no en medio de otros números)
    sed -i 's/\b900000\b/3600000/g' "$file"
  fi
done

# 3. Cambios específicos en Dashboard.jsx (principal)
echo ""
echo "🎯 Aplicando cambios específicos en Dashboard.jsx..."

if [[ -f "src/views/Dashboard.jsx" ]]; then
  # Reemplazar DELTA_WINDOW si es necesario
  sed -i 's/DELTA_WINDOW = 5/DELTA_WINDOW = 20/g' "src/views/Dashboard.jsx"
  echo "    ✓ DELTA_WINDOW actualizado a 20"
fi

# 4. Crear archivo de configuración de rangos de tiempo (opcional pero recomendado)
echo ""
echo "📝 Creando archivo de configuración de rangos..."

cat > "src/config/timeRanges.js" << 'EOF'
// src/config/timeRanges.js - Configuración centralizada de rangos temporales
export const TIME_RANGES = {
  // Rangos en milisegundos
  MINUTES_5: 5 * 60 * 1000,      // 300,000 ms
  MINUTES_15: 15 * 60 * 1000,    // 900,000 ms
  MINUTES_30: 30 * 60 * 1000,    // 1,800,000 ms
  HOUR_1: 60 * 60 * 1000,        // 3,600,000 ms
  HOURS_2: 2 * 60 * 60 * 1000,   // 7,200,000 ms
  HOURS_4: 4 * 60 * 60 * 1000,   // 14,400,000 ms
  HOURS_8: 8 * 60 * 60 * 1000,   // 28,800,000 ms
  HOURS_12: 12 * 60 * 60 * 1000, // 43,200,000 ms
  HOURS_24: 24 * 60 * 60 * 1000, // 86,400,000 ms
  
  // Nombres descriptivos
  SHORT_TERM: 15 * 60 * 1000,    // 15 minutos (corto plazo)
  MEDIUM_TERM: 60 * 60 * 1000,   // 60 minutos (medio plazo - DEFAULT)
  LONG_TERM: 24 * 60 * 60 * 1000, // 24 horas (largo plazo)
};

// Alias para compatibilidad
export const DEFAULT_RANGE = TIME_RANGES.HOUR_1;
export const SHORT_RANGE = TIME_RANGES.MINUTES_15;
export const LONG_RANGE = TIME_RANGES.HOURS_24;
EOF

echo "    ✓ Creado src/config/timeRanges.js"

# 5. Actualizar historyEngine.js para usar rangos configurables
echo ""
echo "🔄 Actualizando historyEngine.js para usar rangos configurables..."

if [[ -f "src/historyEngine.js" ]]; then
  # Hacer backup
  cp "src/historyEngine.js" "$BACKUP_DIR/src/historyEngine.js"
  
  # Modificar historyEngine.js
  cat > "src/historyEngine.js" << 'EOF'
import Mem from './historyMem';
import DB from './historyDB';

/** Devuelve un punto 'array-like':
 *   p = [ts, sec]; p.ts=ts; p.x=ts; p.y=sec; p.value=sec; p.sec=sec; p.ms=ms; p.avgMs=ms; p.xy=[ts,sec];
 *   => Compatible con charts que esperan tuplas [x,y] o props {x,y}
 */
function mkPoint(ts, ms){
  const sec = (typeof ms === 'number') ? (ms/1000) : null;
  const p = [ts, sec];
  p.ts = ts;
  p.x  = ts;
  p.y  = sec;
  p.value = sec;
  p.sec = sec;
  p.ms  = ms;
  p.avgMs = ms;
  p.xy = [ts, sec];
  return p;
}

// Rangos configurables (pueden ser importados de timeRanges.js)
const DEFAULT_RANGES = {
  SHORT: 60 * 60 * 1000,     // 60 minutos por defecto
  MEDIUM: 24 * 60 * 60 * 1000, // 24 horas
  LONG: 7 * 24 * 60 * 60 * 1000, // 7 días
};

const History = {
  addSnapshot(monitors) {
    try { Mem.addSnapshots?.(monitors); } catch {}
    try { DB.addSnapshots?.(monitors); DB.pruneOlderThanDays?.(7); } catch {}
    try { if (typeof window !== 'undefined') window.__histLastAddTs = Date.now(); } catch {}
  },

  async getSeriesForMonitor(instance, name, sinceMs = DEFAULT_RANGES.SHORT) {
    try {
      const mem = Mem.getSeriesForMonitor?.(instance, name, sinceMs) || [];
      if (mem.length) {
        const out = mem.map(r => mkPoint(r.ts, r.ms));
        console.log('[HIST] getSeriesForMonitor(mem)', instance, name, '->', out.length, 'puntos');
        return out;
      }
      const key = `${instance}::${name||''}`;
      const rows = await (DB.getSeriesFor ? DB.getSeriesFor(key, sinceMs) : Promise.resolve([]));
      const out = (rows||[])
        .filter(r => typeof r.responseTime === 'number')
        .map(r => mkPoint(r.ts, r.responseTime));
      console.log('[HIST] getSeriesForMonitor(db)', instance, name, '->', out.length, 'puntos (', sinceMs/1000/60, 'min)');
      return out;
    } catch (e) {
      console.error('[HIST] getSeriesForMonitor error', e);
      return [];
    }
  },

  async getAvgSeriesForMonitor(instance, name, sinceMs = DEFAULT_RANGES.MEDIUM, bucketMs = 60*1000) {
    try {
      const base = await this.getSeriesForMonitor(instance, name, sinceMs);
      if (!base.length) return [];
      const sum = new Map(), count = new Map();
      for (const s of base) {
        const ms = (typeof s.ms === 'number') ? s.ms : (s[1]*1000);
        const b = Math.floor(s.ts / bucketMs) * bucketMs;
        sum.set(b, (sum.get(b) || 0) + ms);
        count.set(b, (count.get(b) || 0) + 1);
      }
      const out = [];
      for (const [b, s] of sum) out.push(mkPoint(b, s / (count.get(b) || 1)));
      out.sort((a,b)=> a.ts - b.ts);
      console.log('[HIST] getAvgSeriesForMonitor', instance, name, '->', out.length, 'buckets');
      return out;
    } catch (e) {
      console.error('[HIST] getAvgSeriesForMonitor error', e);
      return [];
    }
  },

  async getAllForInstance(instance, sinceMs = DEFAULT_RANGES.SHORT) {
    try {
      const objMem = Mem.getAllForInstance?.(instance, sinceMs);
      if (objMem && Object.keys(objMem).length) {
        const ofmt = {};
        for (const [name, arr] of Object.entries(objMem)) ofmt[name] = arr.map(r => mkPoint(r.ts, r.ms));
        const total = Object.values(ofmt).reduce((n,a)=>n+a.length,0);
        console.log('[HIST] getAllForInstance(mem)', instance, 'series:', Object.keys(ofmt).length, 'points:', total);
        return ofmt;
      }
      const objDb = await (DB.getAllForInstance ? DB.getAllForInstance(instance, sinceMs) : Promise.resolve({}));
      const ofmt = {};
      for (const [name, arr] of Object.entries(objDb || {})) {
        ofmt[name] = (arr||[])
          .filter(r => typeof r.responseTime === 'number')
          .map(r => mkPoint(r.ts, r.responseTime));
      }
      const total = Object.values(ofmt).reduce((n,a)=>n+a.length,0);
      console.log('[HIST] getAllForInstance(db)', instance, 'series:', Object.keys(ofmt).length, 'points:', total);
      return ofmt;
    } catch (e) {
      console.error('[HIST] getAllForInstance error', e);
      return {};
    }
  },

  async getAvgSeriesByInstance(instance, sinceMs = DEFAULT_RANGES.SHORT, bucketMs = 60*1000) {
    try {
      const mem = Mem.getAvgSeriesByInstance?.(instance, sinceMs, bucketMs) || [];
      if (mem.length) {
        const out = mem.map(p => mkPoint(p.ts, p.avgMs));
        console.log('[HIST] getAvgSeriesByInstance(mem)', instance, '->', out.length);
        return out;
      }
      const arr = await (DB.getAvgSeriesByInstance ? DB.getAvgSeriesByInstance(instance, sinceMs, bucketMs) : Promise.resolve([]));
      const out = (arr||[]).map(p => mkPoint(p.ts, p.avgMs));
      console.log('[HIST] getAvgSeriesByInstance(db)', instance, '->', out.length);
      return out;
    } catch (e) {
      console.error('[HIST] getAvgSeriesByInstance error', e);
      return [];
    }
  },

  debugInfo() {
    try { return Mem.debugInfo?.(); } catch { return {}; }
  },
};

// Exponer para consola
try { if (typeof window !== 'undefined') window.__hist = History; } catch {}

// Exportar rangos también
History.DEFAULT_RANGES = DEFAULT_RANGES;
History.DEFAULT_SHORT_RANGE = DEFAULT_RANGES.SHORT;
History.DEFAULT_MEDIUM_RANGE = DEFAULT_RANGES.MEDIUM;
History.DEFAULT_LONG_RANGE = DEFAULT_RANGES.LONG;

export default History;
EOF

  echo "    ✓ Actualizado historyEngine.js con rangos configurables"
fi

echo ""
echo "✅ ¡Cambios completados!"
echo ""
echo "📊 Resumen de cambios:"
echo "   - Rangos de 15 min cambiados a 60 min en todos los componentes"
echo "   - Histórico ahora muestra 60 minutos por defecto"
echo "   - Archivo de configuración creado: src/config/timeRanges.js"
echo "   - historyEngine.js actualizado para usar rangos configurables"
echo ""
echo "📂 Backup disponible en: $BACKUP_DIR"
echo ""
echo "🔄 Para aplicar los cambios, reinicia tu servidor de desarrollo:"
echo "   npm run dev  # o yarn dev"
echo ""
echo "🔍 Verificación rápida:"
echo "   grep -n '60 \* 60 \* 1000' src/components/*.jsx | head -5"
echo ""
echo "⚠️  Si encuentras problemas, puedes restaurar desde el backup:"
echo "   cp -r $BACKUP_DIR/* ."
