#!/bin/bash
# Script para cerrar procesos Vite en 5173 y reiniciar el dev server

PORT=5173

echo "-------------------------------------------------------"
echo "🔍 Buscando procesos que usan el puerto $PORT..."
echo "-------------------------------------------------------"

PIDS=$(lsof -ti :$PORT)

if [ -z "$PIDS" ]; then
    echo "✅ No hay procesos en el puerto $PORT"
else
    echo "⚠️ Procesos encontrados en el puerto $PORT:"
    lsof -i :$PORT

    echo ""
    echo "🛑 Matando procesos..."
    for PID in $PIDS; do
        echo " - Matando PID $PID ..."
        kill -9 $PID 2>/dev/null && echo "   ✔ PID $PID terminado" || echo "   ❌ Error terminando $PID"
    done
fi

echo ""
echo "🧹 Limpiando caché de Vite..."
rm -rf node_modules/.vite
echo "✔ Caché limpiada"

echo ""
echo "🚀 Iniciando servidor de desarrollo en puerto $PORT..."
echo "-------------------------------------------------------"
npm run dev

