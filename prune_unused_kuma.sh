#!/usr/bin/env bash
# prune_unused_kuma.sh — Elimina TODO lo que no use el proyecto (código, assets y .sh)
# -------------------------------------------------------------------------------------------------
# Propósito: Borrar (o archivar) cualquier archivo que NO esté referenciado por la app ni por scripts.
# Qué detecta como "USADO":
#   • Código/estilos importados transitivamente desde src/main|index.(js|jsx|ts|tsx) y App.* (DFS)
#   • Assets referenciados por nombre o ruta dentro del código / index.html (incluye logoUtil)
#   • Scripts .sh referenciados en package.json, otros .sh, README.md u otros archivos del repo
#
# ❗ Limitaciones: si generas rutas dinámicas (p.ej., `const p = "./"+n+".svg"`) puede haber falsos positivos.
#    Usa --keep-patterns o añade al whitelist si algo marcado como "no usado" en realidad sí lo es.
#
# Modos:
#   --delete (por defecto)  → Borra definitivamente (FS + Git) los no usados
#   --archive               → Mueve los no usados a _unused/ para revisión
#   --dry-run               → Solo muestra lo que haría
#   --backup-tar            → Crea backup .tar.gz antes de cambios (excluye node_modules, .git)
#   --commit-on-main        → Commit/push directo a main (por defecto crea rama chore/prune-*)
#   --keep-scripts          → No toca archivos .sh
#   --keep-patterns "glob1,glob2" → Patrón(es) a excluir del borrado (ej: "public/logos/*,deploy_*.sh")
# -------------------------------------------------------------------------------------------------
set -euo pipefail
Y='\033[1;33m'; G='\033[0;32m'; R='\033[0;31m'; N='\033[0m'

mode_delete=1
dry_run=0
backup_tar=0
commit_on_main=0
keep_scripts=0
keep_patterns_csv=""

for arg in "$@"; do
  case "$arg" in
    --archive)        mode_delete=0 ;;
    --delete)         mode_delete=1 ;;
    --dry-run)        dry_run=1 ;;
    --backup-tar)     backup_tar=1 ;;
    --commit-on-main) commit_on_main=1 ;;
    --keep-scripts)   keep_scripts=1 ;;
    --keep-patterns=*) keep_patterns_csv="${arg#*=}" ;;
    -h|--help)
      cat <<HLP
Uso: $0 [--delete|--archive] [--dry-run] [--backup-tar] [--commit-on-main] [--keep-scripts] [--keep-patterns="glob1,glob2"]
HLP
      exit 0 ;;
    *) echo -e "${Y}Aviso:${N} argumento ignorado: $arg" ;;
  esac
done

# Verificaciones básicas
[ -f package.json ] || { echo -e "${R}Error:${N} No encuentro package.json. Ejecuta en la raíz del proyecto."; exit 1; }
[ -d src ] || { echo -e "${R}Error:${N} No encuentro src/. Ejecuta en la raíz del proyecto."; exit 1; }

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

# 1) Generar un analizador Node para grafo de uso
mkdir -p tools
ANALYZER=tools/usage-graph.mjs
cat > "$ANALYZER" <<'NODE'
import fs from 'fs';
import path from 'path';

const root = process.cwd();
const SRC = path.join(root, 'src');
const PUBLIC = path.join(root, 'public');
const codeExts = new Set(['.js','.jsx','.ts','.tsx','.css']);
const assetExts = new Set(['.png','.jpg','.jpeg','.svg','.webp','.gif','.ico']);

const read = (p)=>{ try { return fs.readFileSync(p,'utf8'); } catch { return ''; } };
const isCode = (p)=> codeExts.has(path.extname(p));
const isAsset= (p)=> assetExts.has(path.extname(p));

// Recorrer árbol
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

// Mapa de nodos código
const codeFiles = files.filter(isCode);
const assets    = files.filter(isAsset);

// Índice rápido por ruta relativa y basename
const rel = (p)=> p.replace(root+path.sep,'');
const byRel = new Map(codeFiles.map(f=>[rel(f), f]));

// Regex básicos de import/require/dynamic y CSS @import
const reImports = [
  /import\s+[^'"\n]*?from\s*['"]([^'"]+)['"]/g,
  /import\s*\(\s*['"]([^'"]+)['"]\s*\)/g,
  /require\(\s*['"]([^'"]+)['"]\s*\)/g,
  /@import\s+['"]([^'"]+)['"]/g
];

function resolveImport(fromFile, spec){
  if (!spec) return null;
  if (!spec.startsWith('.')) return null; // ignorar paquetes
  const base = path.resolve(path.dirname(fromFile), spec);
  const candidates = [
    base,
    base+'.js', base+'.jsx', base+'.ts', base+'.tsx', base+'.css',
    path.join(base,'index.js'), path.join(base,'index.jsx'), path.join(base,'index.tsx'), path.join(base,'index.ts'), path.join(base,'index.css')
  ];
  for (const c of candidates){ try { if (fs.statSync(c).isFile()) return c; } catch {} }
  return null;
}

// Construir grafo: to -> [froms]
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
  if (/^src\/App\.(j|t)sx?$/.test(r)) likelyRoots.add(f);
}
if (likelyRoots.size===0){ // fallback: si no hay, toma cualquier main-like
  for (const f of codeFiles){ if (/main|index\.(j|t)sx?$/.test(f)){ likelyRoots.add(f); break; } }
}

// Alcanzables por DFS (desde roots)
const reachable = new Set([...likelyRoots]);
function dfs(n){
  for (const [to, froms] of graph.entries()){
    if (froms.has(n) && !reachable.has(to)) { reachable.add(to); dfs(to); }
  }
}
for (const r of likelyRoots) dfs(r);

// CSS importados directos por JS también quedan marcados (ya cubierto por resolveImport)

// Assets referenciados por nombre/ruta en todo el código + index.html + logoUtil
const bigBlob = codeFiles.map(read).join('\n') + (fs.existsSync('index.html')? read('index.html') : '');
const referencedAssets = new Set();
for (const a of assets){
  const name = path.basename(a);
  const pRel = rel(a).replace(/\\/g,'/');
  if (bigBlob.includes(name) || bigBlob.includes(pRel)) referencedAssets.add(a);
}
// Caso especial: public/logos mapeados por src/lib/logoUtil.js
const logoUtil = path.join(SRC,'lib','logoUtil.js');
if (fs.existsSync(logoUtil)){
  const s = read(logoUtil);
  for (const a of assets){
    const name = path.basename(a);
    if (/logos\//.test(a.replace(/\\/g,'/')) && s.includes(name)) referencedAssets.add(a);
  }
}

// Determinar no usados
const unusedCode = codeFiles.filter(f => !reachable.has(f));
const unusedAssets = assets.filter(a => !referencedAssets.has(a));

// Salida
const out = {
  roots: [...[...likelyRoots].map(rel)],
  reachable: [...[...reachable].map(rel)],
  unusedCode: unusedCode.map(rel),
  unusedAssets: unusedAssets.map(rel)
};
console.log(JSON.stringify(out,null,2));
NODE

# 2) Ejecutar analizador
node "$ANALYZER" > usage-graph.json

# 3) Calcular scripts .sh no usados
#    Marcamos como "usado" si aparece referenciado por nombre en package.json, README, otros .sh, .md, .yml, .yaml, .js/.ts (p. ej. comandos npm)
sh_used_tmp=".sh_used_${stamp}.txt"; :> "$sh_used_tmp"
if compgen -G "*.sh" > /dev/null; then
  for s in *.sh; do
    # no autoeliminar este script
    [ "$s" = "prune_unused_kuma.sh" ] && continue
    refs=$(grep -RIn --exclude-dir=node_modules --exclude-dir=.git --exclude=dist --exclude=build --exclude=_unused --exclude=_archive -e "$s" . | wc -l || true)
    if [ "$refs" -gt 0 ]; then echo "$s" >> "$sh_used_tmp"; fi
  done
fi

# 4) Aplicar keep-patterns
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

# 5) Construir listas finales a partir de usage-graph.json
unused_code_list=$(jq -r '.unusedCode[]?' usage-graph.json || true)
unused_assets_list=$(jq -r '.unusedAssets[]?' usage-graph.json || true)

# 6) Determinar .sh no usados (no referenciados) salvo que keep-scripts esté activo
unused_sh_list=""
if [ $keep_scripts -eq 0 ] && compgen -G "*.sh" > /dev/null; then
  for s in *.sh; do
    [ "$s" = "prune_unused_kuma.sh" ] && continue
    if grep -Fxq "$s" "$sh_used_tmp" 2>/dev/null; then continue; fi
    unused_sh_list+="$s\n"
  done
fi

# 7) Mostrar resumen y ejecutar acción
mkdir -p _unused/{code,assets,scripts}

log(){ echo -e "$1" | tee -a "$report" >/dev/null; }
log "=== PRUNE REPORT ${stamp} ==="
log "Modo: $([ $mode_delete -eq 1 ] && echo DELETE || echo ARCHIVE)  |  dry-run: $dry_run  | keep-scripts: $keep_scripts"

# Funciones de mover/borrar respetando Git
rm_path(){ p="$1"; if [ $in_git -eq 1 ]; then run "git rm -rf --ignore-unmatch '$p'"; else run "rm -rf '$p'"; fi }
move_path(){ src="$1" dest="$2"; mkdir -p "$dest"; if [ $in_git -eq 1 ]; then run "git mv -f '$src' '$dest/' 2>/dev/null || mv -f '$src' '$dest/'"; else run "mv -f '$src' '$dest/'"; fi }

# Borrar/archivar listas
count=0

# Código y estilos no usados
if [ -n "$unused_code_list" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_kept "$f" && continue
    if [ $mode_delete -eq 1 ]; then rm_path "$f"; else move_path "$f" _unused/code; fi
    echo "$action_word CODE: $f" | tee -a "$report"
    count=$((count+1))
  done <<< "$unused_code_list"
fi

# Assets no usados
if [ -n "$unused_assets_list" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_kept "$f" && continue
    # no borrar favicon o manifest si existieran sin verificación explícita (seguro)
    base=$(basename "$f")
    case "$base" in favicon.*|manifest.*) continue ;; esac
    if [ $mode_delete -eq 1 ]; then rm_path "$f"; else move_path "$f" _unused/assets; fi
    echo "$action_word ASSET: $f" | tee -a "$report"
    count=$((count+1))
  done <<< "$unused_assets_list"
fi

# Scripts .sh no usados
if [ -n "$unused_sh_list" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_kept "$f" && continue
    if [ $mode_delete -eq 1 ]; then rm_path "$f"; else move_path "$f" _unused/scripts; fi
    echo "$action_word SH: $f" | tee -a "$report"
    count=$((count+1))
  done <<< "$unused_sh_list"
fi

echo -e "${G}Total afectados:${N} $count" | tee -a "$report"

# 8) Commit y push
if [ $dry_run -eq 0 ] && [ $in_git -eq 1 ]; then
  if [ $commit_on_main -eq 1 ]; then
    run "git checkout main || true"
    run "git add -A"
    run "git commit -m 'chore: prune archivos no usados (codigo/assets/scripts)'" || true
    run "git push"
  else
    branch="chore/prune-${stamp}"
    run "git checkout -b '$branch'"
    run "git add -A"
    run "git commit -m 'chore: prune archivos no usados (codigo/assets/scripts)'" || true
    run "git push -u origin '$branch'"
    echo -e "${G}Rama subida:${N} $branch (abre PR para fusionar)"
  fi
fi

# 9) Build para validar (solo si no dry-run)
if [ $dry_run -eq 0 ]; then
  if command -v npm >/dev/null 2>&1; then
    echo -e "${Y}Validando build...${N}"
    (npm ci || npm install)
    npm run build
    echo -e "${G}Build OK.${N}"
  else
    echo -e "${Y}npm no encontrado; omito build.${N}"
  fi
fi

# 10) Epílogo
echo -e "\n${G}Reporte:${N} $report"
if [ $mode_delete -eq 0 ]; then
  echo -e "${Y}Revisa _unused/ y, si todo está bien, puedes borrar luego con git rm -r _unused${N}"
fi
