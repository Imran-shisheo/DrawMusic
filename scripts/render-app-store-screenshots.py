#!/usr/bin/env python3
"""Compose original App Store campaign layouts around unaltered iOS captures.

Requires Pillow. The UI is only uniformly resized, never retouched or fabricated.
Usage: python render-app-store-screenshots.py CAPTURES OUTPUT --device iphone
"""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


SLIDES = [
    ("01-draw-it-hear-it", ["Draw it.", "Hear it."], "Your doodles become musical loops."),
    ("02-find-your-sound", ["Find your", "sound."], "13 original instrument voices."),
    ("03-give-it-a-groove", ["Give it", "a groove."], "Layer bass, arpeggios and percussion."),
    ("04-change-the-mood", ["Change", "the mood."], "Explore tempo, keys and scales."),
    ("05-make-it-your-canvas", ["Make it", "your canvas."], "Smooth strokes, Pixel style and color."),
    ("06-let-your-ideas-travel", ["Let your", "ideas travel."], "Export MIDI, WAV, video and PNG."),
]
PALETTES = ["#E6F4EC", "#FAEADF", "#E7EEF9", "#F0E9F5", "#F9EFCF", "#E0F2F0"]
INK = "#153E38"
TEAL = "#007E73"


def font(size, bold=False):
    path = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf"
    return ImageFont.truetype(path, size)


def compose(source, output, index, device):
    size = (1206, 2622) if device == "iphone" else (2064, 2752)
    width, height = size
    ratio = width / 1206
    page = Image.new("RGB", size, PALETTES[index])
    draw = ImageDraw.Draw(page)
    margin = round(83 * ratio)
    # Original typography and quiet visual rhythm, separate from the app capture.
    draw.rounded_rectangle((margin, 57, margin + 16 * ratio, 91), radius=8, fill=TEAL)
    draw.text((margin + 32 * ratio, 51), "Doodimo", fill=INK, font=font(round(40 * ratio), True))
    counter = f"{index + 1:02d} / 06"
    draw.text((width - margin, 63), counter, anchor="ra", fill=TEAL, font=font(round(24 * ratio), True))
    headline_size = 121 if device == "iphone" else 153
    title_y = 156 if device == "iphone" else 146
    line_height = 131 if device == "iphone" else 166
    for line in SLIDES[index][1]:
        draw.text((margin - 5, title_y), line, fill=INK, font=font(headline_size, True))
        title_y += line_height
    supporting_y = 460 if device == "iphone" else 518
    draw.text((margin, supporting_y), SLIDES[index][2], fill=INK,
              font=font(42 if device == "iphone" else 58))
    with Image.open(source) as opened:
        ui = opened.convert("RGB")
    # Preserve the entire native screenshot and its aspect ratio.
    max_height = 1900 if device == "iphone" else 1995
    max_width = width - 2 * (158 if device == "iphone" else 260)
    scale = min(max_width / ui.width, max_height / ui.height)
    ui = ui.resize((round(ui.width * scale), round(ui.height * scale)), Image.Resampling.LANCZOS)
    x, y = (width - ui.width) // 2, (625 if device == "iphone" else 665)
    border = 15 if device == "iphone" else 19
    radius = 68 if device == "iphone" else 42
    rect = (x - border, y - border, x + ui.width + border, y + ui.height + border)
    shadow = Image.new("RGBA", size)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (rect[0] - 4, rect[1] + 15, rect[2] + 4, rect[3] + 25),
        radius=radius, fill=(21, 62, 56, 46))
    page = Image.alpha_composite(page.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(27)))
    ImageDraw.Draw(page).rounded_rectangle(rect, radius=radius, fill=INK)
    mask = Image.new("L", ui.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, ui.width - 1, ui.height - 1), radius=radius - border, fill=255)
    page.paste(ui, (x, y), mask)
    page = page.convert("RGB")
    page.save(output, optimize=True)
    return {
        "file": output.name,
        "dimensions": list(size),
        "capture": str(source),
        "capture_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "ui_transformation": "uniform resize and rounded outer frame; native controls/content unchanged",
    }


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("captures", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--device", choices=["iphone", "ipad"], required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = []
    previews = []
    for index, (name, _, _) in enumerate(SLIDES):
        path = args.output / f"{name}.png"
        manifest.append(compose(args.captures / f"{name}.png", path, index, args.device))
        with Image.open(path) as slide:
            preview = slide.copy()
            preview.thumbnail((330, 720))
            previews.append(preview)
    tile_height = max(p.height for p in previews)
    sheet = Image.new("RGB", (3 * 330, 2 * tile_height), "#F7F5EB")
    for index, preview in enumerate(previews):
        sheet.paste(preview, ((index % 3) * 330, (index // 3) * tile_height))
    sheet.save(args.output / "contact-sheet.jpg", quality=92)
    (args.output / "asset-manifest.json").write_text(json.dumps({
        "device": args.device,
        "locale": "en-US",
        "assets": manifest,
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()
