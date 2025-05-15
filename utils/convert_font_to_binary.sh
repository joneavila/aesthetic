#!/bin/bash

# This script converts a font file to binary format using lv_font_conv.
# lv_font_conv must be installed and accessible in PATH.
# The converted font is saved in the same directory as the input font file, with the same name, e.g.,
# ./fonts/comic-sans.ttf -> ./fonts/comic_sans_24.bin
#
# Usage:
#   ./convert_font_to_binary.sh <path-to-font-file> [size]
#
# Examples:
#   # Convert font with default size (24px)
#   ./convert_font_to_binary.sh ./fonts/comic-sans.ttf
#
#   # Convert font with custom size (28px)
#   ./convert_font_to_binary.sh ./fonts/comic-sans.ttf 28
#
# Output:
#   
#   Example: ./fonts/roboto.ttf -> ./fonts/roboto_24.bin

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-font-file> [size]"
    echo "size: Optional font size (default: 24)"
    exit 1
fi

font_path="$1"

if [ ! -f "$font_path" ]; then
    echo "Error: Font file '$font_path' does not exist"
    exit 1
fi

size=${2:-24}

dir_path=$(dirname "$font_path")
filename=$(basename "$font_path")
filename_no_ext="${filename%.*}"

# Format the filename: lowercase, replace dashes with underscores, append size
formatted_filename=$(echo "$filename_no_ext" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
output_path="${dir_path}/${formatted_filename}_${size}.bin"

# See: https://muos.dev/themes/fonts.html#using-the-script
lv_font_conv --bpp 4 --size "$size" --font "$font_path" -r 0x00-0xFF --format bin --no-compress --no-prefilter -o "$output_path"

if [ $? -eq 0 ]; then
    echo "Font conversion completed successfully"
    echo "Output saved to: $output_path"
else
    echo "Error: Font conversion failed"
    exit 1
fi 