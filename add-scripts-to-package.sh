#!/bin/bash
echo "📝 AGREGANDO SCRIPTS A PACKAGE.JSON..."
echo "======================================"

BACKEND_ROOT="/opt/kuma-central/kuma-aggregator"
PACKAGE_JSON="$BACKEND_ROOT/package.json"

# Hacer backup
cp "$PACKAGE_JSON" "$PACKAGE_JSON.backup.before_scripts.$(date +%s)"

# Crear nuevo package.json con scripts
cat > "$PACKAGE_JSON" << 'EOF'
{
  "name": "kuma-aggregator",
  "type": "module",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/index.js",
    "dev": "node src/index.js",
    "test": "echo \"No tests specified\" && exit 0"
  },
  "dependencies": {
    "axios": "^1.6.0",
    "compression": "^1.8.1",
    "cors": "^2.8.6",
    "dotenv": "^17.2.4",
    "express": "^4.22.1",
    "helmet": "^8.1.0",
    "morgan": "^1.10.1",
    "sqlite3": "^5.1.7"
  }
}
EOF

echo "✅ package.json actualizado con scripts"
echo ""
echo "Nuevo package.json:"
cat "$PACKAGE_JSON"
echo ""
echo "======================================"
