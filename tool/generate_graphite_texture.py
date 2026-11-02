"""Original deterministic micrograin; no reference-image pixels or runtime work.

128x128 RGBA, shared at2x scale (64KiB decoded). Pillow is developer-only.
The authored generator and generated asset belong to the Doodimo source tree.
"""
from pathlib import Path
import random
from PIL import Image

root = Path(__file__).resolve().parents[1]
rng = random.Random(20261029)
image = Image.new('RGBA', (128, 128))
pixels = []
for y in range(128):
    for x in range(128):
        grain = rng.gauss(0, 1)
        # Fine directional striation plus a nonrepeating-in-tile grain field.
        alpha = min(28, round(abs(grain) * 10 + (y % 7 == 0) * 2))
        level = 255 if grain > 0 else 0
        pixels.append((level, level, level, alpha))
image.putdata(pixels)
image.save(root / 'assets/branding/graphite-grain.png', optimize=True)
