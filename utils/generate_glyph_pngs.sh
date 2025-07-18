#!/bin/bash
set -euo pipefail

MAPPING_FILE="utils/glyph_mapping.txt"
SRC_DIR="assets/icons"
OUT_DIR="assets/icons/glyph"
STROKE_WIDTH=2.0

# Function to convert SVG to PNG
convert_svg_to_png() {
  local input_svg="$1"
  local output_png="$2"
  local size="$3"
  local y_adjust="${4:-0}"
  local tmp_svg="/tmp/$(basename "$input_svg" .svg)_stroke.svg"
  local tmp_png="/tmp/$(basename "$output_png" .png)_raw.png"
  # Replace stroke-width value with $STROKE_WIDTH and count replacements
  local replace_count
  replace_count=$(grep -o 'stroke-width="[0-9.]*"' "$input_svg" | wc -l)
  sed -E 's/stroke-width="[0-9.]+"/stroke-width="'$STROKE_WIDTH'"/g' "$input_svg" >"$tmp_svg"
  if [ "$replace_count" -eq 0 ]; then
    echo "[WARN] No stroke-width replaced in $input_svg" >&2
  fi
  mkdir -p "$(dirname "$output_png")"
  rsvg-convert -a -f png -w "$size" -h "$size" "$tmp_svg" -o "$tmp_png"
  rm -f "$tmp_svg"
  if [ "${y_adjust}" != "0" ] && command -v magick >/dev/null 2>&1; then
    # Shift the PNG vertically by y_adjust pixels (positive = down, negative = up)
    magick convert -size ${size}x${size} canvas:none "$tmp_png" -geometry +0+${y_adjust} -gravity NorthWest -composite "$output_png"
    rm -f "$tmp_png"
  else
    mv "$tmp_png" "$output_png"
  fi
}

# Default size for most glyphs
DEFAULT_SIZE=24
SIZE_1024x768=34
SIZE_MUXLAUNCH=120
SIZE_MUXLAUNCH_1024x768=192
SIZE_MUXTESTER=128
PADDING_MUXLAUNCH=30          # Subtracted from size to get final icon size
PADDING_MUXLAUNCH_1024x768=72 # Subtracted from size to get final icon size
SIZE_HEADER=28
SIZE_HEADER_1024x768=38
SIZE_FOOTER=28
SIZE_FOOTER_1024x768=38

# Clean output directory
if [ -d "$OUT_DIR" ]; then
  rm -rf "$OUT_DIR"
  # Wait until the directory is actually deleted
  while [ -d "$OUT_DIR" ]; do
    sleep 0.5
  done
fi
mkdir -p "$OUT_DIR"

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip comments and blank lines
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  # Parse mapping
  output_path=$(echo "$line" | cut -d, -f1 | xargs)
  input_svg_rel=$(echo "$line" | cut -d, -f2 | xargs)
  percent_adj=$(echo "$line" | cut -d, -f3 | xargs)
  y_adjust=$(echo "$line" | cut -d, -f4 | xargs)
  input_svg="$SRC_DIR/$input_svg_rel.svg"
  output_png="$OUT_DIR/$output_path.png"

  # Apply percentage adjustment
  adjust_size() {
    local base_size="$1"
    local percent="$2"
    if [[ -z "$percent" ]]; then
      echo "$base_size"
    else
      # Allow negative or positive percent
      adj=$(awk "BEGIN { printf(\"%.0f\", $base_size * (1 + $percent / 100.0)) }")
      echo "$adj"
    fi
  }

  if [[ "$output_path" == muxlaunch/* ]]; then
    # (1A) Default glyph output directory (DEFAULT_SIZE)
    size=$(adjust_size "$DEFAULT_SIZE" "$percent_adj")
    if [[ ! -f "$input_svg" ]]; then
      echo "[WARN] Missing SVG: $input_svg (for $output_png)" >&2
      continue
    fi
    mkdir -p "$(dirname "$output_png")"
    if ! convert_svg_to_png "$input_svg" "$output_png" "$size" "$y_adjust"; then
      echo "[ERROR] Failed to convert $input_svg to $output_png" >&2
      exit 1
    fi
    # (1B) Default glyph output directory for 1024x768 theme (DEFAULT_SIZE_1024x768)
    output_1024x768_png="assets/1024x768/glyph/${output_path}.png"
    size_1024x768=$(adjust_size "$SIZE_1024x768" "$percent_adj")
    mkdir -p "$(dirname "$output_1024x768_png")"
    if ! convert_svg_to_png "$input_svg" "$output_1024x768_png" "$size_1024x768" "$y_adjust"; then
      echo "[ERROR] Failed to convert $input_svg to $output_1024x768_png" >&2
      exit 1
    fi

    # (2A) assets/image/grid/muxlaunch (SIZE_MUXLAUNCH)
    grid_output_png="assets/image/grid/muxlaunch/${output_path#muxlaunch/}.png"
    size=$(adjust_size "$SIZE_MUXLAUNCH" "$percent_adj")
    padding="$PADDING_MUXLAUNCH"
    icon_size=$((size - padding))
    tmp_icon_png="/tmp/$(basename "$grid_output_png" .png)_icon.png"
    mkdir -p "$(dirname "$grid_output_png")"
    if ! convert_svg_to_png "$input_svg" "$tmp_icon_png" "$icon_size" "$y_adjust"; then
      echo "[ERROR] Failed to convert $input_svg to $tmp_icon_png" >&2
      exit 1
    fi
    if ! magick -size "${size}x${size}" canvas:none "$tmp_icon_png" -gravity center -composite "$grid_output_png"; then
      echo "[ERROR] Failed to composite $tmp_icon_png to $grid_output_png" >&2
      exit 1
    fi
    rm -f "$tmp_icon_png"

    # (2B) assets/1024x768/image/grid/muxlaunch (SIZE_MUXLAUNCH_1024x768)
    grid_1024_output_png="assets/1024x768/image/grid/muxlaunch/${output_path#muxlaunch/}.png"
    size=$(adjust_size "$SIZE_MUXLAUNCH_1024x768" "$percent_adj")
    padding="$PADDING_MUXLAUNCH_1024x768"
    icon_size=$((size - padding))
    tmp_icon_png="/tmp/$(basename "$grid_1024_output_png" .png)_icon.png"
    mkdir -p "$(dirname "$grid_1024_output_png")"
    if ! convert_svg_to_png "$input_svg" "$tmp_icon_png" "$icon_size" "$y_adjust"; then
      echo "[ERROR] Failed to convert $input_svg to $tmp_icon_png" >&2
      exit 1
    fi
    if ! magick -size "${size}x${size}" canvas:none "$tmp_icon_png" -gravity center -composite "$grid_1024_output_png"; then
      echo "[ERROR] Failed to composite $tmp_icon_png to $grid_1024_output_png" >&2
      exit 1
    fi
    rm -f "$tmp_icon_png"
    continue
  fi

  if [[ "$output_path" == header/* ]]; then
    # (1A) Default glyph output directory (SIZE_HEADER)
    size=$(adjust_size "$SIZE_HEADER" "$percent_adj")
    if [[ ! -f "$input_svg" ]]; then
      echo "[WARN] Missing SVG: $input_svg (for $output_png)" >&2
      continue
    fi
    mkdir -p "$(dirname "$output_png")"
    if ! convert_svg_to_png "$input_svg" "$output_png" "$size" "$y_adjust"; then
      echo "[ERROR] Failed to convert $input_svg to $output_png" >&2
      exit 1
    fi
    # (1B) assets/1024x768/glyph/header (SIZE_HEADER_1024x768)
    grid_1024_output_png="assets/1024x768/glyph/header/${output_path#header/}.png"
    size=$(adjust_size "$SIZE_HEADER_1024x768" "$percent_adj")
    mkdir -p "$(dirname "$grid_1024_output_png")"
    if ! convert_svg_to_png "$input_svg" "$grid_1024_output_png" "$size" "$y_adjust"; then
      echo "[ERROR] Failed to convert $input_svg to $grid_1024_output_png" >&2
      exit 1
    fi
    continue
  fi

  if [[ "$output_path" == footer/* ]]; then
    # (1A) Default glyph output directory (SIZE_FOOTER)
    size=$(adjust_size "$SIZE_FOOTER" "$percent_adj")
    if [[ ! -f "$input_svg" ]]; then
      echo "[WARN] Missing SVG: $input_svg (for $output_png)" >&2
      continue
    fi
    mkdir -p "$(dirname "$output_png")"
    if ! convert_svg_to_png "$input_svg" "$output_png" "$size" "$y_adjust"; then
      echo "[ERROR] Failed to convert $input_svg to $output_png" >&2
      exit 1
    fi
    # (1B) assets/1024x768/glyph/footer (SIZE_FOOTER_1024x768)
    grid_1024_output_png="assets/1024x768/glyph/footer/${output_path#footer/}.png"
    size=$(adjust_size "$SIZE_FOOTER_1024x768" "$percent_adj")
    mkdir -p "$(dirname "$grid_1024_output_png")"
    if ! convert_svg_to_png "$input_svg" "$grid_1024_output_png" "$size" "$y_adjust"; then
      echo "[ERROR] Failed to convert $input_svg to $grid_1024_output_png" >&2
      exit 1
    fi
    continue
  fi

  # Determine size based on output path
  size="$DEFAULT_SIZE"
  if [[ "$output_path" == muxtester/* ]]; then
    size="$SIZE_MUXTESTER"
  fi
  size=$(adjust_size "$size" "$percent_adj")

  if [[ ! -f "$input_svg" ]]; then
    echo "[WARN] Missing SVG: $input_svg (for $output_png)" >&2
    continue
  fi
  mkdir -p "$(dirname "$output_png")"

  # (1A) Default glyph output directory (DEFAULT_SIZE)
  if ! convert_svg_to_png "$input_svg" "$output_png" "$size" "$y_adjust"; then
    echo "[ERROR] Failed to convert $input_svg to $output_png" >&2
    exit 1
  fi

  # (1B) assets/1024x768/glyph/<output_path> for 1024x768 theme (SIZE_1024x768)
  output_1024x768_png="assets/1024x768/glyph/${output_path}.png"
  size_1024x768=$(adjust_size "$SIZE_1024x768" "$percent_adj")
  mkdir -p "$(dirname "$output_1024x768_png")"
  if ! convert_svg_to_png "$input_svg" "$output_1024x768_png" "$size_1024x768" "$y_adjust"; then
    echo "[ERROR] Failed to convert $input_svg to $output_1024x768_png" >&2
    exit 1
  fi

done <"$MAPPING_FILE"

echo "[INFO] All glyphs generated in $OUT_DIR"
