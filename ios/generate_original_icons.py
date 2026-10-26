"""Rasterize DrawMusic's original Android wave/note identity for iOS.

No competitor or Flutter-brand image is used. Requires Pillow for regeneration;
Pillow is a developer tool, not an application dependency.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).parent / 'Runner/Assets.xcassets'
scale = 20
image = Image.new('RGB', (108 * scale, 108 * scale), '#FFFDF5')
draw = ImageDraw.Draw(image)
def box(values):
    return tuple(round(v * scale) for v in values)
draw.ellipse(box((14, 14, 94, 94)), fill='#E0F1E9')
def curve(a, b, c, d):
    result = []
    for i in range(121):
        t = i / 120
        result.append(tuple(round(((1-t)**3*a[j]+3*(1-t)**2*t*b[j]+3*(1-t)*t*t*c[j]+t**3*d[j])*scale) for j in range(2)))
    return result
points = curve((25,63),(34,63),(34,39),(43,39)) + curve((43,39),(52,39),(52,69),(61,69)) + curve((61,69),(70,69),(70,44),(79,44))
draw.line(points, fill='#7961C6', width=6*scale, joint='curve')
for p in [points[0],points[-1]]:
    draw.ellipse((p[0]-3*scale,p[1]-3*scale,p[0]+3*scale,p[1]+3*scale),fill='#7961C6')
draw.polygon([box((68,32)),box((83,28)),box((83,34)),box((72,37)),box((72,54)),box((68,54))],fill='#007E73')
draw.ellipse(box((60,48,72,58)),fill='#007E73')
manifest=json.loads((root/'AppIcon.appiconset/Contents.json').read_text())
for asset in manifest['images']:
    size=round(float(asset['size'].split('x')[0])*float(asset['scale'][:-1]))
    image.resize((size,size), Image.Resampling.LANCZOS).save(root/'AppIcon.appiconset'/asset['filename'])
for multiple in (1,2,3):
    suffix='' if multiple==1 else f'@{multiple}x'
    image.resize((84*multiple,84*multiple), Image.Resampling.LANCZOS).save(root/'LaunchImage.imageset'/f'LaunchImage{suffix}.png')
