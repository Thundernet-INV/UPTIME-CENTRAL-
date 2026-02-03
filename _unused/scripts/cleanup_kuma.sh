#!/usr/bin/env bash
# cleanup_kuma.sh — Limpieza segura del proyecto React (archiva backups y residuos)
# Autor: Yael + Copilot
# Uso:
#   ./cleanup_kuma.sh [--commit-on-main] [--skip-build] [--keep-scripts]
#
#  - Por defecto crea una rama "chore/cleanup-<fecha>" con los cambios y hace push.
#  - Usa "--commit-on-main" para commitear directamente en main.
#  - Usa "--skip-build" para no ejecutar npm ci && npm run build.
#  - Usa "--keep-scripts" para NO archivar scripts de mantenimiento (fix_*, patch_*, etc.).
#
# Qué hace:
#  1) Crea carpeta _archive/ y mueve allí backups: src.bak_*, *.bak*, *.tmp*, vite.config.*.bak.*.js, vite.config.broken.*.js
#  2) (Opcional) Archiva scripts de mantenimiento a _archive/scripts_unused/
#  3) Actualiza .gitignore con reglas para evitar que vuelvan a versionarse
#  4) Crea rama/commit/push
#  5) (Opcional) Ejecuta npm ci && npm run build para validar

set -euo pipefail

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

commit_on_main=0
skip_build=0
keep_scripts=0
for arg in "$@"; do
  case "$arg" in
    --commit-on-main) commit_on_main=1 ;;
    --skip-build)     skip_build=1 ;;
    --keep-scripts)   keep_scripts=1 ;;
    -h|--help)
      echo "Uso: $0 [--commit-on-main] [--skip-build] [--keep-scripts]"; exit 0 ;;
    *) echo -e "${YELLOW}Aviso:${NC} argumento ignorado: $arg" ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}Error:${NC} git no está instalado."; exit 1
fi

if [ ! -f package.json ] || [ ! -d src ]; then
  echo -e "${RED}Error:${NC} ejecuta este script en la RAÍZ del proyecto (donde está package.json y src/)."; exit 1
fi

# Crear estructura de archivo
mkdir -p _archive/{src_baks,vite_baks,public_baks,root_misc,scripts_unused}

# Detectar si estamos en un repo git
in_git=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then in_git=1; fi

move_to(){ # $1=path $2=dest_dir
  src="$1"; dest="$2"
  mkdir -p "$dest"
  if [ $in_git -eq 1 ]; then
    git mv -f "$src" "$dest/" 2>/dev/null || mv -f "$src" "$dest/"
  else
    mv -f "$src" "$dest/"
  fi
}

count_moved=0

# 1) Mover directorios de respaldo tipo src.bak_*
for d in src.bak* src.bak_* src.bak_css* src.bak_csswarn*; do
  if [ -d "$d" ]; then
    echo -e "${YELLOW}Archivando dir:${NC} $d -> _archive/src_baks/"
    move_to "$d" _archive/src_baks
    count_moved=$((count_moved+1))
  fi
done

# 2) Mover archivos *.bak* y *.tmp* dentro de src/ (preservando estructura)
#    Creamos la ruta relativa bajo _archive/src_baks/src/...
if [ -d src ]; then
  while IFS= read -r -d '' f; do
    rel="${f#src/}"  # parte relativa
    dest_dir="_archive/src_baks/src/$(dirname "$rel")"
    echo -e "${YELLOW}Archivando bak:${NC} $f -> $dest_dir/"
    mkdir -p "$dest_dir"
    if [ $in_git -eq 1 ]; then
      git mv -f "$f" "$dest_dir/" 2>/dev/null || mv -f "$f" "$dest_dir/"
    else
      mv -f "$f" "$dest_dir/"
    fi
    count_moved=$((count_moved+1))
  done < <(find src -type f \( -name "*.bak*" -o -name "*.tmp*" \) -print0)
fi

# 3) Vite config backups
for f in vite.config.bak.*.js vite.config.broken.*.js; do
  if ls $f >/dev/null 2>&1; then
    for x in $f; do
      echo -e "${YELLOW}Archivando vite backup:${NC} $x -> _archive/vite_baks/"
      move_to "$x" _archive/vite_baks
      count_moved=$((count_moved+1))
    done
  fi
done

# 4) Residuos en raíz
for r in "kuma-ui@0.0.0" "11.8.0"; do
  if [ -e "$r" ]; then
    echo -e "${YELLOW}Archivando residuo raíz:${NC} $r -> _archive/root_misc/"
    move_to "$r" _archive/root_misc
    count_moved=$((count_moved+1))
  fi
done

# 5) public/vite.svg (mover sólo si NO está referenciado)
if [ -f public/vite.svg ]; then
  if ! grep -R "vite.svg" -n src public >/dev/null 2>&1; then
    echo -e "${YELLOW}Archivando public/vite.svg (no referenciado)${NC}"
    move_to public/vite.svg _archive/public_baks
    count_moved=$((count_moved+1))
  else
    echo -e "${GREEN}Manteniendo public/vite.svg:${NC} encontrado en el código"
  fi
fi

# 6) Scripts de mantenimiento (opcional)
if [ $keep_scripts -eq 0 ]; then
  # Patrones conservadores: mueve fix_*, patch_*, disable_*, enable_*, playlist_*, audit_*, apply_*, purge_*, force_* (sin afectar deploy_ ni rebuild_ ni set_backend ni ui-polish)
  for pat in "fix_*" "patch_*" "disable_*" "enable_*" "playlist_*" "audit_*" "apply_*" "purge_*" "force_*"; do
    if ls $pat >/dev/null 2>&1; then
      for s in $pat; do
        # Excluir algunos útiles frecuentes
        case "$s" in
          deploy_*|rebuild_*|set_backend_*|ui-polish-pro.sh|cleanup_vite_port.sh) continue ;;
        esac
        if [ -f "$s" ]; then
          echo -e "${YELLOW}Archivando script:${NC} $s -> _archive/scripts_unused/"
          move_to "$s" _archive/scripts_unused
          count_moved=$((count_moved+1))
        fi
      done
    fi
  done
fi

# 7) Actualizar .gitignore (si faltan reglas)
add_ignore_rule(){
  rule="$1"
  if [ ! -f .gitignore ] || ! grep -Fxq "$rule" .gitignore; then
    echo "$rule" >> .gitignore
    echo -e "${GREEN}Añadida regla .gitignore:${NC} $rule"
  fi
}

touch .gitignore
add_ignore_rule "node_modules/"
add_ignore_rule "dist/"
add_ignore_rule "build/"
add_ignore_rule "coverage/"
add_ignore_rule ".vscode/"
add_ignore_rule ".idea/"
add_ignore_rule ".env"
add_ignore_rule ".env.*"
add_ignore_rule "*.bak"
add_ignore_rule "*.bak.*"
add_ignore_rule "*.tmp"
add_ignore_rule "src.bak*/"
add_ignore_rule "src.bak_*/"
add_ignore_rule "src.bak_css*/"
add_ignore_rule "src.bak_csswarn*/"
add_ignore_rule "_archive/"

# 8) Git: crear rama / commitear / push
if [ $in_git -eq 1 ]; then
  # Detectar rama actual
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
  target_branch="main"
  if [ $commit_on_main -eq 1 ]; then
    echo -e "${YELLOW}Commiteando directamente en main (por solicitud)${NC}"
    [ "$current_branch" != "main" ] && git checkout main || true
    git add -A
    git commit -m "chore: archivar backups y residuos; actualizar .gitignore"
    git push
  else
    new_branch="chore/cleanup-$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}Creando rama:${NC} $new_branch"
    git checkout -b "$new_branch"
    git add -A
    git commit -m "chore: archivar backups (*.bak, *.tmp, src.bak*), vite baks y .gitignore"
    git push -u origin "$new_branch"
    echo -e "${GREEN}Rama subida:${NC} $new_branch\nCrea un Pull Request cuando quieras unirlo a main."
  fi
else
  echo -e "${YELLOW}Aviso:${NC} no estás en un repo git; se movieron archivos en el FS, pero no hay commit."
fi

# 9) Build (opcional)
if [ $skip_build -eq 0 ]; then
  if command -v npm >/dev/null 2>&1; then
    echo -e "${YELLOW}Instalando dependencias y construyendo...${NC}"
    (npm ci || npm install)
    npm run build
    echo -e "${GREEN}Build OK.${NC}"
  else
    echo -e "${YELLOW}npm no encontrado; saltando build.${NC}"
  fi
else
  echo -e "${YELLOW}Build saltado por --skip-build${NC}"
fi

# 10) Resumen
echo -e "\n${GREEN}Limpieza completada.${NC} Archivos/directorios archivados: $count_moved"

echo -e "\nSiguientes pasos recomendados:"
echo "  1) Revisa _archive/ por si quieres recuperar algo."
echo "  2) Valida la app con 'npm run dev' y pruebas manuales."
echo "  3) Si todo está bien, puedes borrar _archive/ en otro commit."
