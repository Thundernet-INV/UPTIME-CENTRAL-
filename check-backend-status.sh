#!/bin/bash

echo "🔍 VERIFICANDO ESTADO DEL BACKEND"
echo "=================================="

# 1. Verificar si el backend está corriendo
echo ""
echo "1. Verificando si el backend está activo..."
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "   ✅ Backend respondiendo en http://localhost:8080"
    HEALTH_RESPONSE=$(curl -s http://localhost:8080/health)
    echo "   📊 Respuesta: $HEALTH_RESPONSE"
else
    echo "   ❌ Backend NO responde en http://localhost:8080"
    echo "   💡 Ejecuta: cd /opt/kuma-central/kuma-agregator && npm start"
fi

# 2. Verificar ruta de historial
echo ""
echo "2. Verificando ruta /api/history..."
if curl -s "http://localhost:8080/api/history?monitorId=test&from=1&to=2" > /dev/null 2>&1; then
    echo "   ✅ Ruta /api/history existe"
else
    echo "   ❌ Ruta /api/history NO disponible"
fi

# 3. Verificar base de datos SQLite
echo ""
echo "3. Verificando base de datos..."
DB_PATH="/opt/kuma-central/kuma-agregator/data/history.db"
if [ -f "$DB_PATH" ]; then
    echo "   ✅ Base de datos encontrada: $DB_PATH"
    SIZE=$(du -h "$DB_PATH" | cut -f1)
    echo "   📊 Tamaño: $SIZE"
    
    # Verificar tablas
    if command -v sqlite3 > /dev/null 2>&1; then
        TABLES=$(sqlite3 "$DB_PATH" ".tables" 2>/dev/null)
        if [ -n "$TABLES" ]; then
            echo "   📋 Tablas encontradas: $TABLES"
        else
            echo "   ⚠️  No se pudieron leer las tablas"
        fi
    fi
else
    echo "   ❌ Base de datos NO encontrada en: $DB_PATH"
fi

# 4. Verificar estructura de archivos
echo ""
echo "4. Verificando estructura de archivos..."

BACKEND_DIR="/opt/kuma-central/kuma-agregator"
check_file() {
    local file="$1"
    local desc="$2"
    if [ -f "$file" ]; then
        echo "   ✅ $desc: $file"
    else
        echo "   ❌ FALTA: $desc ($file)"
    fi
}

check_file "$BACKEND_DIR/src/index.js" "Archivo principal"
check_file "$BACKEND_DIR/src/routes/historyRoutes.js" "Rutas de historial"
check_file "$BACKEND_DIR/src/services/historyService.js" "Servicio de historial"
check_file "$BACKEND_DIR/src/services/storage/sqlite.js" "Storage SQLite"

# 5. Verificar datos en la base de datos
echo ""
echo "5. Verificando datos existentes..."
if [ -f "$DB_PATH" ] && command -v sqlite3 > /dev/null 2>&1; then
    COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM history" 2>/dev/null || echo "0")
    echo "   📈 Registros en tabla 'history': $COUNT"
    
    if [ "$COUNT" -gt "0" ]; then
        echo "   📅 Último registro:"
        sqlite3 "$DB_PATH" "SELECT datetime(timestamp/1000, 'unixepoch'), monitorId, status FROM history ORDER BY timestamp DESC LIMIT 1" 2>/dev/null || echo "      No se pudo leer"
    fi
fi

# 6. Verificar configuración del backend
echo ""
echo "6. Verificando configuración..."
if [ -f "$BACKEND_DIR/src/index.js" ]; then
    if grep -q "historyService.init()" "$BACKEND_DIR/src/index.js"; then
        echo "   ✅ historyService.init() está configurado"
    else
        echo "   ❌ FALTA: historyService.init() en index.js"
    fi
    
    if grep -q "/api/history" "$BACKEND_DIR/src/index.js"; then
        echo "   ✅ Ruta /api/history está montada"
    else
        echo "   ❌ FALTA: Ruta /api/history en index.js"
    fi
    
    if grep -q "addEvent" "$BACKEND_DIR/src/index.js"; then
        echo "   ✅ Guardado automático de eventos configurado"
    else
        echo "   ❌ FALTA: Guardado automático en ciclo de polling"
    fi
fi

echo ""
echo "=================================="
echo "💡 RECOMENDACIONES:"
echo ""

if curl -s http://localhost:8080/health > /dev/null; then
    echo "1. El backend está activo ✅"
else
    echo "1. Inicia el backend:"
    echo "   cd /opt/kuma-central/kuma-agregator"
    echo "   npm start"
fi

if [ -f "$DB_PATH" ]; then
    RECORDS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM history" 2>/dev/null || echo "0")
    if [ "$RECORDS" -eq "0" ]; then
        echo "2. La base de datos está vacía ⚠️"
        echo "   Espera 1-2 ciclos de polling (10 segundos) para que se llenen datos"
    else
        echo "2. La base de datos tiene datos ✅"
    fi
else
    echo "2. La base de datos NO existe ❌"
    echo "   Verifica que el directorio /opt/kuma-central/kuma-agregator/data/ exista"
fi

echo ""
echo "3. Para probar manualmente:"
echo "   curl \"http://localhost:8080/api/history/series?monitorId=San_Felipe_monitor_name&from=\$(date +%s%3N -d '1 hour ago')&to=\$(date +%s%3N)\""
echo ""
echo "📋 RESUMEN DEL ESTADO:"
echo "   Si ves más ✅ que ❌, puedes continuar con el paso 2."
echo "   Si ves muchos ❌, necesitamos corregir el backend primero."
