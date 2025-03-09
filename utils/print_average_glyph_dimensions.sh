#!/bin/bash

# Prints the average dimensions of PNG glyphs in a directory.
# Useful for finding the average dimensions of a glyph in the default muOS theme.
#
# Usage: print_average_glyph_dimensions.sh <path-to-glyph-directory>

total_width=0
total_height=0
count=0

find_png_files_recurse() {
    local directory="$1"
    find "$directory" -type f -iname "*.png"
}

get_image_dimensions() {
    local image_file="$1"
    dimensions=$(sips -g pixelWidth -g pixelHeight "$image_file" 2>/dev/null)
    width=$(echo "$dimensions" | grep "pixelWidth" | awk '{print $2}')
    height=$(echo "$dimensions" | grep "pixelHeight" | awk '{print $2}')
    if [ -n "$width" ] && [ -n "$height" ]; then
        total_width=$((total_width + width))
        total_height=$((total_height + height))
        count=$((count + 1))
    fi
}

directory="$1"
if [ -z "$directory" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

if ! command -v sips &> /dev/null; then
    echo "Error: 'sips' command not found. This script requires the 'sips' command (macOS)."
    exit 1
fi

found_files=0
while IFS= read -r png_file; do
    get_image_dimensions "$png_file"
    found_files=$((found_files + 1))
done < <(find_png_files_recurse "$directory")

if [ "$found_files" -gt 0 ]; then
    avg_width=$((total_width / found_files))
    avg_height=$((total_height / found_files))
    echo "Average width: $avg_width"
    echo "Average height: $avg_height"
else
    echo "No PNG files found in the directory."
fi