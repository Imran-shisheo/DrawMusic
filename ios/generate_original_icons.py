"""Compatibility entry point for shared original Doodimo native asset generation.

The authoritative geometry is assets/branding/mark.svg. Pillow is a developer
rasterizer only; no competitor artwork or runtime dependency is introduced.
"""
from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tool/generate_brand_icons.py'), run_name='__main__')
