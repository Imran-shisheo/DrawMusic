#!/usr/bin/env python3
"""Check original native asset sizes/source identity without raster dependencies.

Source/PNG/resource checks are not physical launcher or Apple compilation proof.
"""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import struct
import xml.etree.ElementTree as ET
import zlib

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


def png_header(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n' and len(data) > 45, path
    assert data[8:16] == b'\x00\x00\x00\rIHDR', path
    assert zlib.crc32(data[12:29]) & 0xffffffff == struct.unpack('>I', data[29:33])[0], path
    assert data[-12:] == b'\x00\x00\x00\x00IEND\xaeB`\x82', path
    return struct.unpack('>II', data[16:24]), data[24], data[25]


def main():
    brand = re.search(r"displayName\s*=\s*'([^']+)'", (ROOT / 'lib/design_system/brand.dart').read_text()).group(1)
    report = json.loads((ROOT / 'assets/branding/native-icon-manifest.json').read_text())
    assert brand == report['brand'] == 'Doodimo'
    svg = ROOT / report['source']
    assert hashlib.sha256(svg.read_bytes()).hexdigest() == report['sourceSha256']
    assert report['androidCriticalGlyphMaxRadiusDp'] < report['androidCriticalSafeCircleDiameterDp'] / 2 == 33
    app = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot().find('application')
    assert app.get(ANDROID + 'label') == '@string/app_name'
    assert app.get(ANDROID + 'icon') == '@mipmap/ic_launcher'
    assert app.get(ANDROID + 'roundIcon') == '@mipmap/ic_launcher_round'
    strings = ET.parse(ROOT / 'android/app/src/main/res/values/strings.xml').getroot()
    assert strings.find("string[@name='app_name']").text == brand
    svg_root = ET.parse(svg).getroot()
    planes = svg_root.findall('{http://www.w3.org/2000/svg}path')
    assert [p.get('id') for p in planes] == ['orbit-plane', 'fold-plane', 'edge-light']
    assert all(p.get('stroke') is None and p.get('fill', '').startswith('url(#') for p in planes)
    painter = (ROOT / 'lib/design_system/doodimo_mark_painter.dart').read_text()
    for plane, name in zip(planes, ('Orbit', 'Fold', 'Edge')):
        actual = re.search(rf"const doodimo{name}PathData\s*=\s*'([^']+)';", painter)
        assert actual and actual.group(1) == plane.get('d'), f'In-app {name} geometry differs from original SVG/native identity'
    assert report['background'] == '#141819'
    for name in ('doodimo_icon_foreground', 'doodimo_icon_monochrome', 'doodimo_splash_mark'):
        vector = ET.parse(ROOT / f'android/app/src/main/res/drawable/{name}.xml').getroot()
        group = vector.find('group')
        assert group.get(ANDROID + 'scaleX') == group.get(ANDROID + 'scaleY') == '0.68'
        assert group.get(ANDROID + 'translateX') == group.get(ANDROID + 'translateY') == '20'
        paths = group.findall('path')
        expected = planes[:2] if name == 'doodimo_icon_monochrome' else planes
        assert [p.get(ANDROID + 'pathData') for p in paths] == [p.get('d') for p in expected]
        assert all(p.get(ANDROID + 'strokeColor') is None for p in paths)
        assert all(p.get(ANDROID + 'fillType') == 'evenOdd' for p in paths)
        if name != 'doodimo_icon_monochrome':
            assert all(p.find('{http://schemas.android.com/aapt}attr/gradient') is not None for p in paths)
    for api in (26, 33):
        for name in ('ic_launcher', 'ic_launcher_round'):
            adaptive = ET.parse(ROOT / f'android/app/src/main/res/mipmap-anydpi-v{api}/{name}.xml').getroot()
            assert adaptive.find('foreground').get(ANDROID + 'drawable') == '@drawable/doodimo_icon_foreground'
            assert (adaptive.find('monochrome') is not None) == (api >= 33)
    icons = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    icon_entries = json.loads((icons / 'Contents.json').read_text())['images']
    for entry in icon_entries:
        expected = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
        size, depth, color = png_header(icons / entry['filename'])
        assert size == (expected, expected) and depth == 8 and color == 2, entry # RGB, no alpha.
    for path, expected in report['generatedPngs'].items():
        source = (ROOT / path).resolve()
        source.relative_to(ROOT)
        assert hashlib.sha256(source.read_bytes()).hexdigest() == expected['sha256'], path
        assert list(png_header(source)[0]) == expected['size'], path
    info = plistlib.loads((ROOT / 'ios/Runner/Info.plist').read_bytes())
    assert info['CFBundleDisplayName'] == info['CFBundleName'] == brand
    assert info['CFBundleIdentifier'] == '$(PRODUCT_BUNDLE_IDENTIFIER)'
    native = (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
    assert 'PRODUCT_BUNDLE_IDENTIFIER = com.devwithdelta.doodimo;' in native
    android = (ROOT / 'android/app/build.gradle.kts').read_text()
    assert 'applicationId = "com.devwithdelta.doodimo"' in android
    localized = list((ROOT / 'ios/Runner').glob('*.lproj/InfoPlist.strings'))
    assert len(localized) == 12
    for path in localized:
        assert f'"CFBundleDisplayName" = "{brand}";' in path.read_text(), path
    print(f'{brand}: {len(set(e["filename"] for e in icon_entries))} opaque iOS app-icon sizes, 6 launch variants, Android legacy/adaptive/monochrome and approved package identity verified. Native launcher/device/iOS compilation remains separate.')


if __name__ == '__main__': main()
