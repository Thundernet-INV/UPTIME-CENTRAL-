#!/bin/bash

echo "=== REPARACIÓN SIMPLE DE CORS ==="
echo ""

BACKEND_DIR="/opt/kuma-central/kuma-aggregator"
INDEX_FILE="${BACKEND_DIR}/src/index.js"
BACKUP_FILE="${INDEX_FILE}.backup.cors.simple.$(date +%s)"

# 1. Backup
cp "$INDEX_FILE" "$BACKUP_FILE"
echo "✅ Backup creado: $BACKUP_FILE"

# 2. Crear una versión temporal para editar
TEMP_FILE="${INDEX_FILE}.temp"
cp "$INDEX_FILE" "$TEMP_FILE"

# 3. Verificar si ya tiene cors configurado
if grep -q "app.use(cors(" "$TEMP_FILE"; then
  echo "⚠️  Ya tiene CORS configurado, reemplazando..."
  # Extraer todo el bloque de cors
  sed -i '/app\.use(cors/,/^[[:space:]]*);/{//!d;}' "$TEMP_FILE"
  sed -i '/app\.use(cors/d' "$TEMP_FILE"
fi

# 4. Agregar import de cors si no existe
if ! grep -q "import.*cors" "$TEMP_FILE"; then
  echo "🔧 Agregando import de cors..."
  # Buscar línea con import express
  IMPORT_LINE=$(grep -n "import express" "$TEMP_FILE" | head -1 | cut -d: -f1)
  if [ -n "$IMPORT_LINE" ]; then
    # Usar sed seguro con nueva línea
    sed -i "${IMPORT_LINE}a\\
import cors from 'cors';" "$TEMP_FILE"
  fi
fi

# 5. Buscar línea después de app = express()
APP_LINE=$(grep -n "const app = express()" "$TEMP_FILE" | head -1 | cut -d: -f1)

if [ -n "$APP_LINE" ]; then
  echo "🔧 Insertando configuración CORS..."
  
  # Crear archivo con la configuración CORS
  cat > /tmp/cors_config.js << 'EOF'
// Configuración CORS para permitir frontend
app.use(cors({
  origin: true, // Permitir cualquier origen
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
}));
EOF
  
  # Insertar después de app = express()
  APP_LINE=$((APP_LINE + 1))
  
  # Usar awk para insertar de manera segura
  awk -v line="$APP_LINE" -v config="$(cat /tmp/cors_config.js)" '
    NR == line {print config "\n" $0; next}
    {print}
  ' "$TEMP_FILE" > "${TEMP_FILE}.new"
  
  mv "${TEMP_FILE}.new" "$TEMP_FILE"
  
  echo "✅ Configuración CORS insertada"
else
  echo "❌ No se encontró 'const app = express()'"
  exit 1
fi

# 6. También agregar middleware manual para OPTIONS
echo "🔧 Agregando middleware para OPTIONS..."

cat > /tmp/options_middleware.js << 'EOF'
// Manejar preflight OPTIONS para todas las rutas
app.options('*', cors());
EOF

# Insertar después del CORS
CORS_LINE=$(grep -n "app.use(cors(" "$TEMP_FILE" | head -1 | cut -d: -f1)
if [ -n "$CORS_LINE" ]; then
  CORS_LINE=$((CORS_LINE + 1))
  # Contar líneas hasta el cierre del CORS
  END_CORS=$(awk -v start="$CORS_LINE" 'NR >= start && /^[[:space:]]*}\);/ {print NR; exit}' "$TEMP_FILE")
  
  if [ -n "$END_CORS" ]; then
    END_CORS=$((END_CORS + 1))
    
    awk -v line="$END_CORS" -v middleware="$(cat /tmp/options_middleware.js)" '
      NR == line {print middleware "\n" $0; next}
      {print}
    ' "$TEMP_FILE" > "${TEMP_FILE}.new"
    
    mv "${TEMP_FILE}.new" "$TEMP_FILE"
    echo "✅ Middleware OPTIONS agregado"
  fi
fi

# 7. Verificar sintaxis
echo "🔍 Verificando sintaxis..."
if node -c "$TEMP_FILE" > /dev/null 2>&1; then
  echo "✅ Sintaxis correcta"
  
  # Reemplazar el archivo original
  cp "$TEMP_FILE" "$INDEX_FILE"
  rm "$TEMP_FILE"
  
  echo "✅ Archivo actualizado: $INDEX_FILE"
  
  # 8. Mostrar cambios
  echo ""
  echo "=== CAMBIOS REALIZADOS ==="
  grep -n -A10 -B2 "cors\|CORS\|Access-Control" "$INDEX_FILE" | head -30
  
else
  echo "❌ Error de sintaxis:"
  node -c "$TEMP_FILE"
  echo ""
  echo "⚠️  Restaurando backup original..."
  cp "$BACKUP_FILE" "$INDEX_FILE"
  rm "$TEMP_FILE"
  exit 1
fi

echo ""
echo "=== INSTRUCCIONES ==="
echo "1. El archivo ha sido actualizado"
echo "2. Ahora reinicia el backend:"
echo "   sudo kill \$(sudo lsof -ti:8080) 2>/dev/null || true"
echo "   cd /opt/kuma-central/kuma-aggregator && npm start &"
echo "3. Luego prueba con:"
echo "   curl -X OPTIONS -H 'Origin: http://10.10.31.31:5173' http://localhost:8080/api/summary -I"
