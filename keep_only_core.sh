#!/usr/bin/env bash
# keep_only_core.sh — Deja solo lo esencial del proyecto y borra el resto.
# Uso:
#   ./keep_only_core.sh --dry-run         # simula (no borra)
#   ./keep_only_core.sh --keep-dist       # conserva dist/
#   ./keep_only_core.sh --yes             # ejecuta sin pedir confirmación
#   ./keep_only_core.sh --keep-sh="deploy_*,rebuild_*,set_backend_*,ui-polish-pro.sh,cleanup_vite_port.sh"
#
# Nota: borra usando 'git rm' si el repo está bajo Git; sino 'rm -rf'.

set -euo pipefail
Y='\033[1;33m'; G='\033[0;32m'; R='\033[0;31m'; N='\033[0m'

dry_run=0
keep_dist=0
assume_yes=0
keep_sh_patterns="deploy_*,rebuild_*,set_backend_*,ui-polish-pro.sh,cleanup_vite_port.sh"

for arg in "$@"; do
  case "$arg" in
    --dry-run)   dry_run=1 ;;
    --keep-dist) keep_dist=1 ;;
    --yes|-y)    assume_yes=1 ;;
    --keep-sh=*) keep_sh_patterns="${arg#*=}" ;;
    -h|--help)
      cat <<HLP
Uso: $0 [--dry-run] [--keep-dist] [--yes] [--keep-sh="glob1,glob2"]
Deja sólo: package.json, package-lock.json, vite.config.js, index.html, src/, public/, .gitignore, README.md
Borra: _archive/, _unused/, herramientas de auditoría, backups de vite, 'vite/' residual, .sh no esenciales, dist/ (salvo --keep-dist)
HLP
      exit 0 ;;
    *) echo -e "${Y}Aviso:${N} argumento ignorado: $arg" ;;
  esac
done

run(){ if [ $dry_run -eq 1 ]; then echo "+ $*"; else eval "$*"; fi }

# Verificaciones rápidas
[ -f package.json ] || { echo -e "${R}Error:${N} no encuentro package.json aquí."; exit 1; }
[ -d src ] || { echo -e "${R}Error:${N} no encuentro src/. Ejecuta en la raíz del proyecto."; exit 1; }

# ¿Repo git?
in_git=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then in_git=1; fi

rm_path(){ p="$1"; if [ $in_git -eq 1 ]; then run "git rm -rf --ignore-unmatch -- '$p'"; else run "rm -rf -- '$p'"; fi; }
keep_msg(){ printf "${G}Manteniendo:${N} %s\n" "$1"; }
del_msg(){  printf "${Y}Eliminando:${N} %s\n" "$1"; }

echo -e "${Y}=== Vista previa de limpieza (archivos a eliminar) ===${N}"

# 1) Depósitos de limpieza y reportes/herramientas de auditoría
targets=( "_archive" "_unused" "tools/usage-graph.mjs" "usage-graph.json" "prune_report_*.txt" "vite.config.bak.*.js" "vite.config.broken.*.js" "vite" )
for t in "${targets[@]}"; do
  if ls -d $t >/dev/null 2>&1; then
    del_msg "$t"
  fi
done

# 2) dist/ (se regenera) salvo --keep-dist
if [ -d dist ]; then
  if [ $keep_dist -eq 1 ]; then
    keep_msg "dist/ (con --keep-dist)"
  else
    del_msg "dist/ (se regenera con npm run build)"
  fi
fi

# 3) Scripts .sh: mantiene los que coincidan con keep_sh_patterns
#    Concatena patrón a patrón.
IFS=',' read -r -a keep_globs <<< "$keep_sh_patterns"
kept_sh=()
del_sh=()
if compgen -G "*.sh" >/dev/null 2>&1; then
  for s in *.sh; do
    keep=0
    for g in "${keep_globs[@]}"; do
      [[ "$s" == $g ]] && keep=1 && break
    done
    if [ $keep -eq 1 ]; then kept_sh+=("$s"); else del_sh+=("$s"); fi
  done
fi

for s in "${kept_sh[@]:-}"; do keep_msg "$s"; done
for s in "${del_sh[@]:-}";  do del_msg  "$s"; done

# Confirmación (si no --yes)
if [ $assume_yes -eq 0 ]; then
  echo
  read -r -p "¿Proceder con la limpieza? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES) : ;;
    *) echo "Cancelado."; exit 0 ;;
  esac
fi

echo -e "${Y}=== Ejecutando limpieza ===${N}"

# Ejecuta eliminaciones
# 1) depósitos y herramientas
for t in "${targets[@]}"; do
  if ls -d $t >/dev/null 2>&1; then rm_path "$t"; fi
done

# 2) dist/
if [ -d dist ] && [ $keep_dist -eq 0 ]; then rm_path "dist"; fi

# 3) .sh a eliminar (uno a uno)
for f in "${del_sh[@]:-}"; do rm_path "$f"; done

# 4) Recordatorio: NUNCA borrar lo esencial
echo -e "${G}Listo.${N} Conservados: package.json, package-lock.json, vite.config.js, index.html, src/, public/, .gitignore, README.md"
if [ $keep_dist -eq 0 ]; then
  echo "Recuerda: genera dist/ con 'npm run build' cuando lo necesites."
fi

# Commit
if [ $in_git -eq 1 ] && [ $dry_run -eq 0 ]; then
  run "git add -A"
  run "git commit -m 'chore: keep only core (remove archives, auditor tools, vite backups, non-core .sh, dist)'"
  run "git push"
fi
