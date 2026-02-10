#!/bin/bash
echo "🔧 ACTUALIZANDO FRONTEND A 60 MINUTOS"
echo "======================================"

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="$FRONTEND_DIR/backup_frontend_$(date +%Y%m%d_%H%M%S)"

echo "1. Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "$FRONTEND_DIR/src/historyEngine.js" "$BACKUP_DIR/" 2>/dev/null || true
cp "$FRONTEND_DIR/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "$FRONTEND_DIR/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "$FRONTEND_DIR/src/components/MonitorsTable.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "   ✅ Backup en: $BACKUP_DIR"

echo ""
echo "2. Actualizando historyEngine.js..."
if [ -f "$FRONTEND_DIR/src/historyEngine.js" ]; then
    # Cambiar todos los 15 minutos por 60 minutos
    sed -i 's/15\*60\*1000/60\*60\*1000/g' "$FRONTEND_DIR/src/historyEngine.js"
    sed -i 's/15 \* 60 \* 1000/60 \* 60 \* 1000/g' "$FRONTEND_DIR/src/historyEngine.js"
    sed -i 's/900000/3600000/g' "$FRONTEND_DIR/src/historyEngine.js"  # 15min -> 60min en ms
    echo "   ✅ historyEngine.js actualizado"
else
    echo "   ⚠️  historyEngine.js no encontrado"
fi

echo ""
echo "3. Actualizando componentes..."
for file in "$FRONTEND_DIR/src/components/"*.jsx; do
    if [ -f "$file" ]; then
        BASENAME=$(basename "$file")
        CHANGES=0
        
        # Buscar y reemplazar
        if grep -q "15\*60\*1000\|15 \* 60 \* 1000\|900000" "$file"; then
            OLD_COUNT=$(grep -c "15\*60\*1000\|15 \* 60 \* 1000\|900000" "$file")
            sed -i 's/15\*60\*1000/60\*60\*1000/g' "$file"
            sed -i 's/15 \* 60 \* 1000/60 \* 60 \* 1000/g' "$file"
            sed -i 's/900000/3600000/g' "$file"
            NEW_COUNT=$(grep -c "60\*60\*1000\|60 \* 60 \* 1000\|3600000" "$file")
            echo "   📄 $BASENAME: $OLD_COUNT → $NEW_COUNT cambios"
            CHANGES=1
        fi
    fi
done

echo ""
echo "4. Verificando cambios..."
echo "   Ejemplos en historyEngine.js:"
grep -n "sinceMs\|60\*60" "$FRONTEND_DIR/src/historyEngine.js" 2>/dev/null | head -5 || echo "     No encontrado"

echo ""
echo "======================================"
echo "✅ FRONTEND ACTUALIZADO A 60 MINUTOS"
echo ""
echo "📋 RESUMEN:"
echo "   - Rango temporal: 15min → 60min"
echo "   - Las gráficas mostrarán 1 hora de datos"
echo "   - Backup en: $BACKUP_DIR"
echo ""
echo "🔄 Para aplicar cambios:"
echo "   1. Reinicia el frontend:"
echo "      cd $FRONTEND_DIR"
echo "      npm run dev"
echo ""
echo "   2. Verifica que las gráficas muestren 60 minutos"
echo ""
echo "💡 El backend YA está guardando datos (43,680+ registros)"
echo "   Las gráficas ahora usarán datos históricos reales."
echo "======================================"
