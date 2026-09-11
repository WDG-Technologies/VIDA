# -*- coding: utf-8 -*-
"""Convierte a.txt → assets/data/daily_verses.json (sin duplicados)."""
import ast
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
src = (root / 'a.txt').read_text(encoding='utf-8')

# Extrae el bloque citas = [ ... ]
m = re.search(r'citas\s*=\s*\[(.*?)\n\]', src, re.S)
if not m:
    raise SystemExit('No se encontró la lista citas en a.txt')

raw_list = '[' + m.group(1) + '\n]'
# Sustituye RVR / TLA por strings para ast.literal_eval
raw_list = raw_list.replace('RVR,', '"RVR",').replace('TLA,', '"TLA",')
citas = ast.literal_eval(raw_list)

seen = set()
out = []
for cita, version, texto in citas:
    ref = cita.strip()
    # Normaliza Salmos → Salmo
    if ref.startswith('Salmos '):
        ref = 'Salmo ' + ref[len('Salmos '):]
    key = ref.casefold()
    if key in seen:
        continue
    seen.add(key)
    text = texto.strip()
    if not ref or not text:
        continue
    item = {'referencia': ref, 'versiculo': text}
    if version and version != 'RVR':
        item['version'] = version  # p.ej. TLA; la app ignora campos extra
    out.append(item)

dest = root / 'assets' / 'data' / 'daily_verses.json'
dest.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Wrote {len(out)} verses to {dest.relative_to(root)}')
print(f'Skipped duplicates: {len(citas) - len(out)}')
