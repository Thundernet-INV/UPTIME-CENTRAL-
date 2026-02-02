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
