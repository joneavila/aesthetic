#!/bin/bash
# This script always runs when installing or updating Aesthetic. It performs necessary migration steps and cleans up
# old files that are no longer part of the current version.

# Source muOS system functions for path resolution
. /opt/muos/script/var/func.sh # For `GET_VAR`

# Directory and file paths
# Use the same path resolution as mux_launch.sh
ROOT_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Aesthetic"
APP_DIR="$ROOT_DIR" # Keep for backward compatibility
SOURCE_DIR="$APP_DIR/.aesthetic"
OLD_SETTINGS_PATH="$SOURCE_DIR/settings.lua"       # v1.5.1
NEW_SETTINGS_DIR="$APP_DIR/userdata"               # v1.6.0 and later
NEW_SETTINGS_PATH="$NEW_SETTINGS_DIR/settings.lua" # v1.6.0 and later
USERDATA_PRESETS_DIR="$NEW_SETTINGS_DIR/presets"   # User-created presets directory

echo "[Aesthetic Update Script]"

# Function to migrate renamed variables in user files
migrate_renamed_variables() {
    echo "Checking for variable name migrations..."

    local files_updated=0

    # Define the variable mappings (old_name -> new_name)
    local -A variable_mappings=(
        ["headerTextAlignment"]="headerAlignment"
        ["headerTextAlpha"]="headerOpacity"
        ["navigationAlpha"]="navigationOpacity"
        ["selectedFont"]="fontFamily"
    )

    # Function to perform replacements in a single file
    perform_replacements() {
        local file_path="$1"
        local temp_file=$(mktemp)
        local file_changed=false

        cp "$file_path" "$temp_file"

        for old_var in "${!variable_mappings[@]}"; do
            local new_var="${variable_mappings[$old_var]}"

            # Replace variable assignments (e.g., headerTextAlignment = value)
            if sed "s/\b${old_var}\s*=/\t${new_var} =/g" "$temp_file" >"$temp_file.tmp" && ! cmp -s "$temp_file" "$temp_file.tmp"; then
                mv "$temp_file.tmp" "$temp_file"
                file_changed=true
            else
                rm -f "$temp_file.tmp"
            fi
        done

        if [ "$file_changed" = true ]; then
            mv "$temp_file" "$file_path"
            return 0
        else
            rm -f "$temp_file"
            return 1
        fi
    }

    # Migrate settings.lua if it exists
    if [ -f "$NEW_SETTINGS_PATH" ]; then
        echo "Checking settings.lua for variable migrations..."
        if perform_replacements "$NEW_SETTINGS_PATH"; then
            echo "Updated variable names in settings.lua"
            ((files_updated++))
        fi
    fi

    # Migrate user-created preset files
    if [ -d "$USERDATA_PRESETS_DIR" ]; then
        echo "Checking user-created preset files for variable migrations..."

        # Find all .lua files in the presets directory
        while IFS= read -r -d '' preset_file; do
            if perform_replacements "$preset_file"; then
                local filename=$(basename "$preset_file")
                echo "Updated variable names in preset: $filename"
                ((files_updated++))
            fi
        done < <(find "$USERDATA_PRESETS_DIR" -name "*.lua" -type f -print0 2>/dev/null)
    fi

    if [ $files_updated -gt 0 ]; then
        echo "Variable migration completed: $files_updated files updated"
    else
        echo "No variable migrations needed"
    fi
}

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
    done <"$manifest_file"

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

# Migrate renamed variables in user files (settings and presets)
migrate_renamed_variables

# Clean up old source files for existing installations only
if [ -d "$SOURCE_DIR" ]; then
    echo "Source directory exists - performing cleanup for existing installation..."
    cleanup_old_source_files
else
    echo "No source directory found - skipping cleanup for new installation"
fi

# Final status message
echo "Update completed successfully!"
