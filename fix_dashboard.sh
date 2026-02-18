#!/bin/bash

# fix_dashboard.sh - Script para corregir el error de sintaxis en Dashboard.jsx

FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/views/Dashboard.jsx"

if [ ! -f "$FILE" ]; then
    echo "❌ Error: No se encontró el archivo $FILE"
    exit 1
fi

# Crear backup
cp "$FILE" "${FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# Verificar la línea 460 y alrededores
echo "📋 Contenido alrededor de la línea 460:"
sed -n '455,465p' "$FILE"

echo ""
echo "🔍 Análisis del error:"
echo "   El problema es que falta un 'return' o hay un '}' mal colocado"
echo "   antes de la etiqueta <section> en la línea 462."

echo ""
echo "💡 Soluciones posibles:"

echo ""
echo "OPCIÓN 1: Si falta el return después de un condicional"
echo "   Busca algo como:"
echo '     if (condicion) {'
echo '       return <Algo />;'
echo '     }'
echo '     <section...>  ← ERROR'
echo ""
echo "   Debe ser:"
echo '     if (condicion) {'
echo '       return <Algo />;'
echo '     }'
echo '     return ('
echo '       <section...>'

echo ""
echo "OPCIÓN 2: Si hay un return ( abierto sin cerrar"
echo "   Busca:"
echo '     return ('
echo '       <div>...</div>'
echo '     }  ← cierra con } en lugar de )'
echo ""
echo "   Debe ser:"
echo '     return ('
echo '       <div>...</div>'
echo '     );'

echo ""
echo "🛠️  Para corregir automáticamente el caso más común (falta return):"

# Detectar si hay un patrón típico del error
if sed -n '458,462p' "$FILE" | grep -q "}$" && sed -n '462p' "$FILE" | grep -q "^[[:space:]]*<section"; then
    echo "   Detectado patrón: '}' seguido de '<section'"
    echo ""
    read -p "¿Agregar 'return (' después de la línea 460? (s/n): " respuesta
    
    if [ "$respuesta" = "s" ]; then
        # Insertar return ( después de la línea 460
        sed -i '460a\
\
      return (' "$FILE"
        
        # Buscar dónde cerrar el return ) - buscar el cierre del componente
        # Esto es aproximado, necesitarás ajustar manualmente
        echo "⚠️  Se agregó 'return (' después de la línea 460."
        echo "   DEBES agregar manualmente el cierre ');' al final del JSX"
    fi
else
    echo "   No se detectó el patrón específico. Revisa manualmente el archivo."
fi

echo ""
echo "📁 Archivo: $FILE"
echo "📝 Abre el archivo y busca la línea 460-462 para corregir manualmente"
echo ""
echo "Comando para editar:"
echo "   code $FILE  # VS Code"
echo "   vim $FILE   # Vim"
echo "   nano $FILE  # Nano"
