#!/usr/bin/env python3
"""Developer-only deterministic Nunito Sans instance builder, never app runtime.

Requires fontTools; supply the reviewed official variable master. Exact source
hash, transformation and resulting files are recorded in docs/FONT-MANIFEST.json.
"""
import argparse
import hashlib
import json
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('master', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'docs/FONT-MANIFEST.json').read_text())
actual = hashlib.sha256(args.master.read_bytes()).hexdigest()
if actual != manifest['nunitoMaster']['sha256']:
    raise SystemExit('Master hash differs; review source/license and manifest first.')
for weight, name in [(400, 'Regular'), (500, 'Medium'), (600, 'SemiBold'), (700, 'Bold')]:
    font = TTFont(args.master, recalcTimestamp=False)
    font = instantiateVariableFont(font, {'wght': weight, 'wdth': 100, 'opsz': 12, 'YTLC': 500},
                                   inplace=True, updateFontNames=True)
    target = root / 'assets/fonts/NunitoSans' / f'NunitoSans-{name}.ttf'
    font.save(target)
    print(target.relative_to(root), hashlib.sha256(target.read_bytes()).hexdigest())
