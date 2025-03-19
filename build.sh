#!/bin/bash
# Usage: ./build.sh [--clean] [<PRIVATE_KEY_PATH>] [<DEVICE_IP>]
# If PRIVATE_KEY_PATH and DEVICE_IP are provided, the archive will be uploaded to the device with `scp`
# If --clean is provided, the script will first delete specified files on the device

CLEAN=false
PRIVATE_KEY_PATH=""
DEVICE_IP=""

# Process arguments
for arg in "$@"; do
    if [ "$arg" == "--clean" ]; then
        CLEAN=true
    elif [ -z "$PRIVATE_KEY_PATH" ]; then
        PRIVATE_KEY_PATH="$arg"
    elif [ -z "$DEVICE_IP" ]; then
        DEVICE_IP="$arg"
    fi
done

APPLICATION_DIR=mnt/mmc/MUOS/application/Aesthetic
GLYPH_DIR=opt/muos/default/MUOS/theme/active/glyph/muxapp
ZIP_BASE_NAME=Aesthetic

# Files to delete when --clean is used
FILES_TO_DELETE=(
    "/.local/share/love/Aesthetic"
    "/mnt/mmc/MUOS/application/Aesthetic"
    "/run/muos/storage/theme/Aesthetic.muxthm"
    "/mnt/sdcard/MUOS/theme/active/glyph/muxapp/aesthetic.png"
    "/mnt/mmc/ARCHIVE/Aesthetic_*.muxupd"
    "/mnt/mmc/MUOS/update/installed/Aesthetic_*.muxupd.done"
    "/opt/muos/default/MUOS/theme/active/glyph/muxapp/aesthetic.png"
)

# Get version from version.lua
MAJOR=$(awk '/version.major =/ {print $3}' src/version.lua)
MINOR=$(awk '/version.minor =/ {print $3}' src/version.lua)
PATCH=$(awk '/version.patch =/ {print $3}' src/version.lua)
VERSION="v${MAJOR}.${MINOR}.${PATCH}"

# Clean files on device if requested
if [ "$CLEAN" = true ]; then
    if [ -z "$PRIVATE_KEY_PATH" ] || [ -z "$DEVICE_IP" ]; then
        echo "Error: --clean requires both PRIVATE_KEY_PATH and DEVICE_IP"
        exit 1
    fi
    
    echo "Cleaning files on device ${DEVICE_IP}..."
    
    # Execute delete commands one by one to better handle wildcards
    for file in "${FILES_TO_DELETE[@]}"; do
        # Remove leading ./ if present
        remote_file="${file#./}"
        
        # Handle files with wildcards differently
        if [[ "$remote_file" == *"*"* ]]; then
            ssh -i "${PRIVATE_KEY_PATH}" root@"${DEVICE_IP}" "for f in ${remote_file}; do if [ -e \"\$f\" ]; then echo \"Found: \$f\"; rm -rf \"\$f\" && echo \"Deleted: \$f\"; else echo \"No matching files for pattern: ${remote_file}\"; fi; done"
        else
            ssh -i "${PRIVATE_KEY_PATH}" root@"${DEVICE_IP}" "if [ -e '${remote_file}' ]; then rm -rf '${remote_file}' && echo 'Deleted: ${remote_file}'; else echo 'Not found: ${remote_file}'; fi"
        fi
    done
    
    echo "Clean completed."
fi

mkdir -p .dist
mkdir -p .build/"${APPLICATION_DIR}"
mkdir -p .build/"${GLYPH_DIR}"

rsync -a mux_launch.sh .build/"${APPLICATION_DIR}"
rsync -a bin/ .build/"${APPLICATION_DIR}"
rsync -a lib/ .build/"${APPLICATION_DIR}"
rsync -a src/ .build/"${APPLICATION_DIR}"
rsync -a src/template/glyph/muxapp/aesthetic.png .build/"${GLYPH_DIR}/aesthetic.png"

# Create archive, exclude .DS_Store files
(cd .build && zip -9r "../.dist/${ZIP_BASE_NAME}_${VERSION}.muxupd" * -x "*.DS_Store")

# Clean up build directory
rm -rf .build

if [ -z "$PRIVATE_KEY_PATH" ]; then
    echo "No PRIVATE_KEY_PATH provided, skipping SCP upload"
    exit 0
elif [ -z "$DEVICE_IP" ]; then
    echo "No DEVICE_IP provided, skipping SCP upload"
    exit 0
else
    echo "Uploading to $DEVICE_IP"
    scp -i "${PRIVATE_KEY_PATH}" .dist/"${ZIP_BASE_NAME}_${VERSION}.muxupd" root@"${DEVICE_IP}":/mnt/mmc/ARCHIVE
fi

echo "Done!"