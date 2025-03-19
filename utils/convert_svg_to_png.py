#!/usr/bin/env python3

"""
Converts SVG icons to 24px-height PNG format using the map in `glyph_map.txt`.
Each line in the map file follows the format:
    output_path (muOS glyph name), input_filename (Lucide icon name)

Note: This script will overwrite existing PNG files without confirmation.

Note: `glyph_map.txt` ignores the `footer` and `header` glyphs.
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
BASE_INPUT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)), "assets/icons/lucide/svg"
)
BASE_OUTPUT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)), "src/template/glyph"
)
PNG_HEIGHT = 24


def main():
    os.makedirs(BASE_OUTPUT_PATH, exist_ok=True)
    os.makedirs(BASE_INPUT_PATH, exist_ok=True)

    with open(MAP_FILE, "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if not line:
            continue

        parts = line.split(",", 1)
        if len(parts) != 2:
            print(f"Invalid line format: {line}")
            continue

        output_rel_path = parts[0].strip()
        input_filename = parts[1].strip()

        output_path = f"{BASE_OUTPUT_PATH}/{output_rel_path}.png"
        input_path = f"{BASE_INPUT_PATH}/{input_filename}.svg"

        if not os.path.exists(input_path):
            print(f"Input SVG file does not exist: {input_path}")

        output_dir = os.path.dirname(output_path)
        os.makedirs(output_dir, exist_ok=True)

        with open(input_path, "rb") as svg_file:
            svg_data = svg_file.read()
        svg2png(bytestring=svg_data, write_to=output_path, output_height=PNG_HEIGHT)
        print(f"Converted: {input_path} -> {output_path}")


if __name__ == "__main__":
    main()
