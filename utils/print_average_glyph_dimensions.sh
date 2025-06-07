#!/bin/bash

# Prints the average dimensions of PNG glyphs in a directory.
# Useful for finding the average dimensions of a glyph in the default muOS theme.
#
# Usage: print_average_glyph_dimensions.sh [--mux-only] <path-to-glyph-directory>
#   --mux-only   Only include PNG files under directories beginning with "mux"

total_width=0
total_height=0
count=0
mux_only=0

display_usage() {
    echo "Usage: $0 [--mux-only] <directory>"
    echo "  --mux-only   Only include PNG files under directories beginning with 'mux'"
}

# Parse arguments
if [ "$1" == "--mux-only" ]; then
    mux_only=1
    shift
fi

directory="$1"
if [ -z "$directory" ]; then
    display_usage
    exit 1
fi

if ! command -v sips &> /dev/null; then
    echo "Error: 'sips' command not found. This script requires the 'sips' command (macOS)."
    exit 1
fi

find_png_files_recurse() {
    local directory="$1"
    if [ "$mux_only" -eq 1 ]; then
        # Only search in subdirectories starting with mux*
        find "$directory" -type d -name "mux*" | while IFS= read -r muxdir; do
            find "$muxdir" -type f -iname "*.png"
        done
    else
        find "$directory" -type f -iname "*.png"
    fi
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