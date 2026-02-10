#!/bin/bash

echo "=== CORRIGIENDO PROBLEMA CORS ==="
echo ""

BACKEND_DIR="/opt/kuma-central/kuma-aggregator"
INDEX_FILE="${BACKEND_DIR}/src/index.js"
BACKUP_FILE="${INDEX_FILE}.backup.cors.$(date +%s)"

# 1. Backup
cp "$INDEX_FILE" "$BACKUP_FILE"
echo "✅ Backup creado: $BACKUP_FILE"

# 2. Verificar si cors está importado
if ! grep -q "import.*cors" "$INDEX_FILE"; then
  echo "🔧 Agregando import de cors..."
  IMPORT_LINE=$(grep -n "import express" "$INDEX_FILE" | head -1 | cut -d: -f1)
  
  if [ -n "$IMPORT_LINE" ]; then
    sed -i "${IMPORT_LINE}a\\\nimport cors from 'cors';" "$INDEX_FILE"
    echo "✅ Import de cors agregado"
  fi
fi

# 3. Buscar y reemplazar configuración CORS existente
echo "🔧 Configurando CORS..."

# Primero, eliminar cualquier configuración CORS existente
sed -i '/app\.use(cors/d' "$INDEX_FILE"
sed -i '/origin:/d' "$INDEX_FILE"
sed -i '/credentials:/d' "$INDEX_FILE"
sed -i '/methods:/d' "$INDEX_FILE"
sed -i '/allowedHeaders:/d' "$INDEX_FILE"
sed -i '/Access-Control/d' "$INDEX_FILE"

# 4. Agregar configuración CORS completa después de app = express()
APP_LINE=$(grep -n "const app = express()" "$INDEX_FILE" | head -1 | cut -d: -f1)

if [ -n "$APP_LINE" ]; then
  APP_LINE=$((APP_LINE + 1))
  
  CORS_CONFIG="// Configuración CORS para permitir frontend
app.use(cors({
  origin: true, // Permitir cualquier origen (o especificar ['http://10.10.31.31:5173'])
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD'],
  allowedHeaders: [
    'Content-Type', 
    'Authorization', 
    'Pragma', 
    'Cache-Control', 
    'X-Requested-With',
    'Accept',
    'Accept-Encoding',
    'Accept-Language',
    'Connection',
    'Host',
    'Origin',
    'Referer',
    'User-Agent'
  ],
  exposedHeaders: ['Content-Length', 'Content-Type'],
  maxAge: 86400 // 24 horas
}));"

  # Insertar la configuración
  sed -i "${APP_LINE}i\\\n${CORS_CONFIG}\\\n" "$INDEX_FILE"
  
  echo "✅ Configuración CORS agregada"
else
  echo "❌ No se pudo encontrar 'const app = express()'"
  exit 1
fi

# 5. También agregar headers manualmente para rutas específicas si es necesario
echo "🔧 Agregando headers manuales para rutas de API..."

# Buscar línea donde se montan las rutas de API
API_LINE=$(grep -n "app.use.*/api" "$INDEX_FILE" | head -1 | cut -d: -f1)

if [ -n "$API_LINE" ]; then
  # Insertar middleware de headers antes de las rutas API
  HEADERS_MIDDLEWARE="// Headers CORS para todas las rutas API
app.use('/api', (req, res, next) => {
  res.header('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.header('Access-Control-Allow-Credentials', 'true');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, HEAD');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Pragma, Cache-Control, X-Requested-With, Accept, Accept-Encoding, Accept-Language, Connection, Host, Origin, Referer, User-Agent');
  res.header('Access-Control-Expose-Headers', 'Content-Length, Content-Type');
  res.header('Access-Control-Max-Age', '86400');
  
  // Manejar preflight OPTIONS
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  next();
});"

  sed -i "${API_LINE}i\\\n${HEADERS_MIDDLEWARE}\\\n" "$INDEX_FILE"
  echo "✅ Headers manuales agregados para rutas API"
fi

# 6. Verificar sintaxis
echo "🔍 Verificando sintaxis..."
if node -c "$INDEX_FILE" > /dev/null 2>&1; then
  echo "✅ Sintaxis correcta"
else
  echo "❌ Error de sintaxis, restaurando backup..."
  node -c "$INDEX_FILE"
  cp "$BACKUP_FILE" "$INDEX_FILE"
  exit 1
fi

# 7. Reiniciar backend
echo "🔄 Reiniciando backend..."
sudo kill $(sudo lsof -ti:8080) 2>/dev/null || true
sleep 2

cd "$BACKEND_DIR"
npm start > /var/log/kuma-backend.log 2>&1 &
NEW_PID=$!
sleep 5

echo "✅ Backend reiniciado (PID: $NEW_PID)"

# 8. Probar CORS
echo "🔍 Probando CORS..."
TEST_RESPONSE=$(curl -s -X OPTIONS -H "Origin: http://10.10.31.31:5173" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: pragma,cache-control" \
  http://localhost:8080/api/summary -I)

echo "Respuesta OPTIONS:"
echo "$TEST_RESPONSE" | grep -i "access-control" || echo "No se encontraron headers CORS"

echo ""
echo "=== RESULTADO ==="
echo "Si ves 'Access-Control-Allow-Headers: pragma', el problema está resuelto."
echo "Reinicia el frontend y prueba nuevamente."
