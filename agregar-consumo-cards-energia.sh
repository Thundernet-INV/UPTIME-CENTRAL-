#!/bin/bash
# agregar-consumo-cards-energia.sh
# AGREGA CONSUMO A LAS CARDS DE LA INSTANCIA ENERGÍA

echo "====================================================="
echo "🔧 AGREGANDO CONSUMO A CARDS DE ENERGÍA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ENERGIA_FILE="$FRONTEND_DIR/src/views/Energia.jsx"

# ========== 1. VERIFICAR ARCHIVO ==========
echo ""
echo "[1] Verificando archivo..."

if [ ! -f "$ENERGIA_FILE" ]; then
    echo "❌ No se encuentra: $ENERGIA_FILE"
    # Buscar en posibles ubicaciones
    ENERGIA_FILE=$(find "$FRONTEND_DIR/src" -name "Energia.jsx" -type f | head -1)
    if [ -n "$ENERGIA_FILE" ]; then
        echo "✅ Encontrado en: $ENERGIA_FILE"
    else
        echo "❌ No se encontró Energia.jsx"
        exit 1
    fi
fi

# ========== 2. HACER BACKUP ==========
echo ""
echo "[2] Creando backup..."
cp "$ENERGIA_FILE" "$ENERGIA_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 3. AGREGAR CONSUMO A LAS CARDS ==========
echo ""
echo "[3] Agregando consumo a las cards..."

# Buscar el componente de card (probablemente InstanceCard o similar)
# Primero, veamos cómo se llama el componente que renderiza cada card
CARD_COMPONENT=$(grep -o "<[A-Za-z]*Card" "$ENERGIA_FILE" | head -1 | sed 's/<//')

if [ -n "$CARD_COMPONENT" ]; then
    echo "✅ Componente de card detectado: $CARD_COMPONENT"
    
    # Buscar el archivo del componente
    CARD_FILE=$(find "$FRONTEND_DIR/src" -name "${CARD_COMPONENT}.jsx" -type f | head -1)
    
    if [ -f "$CARD_FILE" ]; then
        echo "✅ Archivo de card encontrado: $CARD_FILE"
        
        # Hacer backup de la card
        cp "$CARD_FILE" "$CARD_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Agregar consumo a la card
        sed -i '/<div className="inst-body">/a \          <div style={{ marginTop: 8, padding: 8, background: "#f3f4f6", borderRadius: 6 }}>\n            <div style={{ fontSize: "0.7rem", color: "#4b5563", marginBottom: 4 }}>⛽ CONSUMO</div>\n            <div style={{ display: "flex", justifyContent: "space-between" }}>\n              <span style={{ fontSize: "0.8rem", color: "#065f46" }}>Sesión:</span>\n              <span style={{ fontWeight: 600, color: "#065f46" }}>\n                {(() => {\n                  try {\n                    const saved = localStorage.getItem("consumo_plantas");\n                    const data = saved ? JSON.parse(saved) : {};\n                    const nombre = instance?.nombre_monitor || instance?.name || "";\n                    return (data[nombre]?.sesionActual || 0).toFixed(2);\n                  } catch (e) {\n                    return "0.00";\n                  }\n                })()} L\n              </span>\n            </div>\n            <div style={{ display: "flex", justifyContent: "space-between", marginTop: 2 }}>\n              <span style={{ fontSize: "0.8rem", color: "#1f2937" }}>Histórico:</span>\n              <span style={{ fontWeight: 600, color: "#1f2937" }}>\n                {(() => {\n                  try {\n                    const saved = localStorage.getItem("consumo_plantas");\n                    const data = saved ? JSON.parse(saved) : {};\n                    const nombre = instance?.nombre_monitor || instance?.name || "";\n                    return (data[nombre]?.historico || 0).toFixed(2);\n                  } catch (e) {\n                    return "0.00";\n                  }\n                })()} L\n              </span>\n            </div>\n          </div>' "$CARD_FILE"
        
        echo "✅ Consumo agregado a $CARD_FILE"
    else
        echo "⚠️ No se encontró el archivo de card, modificando directamente Energia.jsx"
        
        # Modificar directamente Energia.jsx
        sed -i '/{instances.map/a \              {/* CONSUMO */}\n              {(() => {\n                try {\n                  const saved = localStorage.getItem("consumo_plantas");\n                  const data = saved ? JSON.parse(saved) : {};\n                  const nombre = inst.name;\n                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 };\n                  return (\n                    <div style={{ marginTop: 8, padding: 8, background: "#f3f4f6", borderRadius: 6 }}>\n                      <div style={{ fontSize: "0.7rem", color: "#4b5563", marginBottom: 4 }}>⛽ CONSUMO</div>\n                      <div style={{ display: "flex", justifyContent: "space-between" }}>\n                        <span style={{ fontSize: "0.8rem", color: "#065f46" }}>Sesión:</span>\n                        <span style={{ fontWeight: 600, color: "#065f46" }}>{consumo.sesionActual.toFixed(2)} L</span>\n                      </div>\n                      <div style={{ display: "flex", justifyContent: "space-between", marginTop: 2 }}>\n                        <span style={{ fontSize: "0.8rem", color: "#1f2937" }}>Histórico:</span>\n                        <span style={{ fontWeight: 600, color: "#1f2937" }}>{consumo.historico.toFixed(2)} L</span>\n                      </div>\n                    </div>\n                  );\n                } catch (e) {\n                  return null;\n                }\n              })()}' "$ENERGIA_FILE"
        
        echo "✅ Consumo agregado directamente a Energia.jsx"
    fi
else
    echo "⚠️ No se detectó componente de card, modificando Energia.jsx directamente"
    
    sed -i '/{instances.map/a \              {/* CONSUMO */}\n              {(() => {\n                try {\n                  const saved = localStorage.getItem("consumo_plantas");\n                  const data = saved ? JSON.parse(saved) : {};\n                  const nombre = inst.name;\n                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 };\n                  return (\n                    <div style={{ marginTop: 8, padding: 8, background: "#f3f4f6", borderRadius: 6 }}>\n                      <div style={{ fontSize: "0.7rem", color: "#4b5563", marginBottom: 4 }}>⛽ CONSUMO</div>\n                      <div style={{ display: "flex", justifyContent: "space-between" }}>\n                        <span style={{ fontSize: "0.8rem", color: "#065f46" }}>Sesión:</span>\n                        <span style={{ fontWeight: 600, color: "#065f46" }}>{consumo.sesionActual.toFixed(2)} L</span>\n                      </div>\n                      <div style={{ display: "flex", justifyContent: "space-between", marginTop: 2 }}>\n                        <span style={{ fontSize: "0.8rem", color: "#1f2937" }}>Histórico:</span>\n                        <span style={{ fontWeight: 600, color: "#1f2937" }}>{consumo.historico.toFixed(2)} L</span>\n                      </div>\n                    </div>\n                  );\n                } catch (e) {\n                  return null;\n                }\n              })()}' "$ENERGIA_FILE"
    
    echo "✅ Consumo agregado a Energia.jsx"
fi

# ========== 4. REINICIAR FRONTEND ==========
echo ""
echo "[4] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ CONSUMO AGREGADO A CARDS DE ENERGÍA ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA DEBERÍAS VER:"
echo "   • En el panel de admin: botón Editar recuperado"
echo "   • En la vista Energía: consumo en cada card"
echo ""
echo "🌐 Panel admin: http://10.10.31.31:8081/#/admin-plantas"
echo "🌐 Vista Energía: http://10.10.31.31:8081/#/ (haz click en Energía)"
echo ""
