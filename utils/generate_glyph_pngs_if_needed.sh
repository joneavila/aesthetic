#!/bin/bash

# SVG to PNG Conversion Optimization Wrapper
#
# This script checks if any relevant SVG source files or the mapping file have changed
# since the last icon conversion. If so, it runs generate_glyph_pngs.sh and updates the cache.
#
# Limitations:
# - Will not detect if output PNG files are manually deleted or corrupted.
# - Timestamp precision depends on your filesystem (may miss rapid changes).
# - Does not validate successful completion of the conversion script.
# - Only tracks changes to the mapping file and SVG sources (not the conversion script itself).
# - If new SVG directories are added, they must be under assets/icons/ to be detected.
#
# Usage: ./generate_glyph_pngs_if_needed.sh

set -euo pipefail

CACHE_FILE="$(dirname "$0")/.icon_cache_timestamps"
MAPPING_FILE="$(dirname "$0")/glyph_mapping.txt"
SVG_DIR="assets/icons"
CONVERT_SCRIPT="$(dirname "$0")/generate_glyph_pngs.sh"

# Get all relevant file timestamps (mapping file + all SVGs)
get_current_timestamps() {
    # Mapping file timestamp
    if [ -f "$MAPPING_FILE" ]; then
        stat -f "%m %N" "$MAPPING_FILE"
    fi
    # All SVG file timestamps (recursively)
    if [ -d "$SVG_DIR" ]; then
        find "$SVG_DIR" -type f -name "*.svg" -exec stat -f "%m %N" {} \; | sort
    fi
}

# Check if conversion is needed
needs_conversion() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 0 # Cache doesn't exist, need conversion
    fi
    current_timestamps="$(get_current_timestamps)"
    cached_timestamps="$(cat "$CACHE_FILE" 2>/dev/null || echo "")"
    [ "$current_timestamps" != "$cached_timestamps" ]
}

run_conversion() {
    echo "[INFO] Converting SVG icons to PNG..."
    bash "$CONVERT_SCRIPT"
    get_current_timestamps >"$CACHE_FILE"
}

# Main logic
if needs_conversion; then
    run_conversion
else
    echo "[INFO] No changes detected, skipping icon conversion."
fi
