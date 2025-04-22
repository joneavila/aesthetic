#!/usr/bin/env python3

"""
Converts SVG icons in `assets/icons/lucide/glyphs` to 24px-height PNG format in `src/template/glyph` using the map
`utils/glyph_map.txt`. Additionally, this script prints a list of SVG files in `assets/icons/lucide/glyphs` that are not
listed in `utils/glyph_map.txt` (unused SVG files that can be removed from the repo).

Note: This script will overwrite files without confirmation.

If you receive an error "OSError: no library called "cairo-2" was found", try exporting the following environment
variable: `export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib`
"""

import os
import sys

try:
    from cairosvg import svg2png
except ImportError:
    print("Error: cairosvg module not found. Please install it with:")
    print("pip install cairosvg")
    sys.exit(1)

MAP_FILE = os.path.join(os.path.dirname(__file__), "glyph_map.txt")
SVG_DIR = os.path.join(
    os.path.dirname(os.path.dirname(__file__)), "assets/icons/lucide/glyphs"
)
BASE_OUTPUT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)), "src/template/glyph"
)
PNG_HEIGHT = 24


def main():
    os.makedirs(BASE_OUTPUT_PATH, exist_ok=True)
    os.makedirs(SVG_DIR, exist_ok=True)

    with open(MAP_FILE, "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        parts = line.split(",", 1)
        if len(parts) != 2:
            print(f"Invalid line format: {line}")
            continue

        output_rel_path = parts[0].strip()
        input_filename = parts[1].strip()

        output_path = f"{BASE_OUTPUT_PATH}/{output_rel_path}.png"
        input_path = f"{SVG_DIR}/{input_filename}.svg"

        if not os.path.exists(input_path):
            print(f"Input SVG file does not exist: {input_path}")

        output_dir = os.path.dirname(output_path)
        os.makedirs(output_dir, exist_ok=True)

        with open(input_path, "rb") as svg_file:
            svg_data = svg_file.read()
        svg2png(bytestring=svg_data, write_to=output_path, output_height=PNG_HEIGHT)
        print(f"Converted: {input_path} -> {output_path}")

    find_unused_svg_files()


def find_unused_svg_files():
    print("\nChecking for unused SVG files...")

    svg_files = []
    for filename in os.listdir(SVG_DIR):
        if filename.endswith(".svg"):
            svg_files.append(os.path.splitext(filename)[0])

    glyph_map_icons = []
    with open(MAP_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                parts = line.split(",", 1)
                if len(parts) == 2:
                    glyph_map_icons.append(parts[1].strip())

    unused_svg_files = [svg for svg in svg_files if svg not in glyph_map_icons]

    if unused_svg_files:
        print(f"Found {len(unused_svg_files)} SVG files not used in `glyph_map.txt`:")
        for file in sorted(unused_svg_files):
            print(f"  - {file}")
    else:
        print("All SVG files are used in `glyph_map.txt`")


if __name__ == "__main__":
    main()
