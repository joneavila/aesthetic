#!/bin/bash
# This script always runs when installing or updating Aesthetic. It performs necessary migration steps and cleans up
# old files that are no longer part of the current version.

# Directory and file paths
APP_DIR="/mnt/mmc/MUOS/application/Aesthetic"
SOURCE_DIR="$APP_DIR/.aesthetic"
OLD_SETTINGS_PATH="$SOURCE_DIR/settings.lua"       # v1.5.1
NEW_SETTINGS_DIR="$APP_DIR/userdata"               # v1.6.0 and later
NEW_SETTINGS_PATH="$NEW_SETTINGS_DIR/settings.lua" # v1.6.0 and later

echo "[Aesthetic Update Script]"

# Function to clean up old source files not part of the current version
cleanup_old_source_files() {
    if [ ! -d "$SOURCE_DIR" ]; then
        return
    fi
    
    local manifest_file="$SOURCE_DIR/.manifest"
    if [ ! -f "$manifest_file" ]; then
        echo "No manifest file found, skipping cleanup"
        return
    fi
    
    # Read manifest into array (files that should exist)
    local expected_files=()
    while IFS= read -r line; do
        # Remove leading ./ if present
        line="${line#./}"
        if [ -n "$line" ]; then
            expected_files+=("$line")
        fi
    done < "$manifest_file"
    
    echo "Manifest contains ${#expected_files[@]} expected files"
    
    # Find all existing files (excluding the manifest itself for now)
    local existing_files=()
    while IFS= read -r -d '' file; do
        local rel_path="${file#$SOURCE_DIR/}"
        if [ "$rel_path" != ".manifest" ]; then
            existing_files+=("$rel_path")
        fi
    done < <(find "$SOURCE_DIR" -type f -not -name ".manifest" -print0)
    
    # Convert expected_files array to associative array for O(1) lookup
    local -A expected_files_map
    for file in "${expected_files[@]}"; do
        expected_files_map["$file"]=1
    done
    
    # Remove files that exist but are not in manifest
    local removed_count=0
    echo "Checking ${#existing_files[@]} existing files against manifest..."
    for existing_file in "${existing_files[@]}"; do
        if [[ ! "${expected_files_map[$existing_file]}" ]]; then
            rm -f "$SOURCE_DIR/$existing_file"
            ((removed_count++))
        fi
    done
    
    # Remove empty directories
    find "$SOURCE_DIR" -type d -empty -delete 2>/dev/null || true
    
    echo "Removed $removed_count old files"
}

# Settings migration: Move settings from old location to new location if needed
# This handles migration from v1.5.1 and earlier versions to v1.6.0+
# We use file existence check instead of version check since this script runs after installation
if [ -f "$OLD_SETTINGS_PATH" ]; then
    echo "Found existing settings file at: $OLD_SETTINGS_PATH"
    
    # Create the new userdata directory if it doesn't exist
    if [ ! -d "$NEW_SETTINGS_DIR" ]; then
        echo "Creating userdata directory: $NEW_SETTINGS_DIR"
        mkdir -p "$NEW_SETTINGS_DIR"
    fi
    
    # Move the settings file to the new location
    echo "Moving settings.lua to: $NEW_SETTINGS_PATH"
    mv "$OLD_SETTINGS_PATH" "$NEW_SETTINGS_PATH"
    
    if [ $? -eq 0 ]; then
        echo "Settings migration completed successfully"
    else
        echo "Error: Failed to move settings file"
        exit 1
    fi
else
    echo "No old settings file found - migration not needed"
fi

# Clean up old source files for existing installations only
if [ -d "$SOURCE_DIR" ]; then
    echo "Source directory exists - performing cleanup for existing installation..."
    cleanup_old_source_files
else
    echo "No source directory found - skipping cleanup for new installation"
fi

# Final status message
echo "Update completed successfully!"