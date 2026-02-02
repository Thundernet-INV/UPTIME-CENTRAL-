#!/usr/bin/env python3
import os, sys, time, shutil, re

path = sys.argv[1] if len(sys.argv) > 1 else 'src/App.jsx'
if not os.path.isfile(path):
    print(f"[ERR] No existe el archivo: {path}")
    sys.exit(1)

# Backup
stamp = time.strftime('%Y%m%d_%H%M%S')
bak = f"{path}.bak_{stamp}"
shutil.copy2(path, bak)
print(f"[OK] Backup creado: {bak}")

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

changed = False
for i, line in enumerate(lines):
    # Detectamos la línea 'const hay =' que no tenga backticks y que termine con .toLowerCase();
    if ('const hay' in line) and ('`' not in line) and ('.toLowerCase()' in line):
        # Reemplazo a la versión correcta con template literal:
        new_line = '      const hay = ${m.info?.monitor_name ?? ""} ${m.info?.monitor_url ?? ""}.toLowerCase();\n'
        print(f"[FIX] L{ i+1 }:")
        print(f"  OLD: {line.rstrip()}")
        print(f"  NEW: {new_line.rstrip()}")
        lines[i] = new_line
        changed = True

# Asegurar que filteredAll tiene 'return true;'
text = ''.join(lines)
pattern = re.compile(
    r'(const\s+filteredAll\s*=\s*useMemo\s*$$\s*\($$\s*=>\s*baseMonitors\.filter\s*$$\s*m\s*=>\s*\{)([\s\S]?)(\}$$\s,\s*$$baseMonitors,\s*effectiveStatus$$\)\s*;)',
    re.M
)

def ensure_return_true(m):
    body = m.group(2)
    if re.search(r'return\s+true\s*;', body):
        return m.group(1) + body + m.group(3)
    # Insertar antes del cierre del callback
    body = body.rstrip() + "\n    return true;\n"
    print("[INFO] Añadido 'return true;' en filteredAll")
    return m.group(1) + body + m.group(3)

new_text, nsubs = pattern.subn(ensure_return_true, text)

if new_text != text:
    changed = True
    text = new_text

if changed:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    print("[OK] src/App.jsx actualizado (forzado)")
else:
    print("[INFO] No hubo cambios (ya estaba correcto)")

# Mostrar cómo quedó la(s) línea(s) con 'const hay'
for idx, l in enumerate(text.splitlines(), start=1):
    if 'const hay' in l:
        print(f"L{idx}: {l}")
