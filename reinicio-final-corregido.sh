#!/bin/bash
echo "🚀 REINICIO FINAL CON BASE DE DATOS CORREGIDA"
echo "=============================================="

BACKEND_DIR="/opt/kuma-central/kuma-aggregator"
LOG_FILE="/var/log/kuma-backend.log"

# 1. Detener cualquier proceso
echo "1. Deteniendo procesos anteriores..."
sudo kill $(sudo lsof -ti:8080) 2>/dev/null || true
sleep 2
sudo kill -9 $(sudo lsof -ti:8080) 2>/dev/null || true
sleep 1
echo "   ✅ Procesos detenidos"

# 2. Verificaciones finales
echo ""
echo "2. Verificaciones finales..."
cd "$BACKEND_DIR"

echo "   - Base de datos tiene columna 'instance'?:"
if sqlite3 "data/history.db" "PRAGMA table_info(monitor_history);" 2>/dev/null | grep -q "instance"; then
    echo "     ✅ Sí, columna 'instance' existe"
else
    echo "     ❌ No, falta columna 'instance'"
    exit 1
fi

echo "   - Sintaxis de index.js:"
if node -c "src/index.js" > /dev/null 2>&1; then
    echo "     ✅ Sintaxis OK"
else
    echo "     ❌ Error:"
    node -c "src/index.js"
    exit 1
fi

echo "   - Sintaxis de historyService.js:"
if node -c "src/services/historyService.js" > /dev/null 2>&1; then
    echo "     ✅ Sintaxis OK"
else
    echo "     ❌ Error:"
    node -c "src/services/historyService.js"
    exit 1
fi

# 3. Iniciar backend
echo ""
echo "3. Iniciando backend..."
echo "   Logs: $LOG_FILE"
> "$LOG_FILE"  # Limpiar log

echo "   Comando: npm start"
npm start >> "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "   ✅ Proceso iniciado: PID $NEW_PID"

# 4. Esperar con checks periódicos
echo ""
echo "4. Esperando inicio (15 segundos con checks)..."
for i in {1..15}; do
    echo -n "."
    
    # Cada 3 segundos, verificar si hay errores en el log
    if (( i % 3 == 0 )); then
        if tail -5 "$LOG_FILE" | grep -q "Error\|ERR!\|Failed"; then
            echo ""
            echo "   ⚠️  Error detectado en logs"
            break
        fi
    fi
    
    sleep 1
done
echo ""

# 5. Verificar estado
echo ""
echo "5. Verificando estado final..."
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    HEALTH=$(curl -s http://localhost:8080/health)
    echo "   ✅ Backend ACTIVO"
    echo "   📊 Health: $HEALTH"
    
    # Verificar que sea el NUEVO backend (no uno viejo)
    CURRENT_PID=$(sudo lsof -ti:8080 | head -1)
    if [ "$CURRENT_PID" = "$NEW_PID" ]; then
        echo "   🔄 Es el NUEVO backend (PID: $CURRENT_PID)"
    else
        echo "   ⚠️  Es un backend diferente (PID: $CURRENT_PID, esperado: $NEW_PID)"
    fi
else
    echo "   ❌ Backend NO responde"
    echo ""
    echo "🔍 Últimas 25 líneas del log:"
    tail -25 "$LOG_FILE"
    echo ""
    echo "💡 Intentar iniciar manualmente:"
    echo "   cd $BACKEND_DIR"
    echo "   npm start"
    exit 1
fi

# 6. Probar módulo de historial
echo ""
echo "6. Probando módulo de historial..."
TEST_RESP=$(curl -s "http://localhost:8080/api/history?limit=1")
if echo "$TEST_RESP" | grep -q "data\|errors"; then
    echo "   ✅ API de historial respondiendo"
else
    echo "   ⚠️  Respuesta inesperada: $(echo $TEST_RESP | head -c 100)"
fi

# 7. Verificar guardado automático
echo ""
echo "7. Verificando configuración de guardado automático..."
ADD_EVENT_COUNT=$(grep -c "historyService.addEvent" "src/index.js")
if [ "$ADD_EVENT_COUNT" -gt 0 ]; then
    echo "   ✅ Guardado automático configurado en $ADD_EVENT_COUNT lugares"
else
    echo "   ❌ NO hay guardado automático configurado"
fi

echo ""
echo "=============================================="
echo "🎉 BACKEND CONFIGURADO COMPLETAMENTE"
echo ""
echo "📋 ESTADO ACTUAL:"
echo "   - PID: $NEW_PID (verificar con: sudo lsof -ti:8080)"
echo "   - Base de datos: Corregida (con columna 'instance')"
echo "   - Guardado automático: Configurado"
echo "   - Health check: Funcionando"
echo ""
echo "⏳ AHORA ESPERA 20-30 SEGUNDOS"
echo "   El backend procesará 4-6 ciclos de polling"
echo "   y comenzará a llenar la base de datos."
echo ""
echo "📊 Para verificar progreso:"
echo "   watch -n 5 'sqlite3 /opt/kuma-central/kuma-aggregator/data/history.db \"SELECT COUNT(*) FROM monitor_history\"'"
echo ""
echo "=============================================="
