import math
import os
import sys

import numpy as np


def smart_detect_glyph_size(filepath, min_glyphs=64):
    filesize = os.path.getsize(filepath)
    best_score = -1
    best_glyphs = None
    best_dims = (0, 0)

    data = np.fromfile(filepath, dtype=np.uint8)

    for w in range(4, 33):  # try width from 4 to 32
        for h in range(4, 65):  # try height from 4 to 64
            gsize = w * h
            if filesize % gsize != 0:
                continue
            num_glyphs = filesize // gsize
            if num_glyphs < min_glyphs:
                continue
            try:
                glyphs = data[: num_glyphs * gsize].reshape((num_glyphs, h, w))
                non_empty = np.count_nonzero(np.any(glyphs != 0, axis=(1, 2)))
                score = non_empty / num_glyphs
                if score > best_score:
                    best_score = score
                    best_glyphs = glyphs
                    best_dims = (w, h)
            except Exception:
                continue

    if best_glyphs is None:
        raise ValueError(f"Failed to detect glyph size for {filepath}")
    return best_glyphs, best_dims[0], best_dims[1]


def avg_char_bbox(glyphs):
    widths = []
    heights = []
    for glyph in glyphs:
        rows = np.any(glyph != 0, axis=1)
        cols = np.any(glyph != 0, axis=0)
        if not np.any(rows) or not np.any(cols):
            continue  # skip empty glyphs
        y_indices = np.where(rows)[0]
        x_indices = np.where(cols)[0]
        height = y_indices[-1] - y_indices[0] + 1
        width = x_indices[-1] - x_indices[0] + 1
        widths.append(width)
        heights.append(height)
    avg_width = np.mean(widths) if widths else 0
    avg_height = np.mean(heights) if heights else 0
    return avg_width, avg_height


def main(font1_path, font2_path):
    font1_glyphs, w1, h1 = smart_detect_glyph_size(font1_path)
    font2_glyphs, w2, h2 = smart_detect_glyph_size(font2_path)

    avg1_w, avg1_h = avg_char_bbox(font1_glyphs)
    avg2_w, avg2_h = avg_char_bbox(font2_glyphs)

    print(
        f"Font 1: {os.path.basename(font1_path)} — size: {w1}x{h1}, avg char bbox: {avg1_w:.2f}x{avg1_h:.2f}"
    )
    print(
        f"Font 2: {os.path.basename(font2_path)} — size: {w2}x{h2}, avg char bbox: {avg2_w:.2f}x{avg2_h:.2f}"
    )
    width_scale = avg2_w / avg1_w if avg1_w else 0
    height_scale = avg2_h / avg1_h if avg1_h else 0
    geom_mean = (
        math.sqrt(width_scale * height_scale) if width_scale and height_scale else 0
    )
    print(f"\nEstimated scaling factor:")
    print(f"  Width:  {width_scale:.2f}x")
    print(f"  Height: {height_scale:.2f}x")
    print(f"  Geometric mean: {geom_mean:.2f}x (overall font size)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python compare_fonts.py font1.bin font2.bin")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
