#!/usr/bin/env bash
# subir_github.sh — Sube un proyecto existente a un repositorio GitHub
# Uso rápido:
#   ./subir_github.sh -r https://github.com/USUARIO/REPO.git -u "Tu Nombre" -e "tu@email.com" -m "primer commit"
# Requisitos: git instalado y acceso al repo (token si GitHub lo pide)

set -euo pipefail

# Colores
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

usage(){
  cat <<USAGE
Uso: $0 -r <repo_url> [-u <user_name>] [-e <user_email>] [-m <mensaje>] [-b <branch>]

Parámetros:
  -r  URL del repositorio remoto (por ej. https://github.com/Thundernet-INV/UPTIME-CENTRAL-.git)
  -u  Nombre de usuario para commits (si no se pasa, se preguntará)
  -e  Email para commits (si no se pasa, se preguntará)
  -m  Mensaje de commit inicial (por defecto: "subida inicial")
  -b  Nombre de rama (por defecto: main)

Ejemplo:
  $0 -r https://github.com/usuario/mi-repo.git -u "Juan Perez" -e "juan@example.com" -m "primer commit" -b main
USAGE
}

# Verificar git
if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}Error:${NC} git no está instalado. Instálalo y vuelve a intentar." >&2
  exit 1
fi

REPO_URL=""; GIT_USER=""; GIT_EMAIL=""; COMMIT_MSG="subida inicial"; BRANCH="main"

while getopts ":r:u:e:m:b:h" opt; do
  case $opt in
    r) REPO_URL="$OPTARG" ;;
    u) GIT_USER="$OPTARG" ;;
    e) GIT_EMAIL="$OPTARG" ;;
    m) COMMIT_MSG="$OPTARG" ;;
    b) BRANCH="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) echo -e "${RED}Falta valor para -$OPTARG${NC}"; usage; exit 1 ;;
    \?) echo -e "${RED}Opción inválida -$OPTARG${NC}"; usage; exit 1 ;;
  esac
done

if [[ -z "$REPO_URL" ]]; then
  echo -e "${RED}Debes indicar la URL del repositorio con -r${NC}"; usage; exit 1
fi

# Pedir nombre/email si faltan (config local del repo)
if [[ -z "${GIT_USER}" ]]; then
  read -rp "Nombre para commits (user.name): " GIT_USER
fi
if [[ -z "${GIT_EMAIL}" ]]; then
  read -rp "Email para commits (user.email): " GIT_EMAIL
fi

# Inicializar repo si no existe .git
if [[ ! -d .git ]]; then
  echo -e "${YELLOW}Inicializando repositorio Git...${NC}"
  git init >/dev/null
fi

# Config local (no --global para no tocar otros repos)
 git config user.name "$GIT_USER"
 git config user.email "$GIT_EMAIL"

# Crear .gitignore si no existe
if [[ ! -f .gitignore ]]; then
  cat > .gitignore <<IGN
# Dependencias
node_modules/
# Builds
build/
dist/
.next/
coverage/
# Entornos
.env
.env.*
# SO / editor
.DS_Store
Thumbs.db
.vscode/
.idea/
IGN
  echo -e "${GREEN}Creado .gitignore por defecto${NC}"
fi

# Añadir y commitear
echo -e "${YELLOW}Agregando archivos...${NC}"
 git add -A

# Evitar commit vacío
if ! git diff --cached --quiet; then
  git commit -m "$COMMIT_MSG" >/dev/null || true
  echo -e "${GREEN}Commit creado:${NC} $COMMIT_MSG"
else
  echo -e "${YELLOW}No hay cambios para commitear (quizá ya hiciste un commit).${NC}"
fi

# Renombrar rama a BRANCH
current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [[ "$current_branch" != "$BRANCH" && -n "$current_branch" ]]; then
  git branch -M "$BRANCH"
fi
if [[ -z "$current_branch" ]]; then
  git checkout -b "$BRANCH" >/dev/null
fi

echo -e "${YELLOW}Configurando remoto 'origin'...${NC}"
if git remote | grep -q "^origin$"; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

# Push
echo -e "${YELLOW}Enviando a remoto... (puede pedir usuario y token)${NC}"
set +e
 git push -u origin "$BRANCH"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  cat <<HELP
${RED}El push falló.${NC}
Posibles causas:
  • No tienes permisos sobre el repo
  • Falta autenticación con Token Personal de Acceso (PAT)

Para crear un token:
  1) Ve a GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
  2) Generate new token → marca 'repo' y establece expiración
  3) Copia el token y úsalo como contraseña cuando git lo pida

También puedes guardar credenciales:
  git config --global credential.helper store
  # Luego repite el push y se guardarán en ~/.git-credentials
HELP
  exit $status
fi

echo -e "\n${GREEN}¡Listo! Proyecto subido a ${REPO_URL} en la rama ${BRANCH}.${NC}"
