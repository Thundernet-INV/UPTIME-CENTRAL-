#!/bin/bash
# recuperar-boton-editar-manual.sh
# RECUPERA EL BOTÓN DE EDITAR MANUALMENTE

echo "====================================================="
echo "🔧 RECUPERANDO BOTÓN DE EDITAR MANUALMENTE"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ADMIN_FILE="$FRONTEND_DIR/src/components/AdminPlantas.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$ADMIN_FILE" "$ADMIN_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. BUSCAR LA SECCIÓN DE ACCIONES ==========
echo ""
echo "[2] Buscando sección de acciones..."

# Mostrar las líneas alrededor de donde deberían estar las acciones
LINE_NUM=$(grep -n "<th>Acciones<" "$ADMIN_FILE" | cut -d: -f1)

if [ -n "$LINE_NUM" ]; then
    echo "✅ Columna 'Acciones' encontrada en línea $LINE_NUM"
    
    # Mostrar las siguientes líneas para ver qué hay
    echo ""
    echo "Líneas alrededor de acciones:"
    sed -n "$((LINE_NUM-2)),$((LINE_NUM+10))p" "$ADMIN_FILE"
    
    echo ""
    echo "¿Quieres reemplazar la columna de acciones con el botón de editar? (s/N)"
    read -p "> " RESPUESTA
    
    if [[ "$RESPUESTA" =~ ^[Ss]$ ]]; then
        # Reemplazar la celda de acciones
        sed -i '/<td>/,/<\/td>/ {
          /Acciones/! {
            /<button/ {
              s/<button.*<\/button>/<div style={{ display: "flex", gap: 4 }}>\n                    <button\n                      className="btn-agregar"\n                      onClick={() => {\n                        setPlantaEditando(planta);\n                        setShowForm(true);\n                      }}\n                      style={{ background: "#3b82f6" }}\n                    >\n                      Editar\n                    </button>\n                    <button\n                      className="btn-reset"\n                      onClick={() => resetearPlanta(planta.nombre_monitor)}\n                      disabled={isUp}\n                      title={isUp ? "No se puede resetear mientras está encendida" : "Resetear contador"}\n                    >\n                      Resetear\n                    </button>\n                  <\/div>/g
            }
          }
        }' "$ADMIN_FILE"
        
        echo "✅ Botón de editar agregado"
    fi
else
    echo "❌ No se encontró la columna 'Acciones'"
    
    # Buscar posibles lugares donde podría estar
    echo ""
    echo "Buscando posibles secciones de acciones..."
    grep -n "button" "$ADMIN_FILE" | head -20
fi

# ========== 3. AGREGAR ESTADO PARA EDITAR ==========
echo ""
echo "[3] Agregando estado para edición..."

if ! grep -q "setPlantaEditando" "$ADMIN_FILE"; then
    sed -i '/const \[consumoAcumulado, setConsumoAcumulado\]/a \ \ const [plantaEditando, setPlantaEditando] = useState(null);' "$ADMIN_FILE"
    echo "✅ Estado de edición agregado"
fi

# ========== 4. MODIFICAR EL FORMULARIO PARA EDITAR ==========
echo ""
echo "[4] Modificando formulario para soportar edición..."

# Buscar el formulario y modificar el título
sed -i 's/Agregar Nueva Planta/{plantaEditando ? `Editando: ${plantaEditando.nombre_monitor}` : "Agregar Nueva Planta"}/g' "$ADMIN_FILE"

# Modificar el submit para que sea diferente si es edición
sed -i 's/const handleSubmit = async/const handleSubmit = async (e) => {\n    e.preventDefault();\n    \n    if (plantaEditando) {\n      // Aquí iría la lógica de edición\n      alert("Función de edición próximamente");\n      setPlantaEditando(null);\n      setShowForm(false);\n      return;\n    }\n    \n    try {/g' "$ADMIN_FILE"

# ========== 5. REINICIAR FRONTEND ==========
echo ""
echo "[5] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ PROCESO COMPLETADO ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA DEBERÍAS VER EL BOTÓN 'Editar'"
echo ""
echo "🌐 Panel: http://10.10.31.31:8081/#/admin-plantas"
echo ""
