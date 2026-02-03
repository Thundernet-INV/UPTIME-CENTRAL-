#!/usr/bin/env bash
# prune_unused_kuma_v3.sh — Prune agresivo (código/assets/.sh) + barrido de backups
# -------------------------------------------------------------------------------------------------
# Cambios vs v2:
#  • Arreglado error de doble declaración en usage-graph.mjs (assetExts/arrays duplicados)
#  • Detección de .sh "usados" más estricta: SOLO package.json y otros .sh (por defecto)
#    - Opcional: --include-readme para contar menciones en README*.md
#  • Pre‑barrido de backups/residuos activado por defecto (puedes desactivar con --no-sweep-backups)
#    - Elimina: src.bak*, src.bak_css*, src.bak_csswarn*, *.bak*, *.tmp*, vite.config.bak.*.js, vite.config.broken.*.js,
#               residuos raíz conocidos (kuma-ui@0.0.0, 11.8.0)
#  • Soporta: --delete (default) | --archive, --dry-run, --backup-tar, --commit-on-main, --keep-scripts,
#             --keep-patterns="glob1,glob2", --no-sweep-backups
# -------------------------------------------------------------------------------------------------
set -euo pipefail
Y='\033[1;33m'; G='\033[0;32m'; R='\033[0;31m'; N='\033[0m'

mode_delete=1
dry_run=0
backup_tar=0
commit_on_main=0
keep_scripts=0
keep_patterns_csv=""
include_readme=0
sweep_backups=1

for arg in "$@"; do
  case "$arg" in
    --archive)            mode_delete=0 ;;
    --delete)             mode_delete=1 ;;
    --dry-run)            dry_run=1 ;;
    --backup-tar)         backup_tar=1 ;;
    --commit-on-main)     commit_on_main=1 ;;
    --keep-scripts)       keep_scripts=1 ;;
    --keep-patterns=*)    keep_patterns_csv="${arg#*=}" ;;
    --include-readme)     include_readme=1 ;;
    --no-sweep-backups)   sweep_backups=0 ;;
    -h|--help)
      cat <<HLP
Uso: $0 [--delete|--archive] [--dry-run] [--backup-tar] [--commit-on-main] [--keep-scripts] \
         [--keep-patterns="glob1,glob2"] [--include-readme] [--no-sweep-backups]
HLP
      exit 0 ;;
    *) echo -e "${Y}Aviso:${N} argumento ignorado: $arg" ;;
  esac
done

# Preflight
[ -f package.json ] || { echo -e "${R}Error:${N} No encuentro package.json. Ejecuta en la raíz del proyecto."; exit 1; }
[ -d src ] || { echo -e "${R}Error:${N} No encuentro src/. Ejecuta en la raíz del proyecto."; exit 1; }
command -v node >/dev/null 2>&1 || { echo -e "${R}Error:${N} Node.js no está instalado."; exit 1; }
if ! command -v jq >/dev/null 2>&1; then
  echo -e "${R}Falta jq${N}: instala con -> sudo apt-get update && sudo apt-get install -y jq"
  exit 1
fi

# Detección de git
in_git=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then in_git=1; fi

run(){ if [ $dry_run -eq 1 ]; then echo "+ $*"; else eval "$*"; fi }
exists(){ ls $1 >/dev/null 2>&1 ; }

stamp=$(date +%Y%m%d_%H%M%S)
report="prune_report_${stamp}.txt"
action_word=$([ $mode_delete -eq 1 ] && echo "ELIMINAR" || echo "ARCHIVAR")

# 0) Backup opcional
if [ $backup_tar -eq 1 ]; then
  bk="backup_before_prune_${stamp}.tar.gz"
  echo -e "${Y}Creando backup${N}: $bk"
  run "tar -czf '$bk' --exclude=node_modules --exclude=.git --exclude=dist --exclude=build ."
fi

# 1) Pre‑barrido de backups/residuos (opcional)
rm_path(){ p="$1"; if [ $in_git -eq 1 ]; then run "git rm -rf --ignore-unmatch '$p'"; else run "rm -rf '$p'"; fi }
move_path(){ src="$1" dest="$2"; mkdir -p "$dest"; if [ $in_git -eq 1 ]; then run "git mv -f '$src' '$dest/' 2>/dev/null || mv -f '$src' '$dest/'"; else run "mv -f '$src' '$dest/'"; fi }

if [ $sweep_backups -eq 1 ]; then
  echo -e "${Y}Barrido inicial de backups/residuos...${N}"
  # Directorios src.bak*
  for d in src.bak* src.bak_* src.bak_css* src.bak_csswarn*; do
    exists "$d" && rm_path "$d" || true
  done
  # Archivos *.bak* y *.tmp* en raíz y src
  run "find . -maxdepth 1 -type f \( -name '*.bak*' -o -name '*.tmp*' \) -print0 | xargs -0 -r rm -f"
  run "find src -type f \( -name '*.bak*' -o -name '*.tmp*' \) -print0 | xargs -0 -r rm -f"
  # Vite backups
  exists 'vite.config.bak.*.js' && rm_path vite.config.bak.*.js || true
  exists 'vite.config.broken.*.js' && rm_path vite.config.broken.*.js || true
  # Residuos raíz conocidos
  for r in "kuma-ui@0.0.0" "11.8.0"; do
    [ -e "$r" ] && rm_path "$r" || true
  done
fi

# 2) Analizador Node (corregido, sin dobles declaraciones)
mkdir -p tools
ANALYZER=tools/usage-graph.mjs
cat > "$ANALYZER" <<'NODE'
import fs from 'fs';
import path from 'path';

const root = process.cwd();
const SRC = path.join(root, 'src');
const PUBLIC = path.join(root, 'public');
const CODE_EXTS = new Set(['.js','.jsx','.ts','.tsx','.css']);
const ASSET_EXTS = new Set(['.png','.jpg','.jpeg','.svg','.webp','.gif','.ico']);

const read = (p)=>{ try { return fs.readFileSync(p,'utf8'); } catch { return ''; } };
const isCode = (p)=> CODE_EXTS.has(path.extname(p));
const isAsset= (p)=> ASSET_EXTS.has(path.extname(p));

function walk(dir, list=[]) {
  for (const e of fs.readdirSync(dir, {withFileTypes:true})){
    if (['node_modules','.git','dist','build','coverage','_unused','_archive'].includes(e.name)) continue;
    const p = path.join(dir,e.name);
    if (e.isDirectory()) walk(p,list); else list.push(p);
  }
  return list;
}

const files = [];
if (fs.existsSync(SRC)) walk(SRC, files);
if (fs.existsSync(PUBLIC)) walk(PUBLIC, files);

const codeFiles = files.filter(isCode);
const assets    = files.filter(isAsset);
const rel = (p)=> p.replace(root+path.sep,'').replace(/\\/g,'/');

const reImports = [
  /import\s+[^'"\n]*?from\s*['"]([^'"]+)['"]/g,
  /import\s*\(\s*['"]([^'"]+)['"]\s*\)/g,
  /require\(\s*['"]([^'"]+)['"]\s*\)/g,
  /@import\s+['"]([^'"]+)['"]/g
];

function resolveImport(fromFile, spec){
  if (!spec) return null;
  if (!spec.startsWith('.')) return null; // ignorar paquetes externos
  const base = path.resolve(path.dirname(fromFile), spec);
  const candidates = [
    base,
    base+'.js', base+'.jsx', base+'.ts', base+'.tsx', base+'.css',
    path.join(base,'index.js'), path.join(base,'index.jsx'), path.join(base,'index.tsx'), path.join(base,'index.ts'), path.join(base,'index.css')
  ];
  for (const c of candidates){ try { if (fs.statSync(c).isFile()) return c; } catch {} }
  return null;
}

// Grafo to<-froms (quién importa a quién)
const graph = new Map(codeFiles.map(f=>[f, new Set()]));
for (const f of codeFiles){
  const s = read(f);
  for (const re of reImports){
    let m; while ((m = re.exec(s))){
      const imp = m[1];
      const res = resolveImport(f, imp);
      if (res && graph.has(res)) graph.get(res).add(f);
    }
  }
}

// Raíces probables
const likelyRoots = new Set();
for (const f of codeFiles){
  const r = rel(f);
  if (/^src\/(main|index)\.(j|t)sx?$/.test(r)) likelyRoots.add(f);
  if (/^src\/App\.(j|t)sx?$/.test(r))        likelyRoots.add(f);
}
if (likelyRoots.size===0){
  for (const f of codeFiles){ if (/main|index\.(j|t)sx?$/.test(f)){ likelyRoots.add(f); break; } }
}

// Alcanzables por DFS desde roots
const reachable = new Set([...likelyRoots]);
function dfs(n){
  for (const [to, froms] of graph.entries()){
    if (froms.has(n) && !reachable.has(to)) { reachable.add(to); dfs(to); }
  }
}
for (const r of likelyRoots) dfs(r);

// Assets referenciados por nombre o ruta relativa en código e index.html
const bigBlob = codeFiles.map(read).join('\n') + (fs.existsSync('index.html')? read('index.html') : '');
const referencedAssets = new Set();
for (const a of assets){
  const name = path.basename(a);
  const pRel = rel(a);
  if (bigBlob.includes(name) || bigBlob.includes(pRel)) referencedAssets.add(a);
}
// Caso especial logos mapeados por src/lib/logoUtil.js
const logoUtil = path.join(SRC,'lib','logoUtil.js');
if (fs.existsSync(logoUtil)){
  const s = read(logoUtil);
  for (const a of assets){
    const name = path.basename(a);
    if (/logos\//.test(rel(a)) && s.includes(name)) referencedAssets.add(a);
  }
}

const unusedCode = codeFiles.filter(f => !reachable.has(f));
const unusedAssets = assets.filter(a => !referencedAssets.has(a));

const out = {
  roots: [...[...likelyRoots].map(rel)],
  reachable: [...[...reachable].map(rel)],
  unusedCode: unusedCode.map(rel),
  unusedAssets: unusedAssets.map(rel)
};
console.log(JSON.stringify(out,null,2));
NODE

# 3) Ejecutar analizador
node "$ANALYZER" > usage-graph.json

# 4) Scripts .sh no usados (solo referencias en package.json y otros .sh; opcional README)
sh_used_tmp=".sh_used_${stamp}.txt"; :> "$sh_used_tmp"
SH_SOURCES=(package.json *.sh)
if [ $include_readme -eq 1 ]; then
  SH_SOURCES+=(README.md README.MD README.markdown README*.md)
fi

if compgen -G "*.sh" > /dev/null; then
  for s in *.sh; do
    [ "$s" = "prune_unused_kuma_v3.sh" ] && continue
    # excluir auto-referencia
    refs=$(grep -RIn --exclude="$s" --exclude-dir=node_modules --exclude-dir=.git --exclude=dist --exclude=build --exclude=_unused --exclude=_archive -e "$s" ${SH_SOURCES[@]} 2>/dev/null | wc -l || true)
    if [ "$refs" -gt 0 ]; then echo "$s" >> "$sh_used_tmp"; fi
  done
fi

# 5) keep-patterns
keep_globs=()
IFS=',' read -r -a keep_globs <<< "$keep_patterns_csv"

is_kept(){
  local f="$1"
  for g in "${keep_globs[@]}"; do
    [ -z "$g" ] && continue
    if [[ "$f" == $g ]]; then return 0; fi
  done
  return 1
}

# 6) Cargar listas
unused_code_list=$(jq -r '.unusedCode[]?' usage-graph.json)
unused_assets_list=$(jq -r '.unusedAssets[]?' usage-graph.json)

# 7) .sh no usados
unused_sh_list=""
if [ $keep_scripts -eq 0 ] && compgen -G "*.sh" > /dev/null; then
  for s in *.sh; do
    [ "$s" = "prune_unused_kuma_v3.sh" ] && continue
    if grep -Fxq "$s" "$sh_used_tmp" 2>/dev/null; then continue; fi
    unused_sh_list+="$s\n"
  done
fi

mkdir -p _unused/{code,assets,scripts}

log(){ echo -e "$1" | tee -a "$report" >/dev/null; }
log "=== PRUNE REPORT ${stamp} ==="
log "Modo: $([ $mode_delete -eq 1 ] && echo DELETE || echo ARCHIVE)  |  dry-run: $dry_run  | keep-scripts: $keep_scripts  | sweep-backups: $sweep_backups"

count=0

# Funciones finales (usan git si hay)
rm_final(){ p="$1"; if [ $in_git -eq 1 ]; then run "git rm -rf --ignore-unmatch '$p'"; else run "rm -rf '$p'"; fi }
move_final(){ src="$1" dest="$2"; mkdir -p "$dest"; if [ $in_git -eq 1 ]; then run "git mv -f '$src' '$dest/' 2>/dev/null || mv -f '$src' '$dest/'"; else run "mv -f '$src' '$dest/'"; fi }

# Código
if [ -n "$unused_code_list" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_kept "$f" && continue
    if [ $mode_delete -eq 1 ]; then rm_final "$f"; else move_final "$f" _unused/code; fi
    echo "$action_word CODE: $f" | tee -a "$report"; count=$((count+1))
  done <<< "$unused_code_list"
fi

# Assets
if [ -n "$unused_assets_list" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_kept "$f" && continue
    base=$(basename "$f"); case "$base" in favicon.*|manifest.*) continue ;; esac
    if [ $mode_delete -eq 1 ]; then rm_final "$f"; else move_final "$f" _unused/assets; fi
    echo "$action_word ASSET: $f" | tee -a "$report"; count=$((count+1))
  done <<< "$unused_assets_list"
fi

# Scripts
if [ -n "$unused_sh_list" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_kept "$f" && continue
    if [ $mode_delete -eq 1 ]; then rm_final "$f"; else move_final "$f" _unused/scripts; fi
    echo "$action_word SH: $f" | tee -a "$report"; count=$((count+1))
  done <<< "$unused_sh_list"
fi

echo -e "${G}Total afectados:${N} $count" | tee -a "$report"

# Commit & push
if [ $dry_run -eq 0 ] && [ $in_git -eq 1 ]; then
  if [ $commit_on_main -eq 1 ]; then
    run "git checkout main || true"
    run "git add -A"
    run "git commit -m 'chore: prune v3 (codigo/assets/scripts) + barrido de backups'" || true
    run "git push"
  else
    branch="chore/prune-v3-${stamp}"
    run "git checkout -b '$branch'"
    run "git add -A"
    run "git commit -m 'chore: prune v3 (codigo/assets/scripts) + barrido de backups'" || true
    run "git push -u origin '$branch'"
    echo -e "${G}Rama subida:${N} $branch (abre PR para fusionar)"
  fi
fi

# Sugerencia: prueba local
echo -e "\n${Y}Sugerencia:${N} corre 'npm run build' y 'npm run dev' para validar tras el prune."

echo -e "${G}Reporte:${N} $report"
