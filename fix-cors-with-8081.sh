#!/bin/bash
echo "🔧 ACTUALIZANDO CORS CON PUERTO 8081"
echo "====================================="

INDEX_FILE="/opt/kuma-central/kuma-aggregator/src/index.js"
BACKUP_FILE="$INDEX_FILE.backup.cors8081.$(date +%s)"

if [ ! -f "$INDEX_FILE" ]; then
    echo "❌ Archivo no encontrado: $INDEX_FILE"
    exit 1
fi

# Hacer backup
cp "$INDEX_FILE" "$BACKUP_FILE"
echo "✅ Backup: $BACKUP_FILE"

echo ""
echo "📄 Actualizando configuración CORS..."

# Crear archivo temporal con los cambios
cat > /tmp/update_cors.js << 'EOF'
const fs = require('fs');
const filePath = process.argv[2];
let content = fs.readFileSync(filePath, 'utf8');

// Buscar la configuración CORS
const corsRegex = /app\.use\(cors\({[\s\S]*?}\)\);/g;
const matches = content.match(corsRegex);

if (matches && matches.length > 0) {
    // Tomar la primera configuración CORS
    let corsConfig = matches[0];
    
    // 1. Agregar puerto 8081 a los orígenes
    corsConfig = corsConfig.replace(
        /origin:\s*\[([^\]]+)\]/,
        (match, origins) => {
            // Verificar si ya tiene 8081
            if (!origions.includes('8081')) {
                // Agregar 8081 al final antes de cerrar el array
                return `origin: [${origions.replace(/\]$/, ', ')}'http://10.10.31.31:8081']`;
            }
            return match;
        }
    );
    
    // 2. Agregar 'Pragma' a allowedHeaders si no está
    if (!corsConfig.includes("'Pragma'") && !corsConfig.includes('"Pragma"')) {
        corsConfig = corsConfig.replace(
            /allowedHeaders:\s*\[([^\]]+)\]/,
            `allowedHeaders: [$1, 'Pragma']`
        );
    }
    
    // Reemplazar en el contenido
    content = content.replace(matches[0], corsConfig);
    
    // Eliminar posibles configuraciones CORS duplicadas
    const allCorsMatches = content.match(corsRegex);
    if (allCorsMatches && allCorsMatches.length > 1) {
        // Mantener solo la primera, eliminar las demás
        for (let i = 1; i < allCorsMatches.length; i++) {
            content = content.replace(allCorsMatches[i], '');
        }
    }
    
    fs.writeFileSync(filePath, content);
    console.log('✅ CORS actualizado con puerto 8081 y header Pragma');
} else {
    console.log('❌ No se encontró configuración CORS');
    process.exit(1);
}
EOF

# Ejecutar el script Node.js
node /tmp/update_cors.js "$INDEX_FILE"

echo ""
echo "🔍 Resultado:"
grep -n -A8 "app.use(cors" "$INDEX_FILE"

echo ""
echo "🧪 Verificando sintaxis..."
if node -c "$INDEX_FILE" > /dev/null 2>&1; then
    echo "✅ Sintaxis correcta"
else
    echo "❌ Error de sintaxis"
    node -c "$INDEX_FILE"
    exit 1
fi

echo ""
echo "🔄 Reiniciando backend..."
# Detener backend si existe
BACKEND_PID=$(sudo lsof -ti:8080 2>/dev/null || echo "")
if [ -n "$BACKEND_PID" ]; then
    echo "   Deteniendo backend PID $BACKEND_PID..."
    sudo kill $BACKEND_PID 2>/dev/null
    sleep 2
fi

echo "   Iniciando nuevo backend..."
cd /opt/kuma-central/kuma-aggregator
npm start > /var/log/kuma-backend.log 2>&1 &
NEW_PID=$!
echo "   ✅ Nuevo backend: PID $NEW_PID"

echo ""
echo "⏳ Esperando inicio (7 segundos)..."
sleep 7

echo ""
echo "🏥 Verificando health..."
if curl -s http://localhost:8080/health > /dev/null; then
    HEALTH=$(curl -s http://localhost:8080/health)
    echo "   ✅ Backend activo: $HEALTH"
else
    echo "   ❌ Backend no responde"
    echo "   🔍 Últimas líneas del log:"
    tail -15 /var/log/kuma-backend.log
fi

echo ""
echo "====================================="
echo "✅ CONFIGURACIÓN CORS ACTUALIZADA"
echo ""
echo "📋 Orígenes permitidos ahora incluyen:"
echo "   - http://localhost:5174"
echo "   - http://localhost:5173"
echo "   - http://10.10.31.31:5174"
echo "   - http://10.10.31.31:5173"
echo "   - http://10.10.31.31"
echo "   - http://10.10.31.31:8081  ← NUEVO"
echo ""
echo "📋 Headers permitidos:"
echo "   - Content-Type"
echo "   - Authorization"
echo "   - Pragma"
echo ""
echo "🌐 Prueba tu frontend ahora."
echo "====================================="
