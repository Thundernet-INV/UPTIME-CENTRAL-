#!/bin/bash

echo "🔧 Corrigiendo error en Dashboard.jsx..."

FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/views/Dashboard.jsx"

# Backup
cp "$FILE" "${FILE}.backup"
echo "✅ Backup creado"

# Crear un archivo temporal
TEMP_FILE="${FILE}.tmp"

# Leer línea por línea y corregir
while IFS= read -r line; do
    if [[ $line =~ \<Hero[[:space:]]*$ ]]; then
        # Si la línea termina con <Hero (sin cerrar), agregar >
        echo "${line}>" >> "$TEMP_FILE"
    elif [[ $line =~ \<Hero.*\<div ]]; then
        # Si tiene <Hero y <div en la misma línea, separarlos
        echo "${line//<Hero/<Hero>}" >> "$TEMP_FILE"
    else
        echo "$line" >> "$TEMP_FILE"
    fi
done < "$FILE"

# Agregar </Hero> al final si no existe
if ! grep -q "</Hero>" "$TEMP_FILE"; then
    echo "</Hero>" >> "$TEMP_FILE"
fi

# Reemplazar archivo original
mv "$TEMP_FILE" "$FILE"

echo "✅ Corrección aplicada"
echo "🔄 Reiniciando servidor..."

cd "/home/thunder/kuma-dashboard-clean/kuma-ui"
pkill -f vite
npm run dev &

echo "✨ Listo!"
