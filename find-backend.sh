#!/bin/bash
echo "🔍 BUSCANDO BACKEND REAL (puerto 8080)..."
echo "=========================================="

# 1. Buscar proceso Node.js en puerto 8080
echo ""
echo "1. Proceso usando puerto 8080:"
PORT_PID=$(sudo lsof -ti:8080 2>/dev/null)
if [ -n "$PORT_PID" ]; then
    echo "   ✅ PID encontrado: $PORT_PID"
    PROCESS_INFO=$(ps -p $PORT_PID -o cmd=)
    echo "   📝 Comando: $PROCESS_INFO"
    
    # Extraer ruta del comando
    if [[ "$PROCESS_INFO" == *"node"* ]]; then
        # Buscar el archivo .js que está ejecutando
        JS_FILE=$(echo "$PROCESS_INFO" | grep -o "node.*\.js" | sed 's/node //')
        if [ -n "$JS_FILE" ]; then
            echo "   📄 Archivo JS: $JS_FILE"
            # Obtener directorio
            if [ -f "$JS_FILE" ]; then
                BACKEND_DIR=$(dirname "$(realpath "$JS_FILE")")
                echo "   📁 Directorio backend: $BACKEND_DIR"
            else
                # Buscar en working directory del proceso
                PROC_CWD=$(sudo readlink /proc/$PORT_PID/cwd)
                echo "   📁 Working directory: $PROC_CWD"
                BACKEND_DIR="$PROC_CWD"
            fi
        fi
    fi
else
    echo "   ❌ No hay proceso en puerto 8080"
fi

# 2. Buscar en rutas comunes
echo ""
echo "2. Buscando en rutas comunes..."

# Primero buscar desde el directorio actual hacia arriba
CURRENT_DIR=$(pwd)
while [ "$CURRENT_DIR" != "/" ]; do
    if [ -f "$CURRENT_DIR/package.json" ] && [ -d "$CURRENT_DIR/src" ]; then
        echo "   📁 Encontrado en: $CURRENT_DIR"
        BACKEND_DIR="$CURRENT_DIR"
        break
    fi
    CURRENT_DIR=$(dirname "$CURRENT_DIR")
done

# Rutas específicas para buscar
declare -a CHECK_PATHS=(
    "/home/thunder"
    "/opt"
    "/var/www"
    "$HOME"
    "/root"
)

for base_path in "${CHECK_PATHS[@]}"; do
    if [ -d "$base_path" ]; then
        echo "   🔎 Buscando en $base_path..."
        # Buscar package.json que contenga "kuma" o "aggregator"
        find "$base_path" -name "package.json" -type f 2>/dev/null | while read pkg; do
            if grep -qi "kuma\|aggregator" "$pkg" 2>/dev/null; then
                DIR=$(dirname "$pkg")
                echo "   📦 Posible backend: $DIR"
                echo "      Package.json:"
                grep -i "name\|version\|description" "$pkg" | head -5
            fi
        done | head -10
    fi
done

# 3. Verificar el backend actual (el que respondió en el health check)
echo ""
echo "3. Probando backend actual..."
echo "   Health check:"
curl -s http://localhost:8080/health | head -5

echo ""
echo "   Probando ruta /api/history:"
curl -s "http://localhost:8080/api/history?limit=1" | head -3

# 4. Buscar archivos específicos de backend
echo ""
echo "4. Buscando archivos backend específicos..."

# Si tenemos un BACKEND_DIR, mostrar su contenido
if [ -n "$BACKEND_DIR" ] && [ -d "$BACKEND_DIR" ]; then
    echo "   📁 Contenido de $BACKEND_DIR:"
    ls -la "$BACKEND_DIR/" | head -10
    
    if [ -d "$BACKEND_DIR/src" ]; then
        echo "   📁 Contenido de $BACKEND_DIR/src:"
        ls -la "$BACKEND_DIR/src/" | head -10
    fi
    
    if [ -f "$BACKEND_DIR/package.json" ]; then
        echo "   📄 Package.json:"
        cat "$BACKEND_DIR/package.json" | head -20
    fi
fi

echo ""
echo "=========================================="
echo "💡 INSTRUCCIONES:"
echo ""
echo "Por favor, comparte esta información:"
echo "1. ¿Cuál es la ruta REAL de tu backend? (la que se muestra arriba)"
echo "2. ¿El backend está en un contenedor Docker o directamente en el sistema?"
echo "3. ¿Tienes acceso para modificar archivos en esa ruta?"
echo ""
echo "📋 Si no aparece claramente, ejecuta también:"
echo "   sudo netstat -tlnp | grep :8080"
echo "   sudo ps aux | grep node"
