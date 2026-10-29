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
from PIL import Image, ImageDraw, ImageChops

ROOT = Path(__file__).resolve().parents[1]
SVG = ROOT / 'assets/branding/mark.svg'
PAPER, DARK, IVORY = '#141819', '#141819', '#F5F3EB'
ANDROID = ROOT / 'android/app/src/main/res'
IOS = ROOT / 'ios/Runner/Assets.xcassets'
NS = '{http://www.w3.org/2000/svg}'
ANDROID_NS = 'http://schemas.android.com/apk/res/android'


def polygons(path):
    tokens = re.findall(r'[A-Za-z]|-?(?:\d*\.)?\d+', path)
    paths, points, cursor = [], [], (0., 0.)
    while tokens:
        command = tokens.pop(0)
        if command in ('M', 'L'):
            cursor = tuple(float(tokens.pop(0)) for _ in range(2))
            if command == 'M':
                if points: paths.append(points)
                points = []
            points.append(cursor)
        elif command == 'C':
            values = [float(tokens.pop(0)) for _ in range(6)]
            a, b, end = tuple(values[:2]), tuple(values[2:4]), tuple(values[4:])
            start = cursor
            for i in range(1, 101):
                t = i / 100
                points.append(tuple((1-t)**3*start[j] + 3*(1-t)**2*t*a[j] + 3*(1-t)*t*t*b[j] + t**3*end[j] for j in range(2)))
            cursor = end
        elif command == 'Z':
            paths.append(points); points = []
        else: raise ValueError('Only authored absolute M/L/C/Z paths accepted')
    if points: paths.append(points)
    return paths


SVG_ROOT = ET.parse(SVG).getroot()
assert SVG_ROOT.attrib['viewBox'] == '0 0 100 100'
PLANES = list(SVG_ROOT.findall(f'{NS}path'))
GRADIENTS = {g.attrib['id']: g for g in SVG_ROOT.findall(f'{NS}defs/{NS}linearGradient')}
POINTS = [point for plane in PLANES for polygon in polygons(plane.attrib['d']) for point in polygon]
NAME = re.search(r"displayName\s*=\s*'([^']+)'", (ROOT / 'lib/design_system/brand.dart').read_text()).group(1)
assert NAME == 'Doodimo', 'Brand changes need an explicit owner decision'


def gradient(plane):
    return GRADIENTS[plane.attrib['fill'][5:-1]]


def rgba(stop, opacity=1):
    color = stop.attrib['stop-color']
    return tuple(int(color[index:index+2], 16) for index in (1, 3, 5)) + (round(255 * float(stop.attrib.get('stop-opacity', '1')) * opacity),)


def raster(size, *, transparent=False, dark=False, content_scale=.9):
    supersample = 4 if size <= 256 else 2
    edge = size * supersample
    image = Image.new('RGBA', (edge, edge), (0, 0, 0, 0) if transparent else PAPER)
    scale = edge / 100 * content_scale
    padding = edge * (1 - content_scale) / 2
    at = lambda p: (p[0] * scale + padding, p[1] * scale + padding)
    for plane in PLANES:
        mask = Image.new('1', (edge, edge))
        for polygon in polygons(plane.attrib['d']):
            part = Image.new('1', (edge, edge))
            ImageDraw.Draw(part).polygon([at(point) for point in polygon], fill=1)
            mask = ImageChops.logical_xor(mask, part)
        g = gradient(plane); stops = list(g)
        x1, y1, x2, y2 = (float(g.attrib[k]) for k in ('x1', 'y1', 'x2', 'y2'))
        dx, dy = x2-x1, y2-y1; length = dx*dx+dy*dy
        # A narrow sampled ramp transformed by the exact SVG gradient equation.
        ramp = Image.new('RGBA', (1, 4096))
        colors = []
        for row in range(4096):
            t = min(1., max(0., (row - 2048) / 1024))
            left, right = stops[0], stops[-1]
            for low, high in zip(stops, stops[1:]):
                if float(low.attrib['offset']) <= t <= float(high.attrib['offset']):
                    left, right = low, high; break
            lo, hi = float(left.attrib['offset']), float(right.attrib['offset'])
            mix = 0 if lo == hi else (t-lo)/(hi-lo)
            c1, c2 = rgba(left, float(plane.attrib.get('opacity', '1'))), rgba(right, float(plane.attrib.get('opacity', '1')))
            colors.append(tuple(round(a+(b-a)*mix) for a,b in zip(c1,c2)))
        ramp.putdata(colors)
        a, b = 1024*dx/scale/length, 1024*dy/scale/length
        c = 2048 - 1024*((padding/scale+x1)*dx+(padding/scale+y1)*dy)/length
        fill = ramp.transform((edge,edge), Image.Transform.AFFINE, (0,0,0,a,b,c), Image.Resampling.BILINEAR)
        fill.putalpha(ImageChops.multiply(fill.getchannel('A'), mask.convert('L')))
        image.alpha_composite(fill)
    image = image.resize((size,size), Image.Resampling.LANCZOS)
    return image if transparent else image.convert('RGB')


def vector(*, background=False, monochrome=False, launch=False, round_background=False):
    base = ''
    if background:
        shape = 'M54,0a54,54 0,1 1,0 108a54,54 0,1 1,0 -108' if round_background else 'M0,0h108v108H0z'
        base = f'    <path android:fillColor="{PAPER}" android:pathData="{shape}"/>\n'
    items = []
    for plane in PLANES:
        if monochrome and plane.attrib['id'] == 'edge-light': continue
        path = plane.attrib['d']
        if monochrome:
            items.append(f'        <path android:pathData="{path}" android:fillType="evenOdd" android:fillColor="#000000"/>')
            continue
        g = gradient(plane)
        stops = []
        for stop in g:
            color = rgba(stop)
            encoded = '#' + ''.join(f'{v:02X}' for v in (color[3], *color[:3]))
            stops.append(f'                    <item android:offset="{stop.attrib["offset"]}" android:color="{encoded}"/>')
        attrs = ' '.join(f'android:{android}="{g.attrib[svg]}"' for android,svg in [('startX','x1'),('startY','y1'),('endX','x2'),('endY','y2')])
        items.append(f'''        <path android:pathData="{path}" android:fillType="evenOdd" android:fillAlpha="{plane.attrib.get('opacity', '1')}">
            <aapt:attr name="android:fillColor">
                <gradient android:type="linear" {attrs}>
{chr(10).join(stops)}
                </gradient>
            </aapt:attr>
        </path>''')
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated original original dimensional drawing-to-sound gesture. Critical glyph fits the 66dp safe circle. -->
<vector xmlns:android="{ANDROID_NS}" xmlns:aapt="http://schemas.android.com/aapt" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
{base}    <group android:translateX="20" android:translateY="20" android:scaleX="0.68" android:scaleY="0.68">
{chr(10).join(items)}
    </group>
</vector>
'''


def put(relative, text):
    file = ANDROID / relative
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(text)


def main():
    put('values/brand_colors.xml', f'<resources>\n    <color name="doodimo_icon_background">{PAPER}</color>\n    <color name="doodimo_launch_background">{PAPER}</color>\n    <color name="doodimo_launch_ink">#FF9855</color>\n</resources>\n')
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
        source = source.replace('    </resources>', '        <namedColor name="DoodimoLaunchBackground">\n            <color red="0.078431" green="0.094118" blue="0.098039" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>\n        </namedColor>\n    </resources>')
    source = re.sub(r'(<namedColor name="DoodimoLaunchBackground">\s*)<color[^>]*/>', r'\1<color red="0.078431" green="0.094118" blue="0.098039" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>', source)
    storyboard.write_text(source)
    native = ROOT / 'ios/Runner/DrawMusicBackgrounds.swift'
    native.write_text(native.read_text().replace('Enable Camera for DrawMusic in iOS Settings', f'Enable Camera for {NAME} in iOS Settings'))
    radius = max(math.hypot(20 + .68*x - 54, 20 + .68*y - 54) for x, y in POINTS)

    assert radius < 33, 'Critical glyph must fit Android adaptive 66dp safe circle'
    report = {'brand': NAME, 'source': 'assets/branding/mark.svg', 'sourceSha256': hashlib.sha256(SVG.read_bytes()).hexdigest(), 'packageIdentifierUnchanged': 'com.imranshisheo.scribblesong', 'androidAdaptiveViewportDp': 108, 'androidCriticalSafeCircleDiameterDp': 66, 'androidCriticalGlyphMaxRadiusDp': radius, 'iosAppIconContentScale': .9, 'background': PAPER, 'generatedPngs': {str(file.relative_to(ROOT)): {'sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'size': list(Image.open(file).size), 'mode': Image.open(file).mode} for file in sorted(set(generated))}, 'scope': 'Original SVG-derived assets and source checks; not iOS compilation or physical launcher validation'}
    (ROOT / 'assets/branding/native-icon-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Generated {len(set(generated))} original native PNGs; adaptive content radius {radius:.3f}dp / 33dp safe radius. Package/storage identity unchanged.')


if __name__ == '__main__': main()
