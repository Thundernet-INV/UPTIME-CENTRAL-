#!/bin/bash
echo "🔧 ARREGLANDO CONFLICTOS DE MERGE EN INDEX.JS"
echo "============================================="

INDEX_FILE="/opt/kuma-central/kuma-aggregator/src/index.js"
BACKUP_FILE="$INDEX_FILE.backup.$(date +%s)"

if [ ! -f "$INDEX_FILE" ]; then
    echo "❌ Archivo no encontrado: $INDEX_FILE"
    exit 1
fi

# Hacer backup
cp "$INDEX_FILE" "$BACKUP_FILE"
echo "✅ Backup creado: $BACKUP_FILE"

echo ""
echo "📄 Eliminando conflictos de merge..."

# Método más seguro: procesar línea por línea manteniendo la versión HEAD
cat > /tmp/fix_merge.js << 'SCRIPT'
const fs = require('fs');
const filePath = process.argv[2];
const lines = fs.readFileSync(filePath, 'utf8').split('\n');
const output = [];
let inConflict = false;
let keepLines = false;

for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (line.startsWith('<<<<<<<')) {
        inConflict = true;
        keepLines = true;  // Empezar a mantener líneas (HEAD)
    } else if (line.startsWith('=======')) {
        keepLines = false; // Dejar de mantener líneas (ignorar versión antigua)
    } else if (line.startsWith('>>>>>>>')) {
        inConflict = false;
        keepLines = false;
    } else if (!inConflict) {
        output.push(line); // Fuera de conflicto, mantener línea
    } else if (keepLines) {
        output.push(line); // Dentro de conflicto, solo mantener HEAD
    }
    // Si inConflict=true y keepLines=false, no agregamos la línea (ignorar versión antigua)
}

fs.writeFileSync(filePath, output.join('\n'));
console.log('✅ Conflictos resueltos manteniendo versión HEAD');
SCRIPT

# Ejecutar el fix
node /tmp/fix_merge.js "$INDEX_FILE"

echo ""
echo "🧪 Verificando sintaxis..."
if node -c "$INDEX_FILE" > /dev/null 2>&1; then
    echo "✅ Sintaxis JavaScript correcta"
else
    echo "❌ Aún hay errores de sintaxis"
    echo "Detalle del error:"
    node -c "$INDEX_FILE"
    echo ""
    echo "🔙 Restaurando backup..."
    cp "$BACKUP_FILE" "$INDEX_FILE"
    exit 1
fi

echo ""
echo "🔍 Verificando imports importantes..."
echo ""
echo "1. Import de historyService:"
grep -n "import.*historyService" "$INDEX_FILE"
echo ""
echo "2. historyService.init():"
grep -n "historyService.init()" "$INDEX_FILE"
echo ""
echo "3. /api/history route:"
grep -n "/api/history" "$INDEX_FILE"
echo ""
echo "4. historyService.addEvent:"
grep -n "historyService.addEvent" "$INDEX_FILE" | head -3

echo ""
echo "============================================="
echo "✅ CONFLICTOS ARREGLADOS"
echo ""
echo "📋 Si todo está bien, puedes continuar con el reinicio."
echo "   El archivo original está en: $BACKUP_FILE"
echo "============================================="
