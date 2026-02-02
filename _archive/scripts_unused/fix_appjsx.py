#!/usr/bin/env python3
import re, sys, shutil, os, time

# Uso: python3 fix_appjsx.py [ruta_al_App.jsx]
path = sys.argv[1] if len(sys.argv) > 1 else 'src/App.jsx'
if not os.path.isfile(path):
    print(f"[ERR] No existe el archivo: {path}")
    raise SystemExit(1)

# Backup
stamp = time.strftime('%Y%m%d_%H%M%S')
bak = f"{path}.bak_{stamp}"
shutil.copy2(path, bak)
print(f"[OK] Backup creado: {bak}")

with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

orig = src

# 1) Corregir la línea 'const hay = ... .toLowerCase();' con backticks correctos
line_re = re.compile(r"^\s*const\s+hay\s*=\s*.?\.toLowerCase$$$$;\s$", re.M)
replacement = '      const hay = ${m.info?.monitor_name ?? ""} ${m.info?.monitor_url ?? ""}.toLowerCase();'
src = line_re.sub(replacement, src)

# 2) Asegurar que filteredAll retorna true al final
src = re.sub(
    r"(const\s+filteredAll\s*=\s*useMemo\s*$$\s*\($$\s*=>\s*baseMonitors\.filter\s*$$\s*m\s*=>\s*\{)([\s\S]?)(\}$$\s,\s*$$baseMonitors,\s*effectiveStatus$$\)\s*;)",
    lambda m: (
        m.group(1)
        + (m.group(2) if re.search(r"return\s+true\s*;", m.group(2)) else m.group(2).rstrip()+"\n    return true;\n")
        + m.group(3)
    ),
    src,
    flags=re.M
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("[OK] src/App.jsx actualizado")
for i, line in enumerate(src.splitlines(), start=1):
    if 'const hay' in line:
        print(f"L{i}: {line}")
