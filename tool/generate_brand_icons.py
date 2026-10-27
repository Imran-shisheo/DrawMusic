"""Generate Doodimo native assets from the original shared SVG identity.

Pillow is a developer-only rasterizer; the shipping app does not depend on it.
Package IDs, storage paths and persisted preference keys are deliberately untouched.
"""
from pathlib import Path
import hashlib
import json
import math
import re
import plistlib
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SVG = ROOT / 'assets/branding/mark.svg'
PAPER, DARK, IVORY = '#F8F7F3', '#172622', '#F1F0EA'
ANDROID = ROOT / 'android/app/src/main/res'
IOS = ROOT / 'ios/Runner/Assets.xcassets'
NS = '{http://www.w3.org/2000/svg}'
ANDROID_NS = 'http://schemas.android.com/apk/res/android'


def identity():
    svg = ET.parse(SVG).getroot()
    assert svg.attrib['viewBox'] == '0 0 100 100'
    path, dot = svg.find(f'{NS}path'), svg.find(f'{NS}circle')
    assert path is not None and dot is not None
    values = re.findall(r'[A-Za-z]|-?(?:\d*\.)?\d+', path.attrib['d'])
    assert values.pop(0) == 'M'
    start = (float(values.pop(0)), float(values.pop(0)))
    points = [start]
    while values:
        assert values.pop(0) == 'C', 'Only the authored M/C cubic path is accepted'
        numbers = [float(values.pop(0)) for _ in range(6)]
        a, b, c = tuple(numbers[:2]), tuple(numbers[2:4]), tuple(numbers[4:])
        for i in range(1, 161):
            t = i / 160
            points.append(tuple((1-t)**3*start[j] + 3*(1-t)**2*t*a[j] + 3*(1-t)*t*t*b[j] + t**3*c[j] for j in range(2)))
        start = c
    return path.attrib['d'], points, float(path.attrib['stroke-width']), path.attrib['stroke'], tuple(float(dot.attrib[k]) for k in ('cx', 'cy', 'r')), dot.attrib['fill']


PATH, POINTS, WIDTH, FOREST, DOT, CORAL = identity()
NAME = re.search(r"displayName\s*=\s*'([^']+)'", (ROOT / 'lib/design_system/brand.dart').read_text()).group(1)
assert NAME == 'Doodimo', 'Brand changes need an explicit owner decision'


def raster(size, *, transparent=False, dark=False, content_scale=.9):
    supersample = 4 if size <= 256 else 2
    edge = size * supersample
    image = Image.new('RGBA' if transparent else 'RGB', (edge, edge), (0, 0, 0, 0) if transparent else PAPER)
    draw = ImageDraw.Draw(image)
    scale = edge / 100 * content_scale
    padding = edge * (1 - content_scale) / 2
    at = lambda p: (round(p[0] * scale + padding), round(p[1] * scale + padding))
    color = IVORY if dark else FOREST
    line = max(1, round(WIDTH * scale))
    draw.line([at(p) for p in POINTS], fill=color, width=line, joint='curve')
    radius = line / 2
    for point in POINTS:
        x, y = at(point)
        draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)
    x, y = at(DOT)
    radius = DOT[2] * scale
    draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=CORAL)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def circle_path():
    x, y, r = DOT
    return f'M{x+r:g},{y:g}a{r:g},{r:g} 0,1 1,{-2*r:g},0a{r:g},{r:g} 0,1 1,{2*r:g},0'


def vector(*, background=False, monochrome=False, launch=False, round_background=False):
    stroke = '#000000' if monochrome else ('@color/doodimo_launch_ink' if launch else FOREST)
    endpoint = '#000000' if monochrome else CORAL
    base = ''
    if background:
        shape = 'M54,0a54,54 0,1 1,0 108a54,54 0,1 1,0 -108' if round_background else 'M0,0h108v108H0z'
        base = f'    <path android:fillColor="{PAPER}" android:pathData="{shape}"/>\n'
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated from assets/branding/mark.svg. Critical content fits the 66dp safe circle. -->
<vector xmlns:android="{ANDROID_NS}" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
{base}    <group android:translateX="20" android:translateY="20" android:scaleX="0.68" android:scaleY="0.68">
        <path android:pathData="{PATH}" android:fillColor="@android:color/transparent" android:strokeColor="{stroke}" android:strokeWidth="{WIDTH:g}" android:strokeLineCap="round" android:strokeLineJoin="round"/>
        <path android:pathData="{circle_path()}" android:fillColor="{endpoint}"/>
    </group>
</vector>
'''


def put(relative, text):
    file = ANDROID / relative
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(text)


def main():
    put('values/brand_colors.xml', f'<resources>\n    <color name="doodimo_icon_background">{PAPER}</color>\n    <color name="doodimo_launch_background">{PAPER}</color>\n    <color name="doodimo_launch_ink">{FOREST}</color>\n</resources>\n')
    put('values-night/brand_colors.xml', f'<resources>\n    <color name="doodimo_launch_background">{DARK}</color>\n    <color name="doodimo_launch_ink">{IVORY}</color>\n</resources>\n')
    put('drawable/app_icon.xml', vector(background=True))
    put('drawable/doodimo_icon_foreground.xml', vector())
    put('drawable/doodimo_icon_monochrome.xml', vector(monochrome=True))
    put('drawable/doodimo_splash_mark.xml', vector(launch=True))
    put('mipmap-anydpi/ic_launcher.xml', vector(background=True))
    put('mipmap-anydpi/ic_launcher_round.xml', vector(background=True, round_background=True))
    for version in (26, 33):
        for name in ('ic_launcher', 'ic_launcher_round'):
            mono = '\n    <monochrome android:drawable="@drawable/doodimo_icon_monochrome"/>' if version >= 33 else ''
            put(f'mipmap-anydpi-v{version}/{name}.xml', f'<adaptive-icon xmlns:android="{ANDROID_NS}">\n    <background android:drawable="@color/doodimo_icon_background"/>\n    <foreground android:drawable="@drawable/doodimo_icon_foreground"/>{mono}\n</adaptive-icon>\n')
    splash = f'''<layer-list xmlns:android="{ANDROID_NS}">
    <item android:drawable="@color/doodimo_launch_background"/>
    <item android:width="108dp" android:height="108dp" android:gravity="center" android:drawable="@drawable/doodimo_splash_mark"/>
</layer-list>
'''
    put('drawable/launch_background.xml', splash)
    put('drawable-v21/launch_background.xml', splash)
    for folder, parent in [('values-v31', '@android:style/Theme.Light.NoTitleBar'), ('values-night-v31', '@android:style/Theme.Black.NoTitleBar')]:
        put(f'{folder}/styles.xml', f'''<resources>
    <style name="LaunchTheme" parent="{parent}">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowSplashScreenBackground">@color/doodimo_launch_background</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/doodimo_splash_mark</item>
        <item name="android:windowSplashScreenIconBackgroundColor">@color/doodimo_launch_background</item>
    </style>
</resources>
''')
    manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
    text = manifest.read_text().replace('android:label="ScribbleSong"', 'android:label="@string/app_name"').replace('android:icon="@drawable/app_icon"', 'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"')
    manifest.write_text(text)
    strings = ANDROID / 'values/strings.xml'
    values = ET.parse(strings).getroot()
    app_name = values.find("string[@name='app_name']")
    if app_name is None: app_name = ET.SubElement(values, 'string', {'name': 'app_name', 'translatable': 'false'})
    app_name.text = NAME
    ET.indent(values, space='    ')
    strings.write_text('<?xml version="1.0" encoding="utf-8"?>\n' + ET.tostring(values, encoding='unicode') + '\n')
    appicons = json.loads((IOS / 'AppIcon.appiconset/Contents.json').read_text())
    generated = []
    for asset in appicons['images']:
        size = round(float(asset['size'].split('x')[0]) * float(asset['scale'][:-1]))
        target = IOS / 'AppIcon.appiconset' / asset['filename']
        raster(size).save(target)
        generated.append(target)
    launches = []
    for dark in (False, True):
        for multiple in (1, 2, 3):
            suffix = '' if multiple == 1 else f'@{multiple}x'
            filename = f'LaunchImage{"-dark" if dark else ""}{suffix}.png'
            target = IOS / 'LaunchImage.imageset' / filename
            raster(84 * multiple, transparent=True, dark=dark, content_scale=1).save(target)
            generated.append(target)
            spec = {'idiom': 'universal', 'filename': filename, 'scale': f'{multiple}x'}
            if dark: spec['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
            launches.append(spec)
    (IOS / 'LaunchImage.imageset/Contents.json').write_text(json.dumps({'images': launches, 'info': {'version': 1, 'author': 'xcode'}}, indent=2) + '\n')
    colorset = IOS / 'DoodimoLaunchBackground.colorset'; colorset.mkdir(exist_ok=True)
    entries = []
    for dark, hex_color in ((False, PAPER), (True, DARK)):
        entry = {'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': {**{key: f'{int(hex_color[index:index+2], 16) / 255:.6f}' for key, index in [('red', 1), ('green', 3), ('blue', 5)]}, 'alpha': '1.000000'}}}
        if dark: entry['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
        entries.append(entry)
    (colorset / 'Contents.json').write_text(json.dumps({'colors': entries, 'info': {'version': 1, 'author': 'xcode'}}, indent=2) + '\n')
    info = ROOT / 'ios/Runner/Info.plist'
    data = plistlib.loads(info.read_bytes()); data['CFBundleDisplayName'] = NAME; data['CFBundleName'] = NAME
    info.write_bytes(plistlib.dumps(data, sort_keys=False))
    for localization in (ROOT / 'ios/Runner').glob('*.lproj/InfoPlist.strings'):
        source = localization.read_text()
        for key in ('CFBundleDisplayName', 'CFBundleName'):
            line = f'"{key}" = "{NAME}";'
            if re.search(rf'^"{key}"\s*=', source, flags=re.M): source = re.sub(rf'^"{key}"\s*=.*?;\s*$', line, source, flags=re.M)
            else: source += '\n' + line + '\n'
        localization.write_text(source)
    storyboard = ROOT / 'ios/Runner/Base.lproj/LaunchScreen.storyboard'
    source = storyboard.read_text()
    source = re.sub(r'<color key="backgroundColor"[^>]*/>', '<color key="backgroundColor" name="DoodimoLaunchBackground"/>', source)
    if '<namedColor name="DoodimoLaunchBackground">' not in source:
        source = source.replace('    </resources>', '        <namedColor name="DoodimoLaunchBackground">\n            <color red="0.972549" green="0.968627" blue="0.952941" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>\n        </namedColor>\n    </resources>')
    storyboard.write_text(source)
    native = ROOT / 'ios/Runner/DrawMusicBackgrounds.swift'
    native.write_text(native.read_text().replace('Enable Camera for DrawMusic in iOS Settings', f'Enable Camera for {NAME} in iOS Settings'))
    radius = max(math.hypot(20 + .68*x - 54, 20 + .68*y - 54) + WIDTH*.68/2 for x, y in POINTS)
    radius = max(radius, math.hypot(20+.68*DOT[0]-54, 20+.68*DOT[1]-54)+.68*DOT[2])
    assert radius < 33, 'Critical glyph must fit Android adaptive 66dp safe circle'
    report = {'brand': NAME, 'source': 'assets/branding/mark.svg', 'sourceSha256': hashlib.sha256(SVG.read_bytes()).hexdigest(), 'packageIdentifierUnchanged': 'com.imranshisheo.scribblesong', 'androidAdaptiveViewportDp': 108, 'androidCriticalSafeCircleDiameterDp': 66, 'androidCriticalGlyphMaxRadiusDp': radius, 'iosAppIconContentScale': .9, 'background': PAPER, 'generatedPngs': {str(file.relative_to(ROOT)): {'sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'size': list(Image.open(file).size), 'mode': Image.open(file).mode} for file in sorted(set(generated))}, 'scope': 'Original SVG-derived assets and source checks; not iOS compilation or physical launcher validation'}
    (ROOT / 'assets/branding/native-icon-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Generated {len(set(generated))} original native PNGs; adaptive content radius {radius:.3f}dp / 33dp safe radius. Package/storage identity unchanged.')


if __name__ == '__main__': main()
