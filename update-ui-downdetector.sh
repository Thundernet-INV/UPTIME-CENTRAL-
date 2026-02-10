#!/bin/bash

CSS_FILE="src/styles.css"
BACKUP_FILE="src/styles.css.bak"

echo "➡️ Verificando archivo CSS…"

# 1. Validar existencia del CSS
if [ ! -f "$CSS_FILE" ]; then
  echo "❌ ERROR: No se encontró $CSS_FILE"
  exit 1
fi

# 2. Crear backup
if [ ! -f "$BACKUP_FILE" ]; then
  echo "📦 Creando backup en $BACKUP_FILE"
  cp "$CSS_FILE" "$BACKUP_FILE"
else
  echo "ℹ️ Ya existe un backup previo, no se sobrescribe."
fi

echo "🛠 Aplicando fixes para hero-search (borders perfectos)…"

# 3. Añadir overflow:hidden a .hero-search si no existe
if grep -q "overflow: hidden" "$CSS_FILE"; then
  echo "ℹ️ 'overflow:hidden' ya existe en .hero-search"
else
  echo "🔧 Insertando 'overflow:hidden' en .hero-search"
  sed -i '/\.hero-search[[:space:]]*{/a\ \ \ overflow: hidden;' "$CSS_FILE"
fi

# 4. Añadir reglas de SearchBar si faltan
NEEDED_RULES=$(cat << 'EOF'
/* --- FIX SEARCHBAR (UPTIME-CENTRAL) --- */

.hero-search-form {
  display: flex;
  width: 100%;
}

.hero-search-input {
  flex: 1;
  border: none;
  outline: none;
  padding: 12px 18px;
  border-radius: 999px 0 0 999px;
  font-size: 0.95rem;
}

.hero-search-button {
  border: none;
  padding: 0 24px;
  border-radius: 999px;
  font-size: 0.9rem;
  font-weight: 600;
  background: #ff4a4a;
  color: #fff;
  cursor: pointer;
}

EOF
)

if grep -q "FIX SEARCHBAR (UPTIME-CENTRAL)" "$CSS_FILE"; then
  echo "ℹ️ Reglas de SearchBar ya estaban instaladas."
else
  echo "🔧 Insertando reglas nuevas del SearchBar…"
  printf "\n%s\n" "$NEEDED_RULES" >> "$CSS_FILE"
fi

echo "✅ PROCESO COMPLETADO con éxito."
echo "👉 Si algo se dañó, puedes restaurar así:"
echo "cp $BACKUP_FILE $CSS_FILE"
