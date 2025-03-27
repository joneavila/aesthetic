#!/bin/bash
# Usage: ./scripts/build.sh [--clean] [<PRIVATE_KEY_PATH>] [<DEVICE_IP>]
#
# If PRIVATE_KEY_PATH and DEVICE_IP are provided, the archive will be uploaded to the device using scp
# If --clean is provided, the script will delete files from the device (left over from previous builds)
# before building a new version

# Check for --clean option
if [[ "$1" == "--clean" ]]; then
    CLEAN=true
    shift
else
    CLEAN=false
fi

PRIVATE_KEY_PATH=$1
DEVICE_IP=$2

APPLICATION_DIR=mnt/mmc/MUOS/application/Aesthetic

LOG_DIR="${APPLICATION_DIR}/.aesthetic/logs"
mkdir -p "${LOG_DIR}"


GLYPH_DIR=opt/muos/default/MUOS/theme/active/glyph/muxapp
ARCHIVE_BASE_NAME=Aesthetic



# Get version from src/version.lua
MAJOR=$(awk '/version.major =/ {print $3}' src/version.lua)
MINOR=$(awk '/version.minor =/ {print $3}' src/version.lua)
PATCH=$(awk '/version.patch =/ {print $3}' src/version.lua)
PRERELEASE=$(awk '/version.prerelease =/ {if ($3 != "nil") print $3}' src/version.lua | sed 's/"//g')

VERSION="v${MAJOR}.${MINOR}.${PATCH}"
if [ ! -z "$PRERELEASE" ]; then
    VERSION="${VERSION}-${PRERELEASE}"
fi

# Items to delete with --clean
ITEMS_TO_DELETE=(
    "/.local/share/love/Aesthetic"
    "/mnt/mmc/MUOS/application/Aesthetic"
    "/run/muos/storage/theme/Aesthetic.muxthm"
    "/mnt/sdcard/MUOS/theme/active/glyph/muxapp/aesthetic.png"
    "/mnt/sdcard/MUOS/theme/Aesthetic*.muxthm"
    "/mnt/mmc/ARCHIVE/Aesthetic_*.muxupd"
    "/mnt/mmc/MUOS/update/installed/Aesthetic_*.muxupd.done"
    "/opt/muos/default/MUOS/theme/active/glyph/muxapp/aesthetic.png"
)

if [ "$CLEAN" = true ]; then
    if [ -z "$PRIVATE_KEY_PATH" ] || [ -z "$DEVICE_IP" ]; then
        echo "Error: --clean requires both PRIVATE_KEY_PATH and DEVICE_IP"
        exit 1
    fi
    
    echo "Cleaning..."
    
    # Execute delete commands one by one to better handle wildcards
    for file in "${ITEMS_TO_DELETE[@]}"; do
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
rsync -a mux_launch.sh .build/"${APPLICATION_DIR}"
rsync -av src/ .build/"${APPLICATION_DIR}"/.aesthetic/

# Debug: Check if SVG was copied
if [ -f ".build/${APPLICATION_DIR}/.aesthetic/assets/muOS/logo.svg" ]; then
    echo "SVG file copied successfully"
    ls -l ".build/${APPLICATION_DIR}/.aesthetic/assets/muOS/logo.svg"
else
    echo "ERROR: SVG file not found in build directory!"
    exit 1
fi

rsync -a bin/ .build/"${APPLICATION_DIR}"/.aesthetic/bin
rsync -a lib/ .build/"${APPLICATION_DIR}"/.aesthetic/lib
rsync -a src/tove/ .build/"${APPLICATION_DIR}"/.aesthetic/tove
# rsync -a src/ .build/"${APPLICATION_DIR}"

# Check for required directories and files
if [ ! -d "src/tove" ]; then
    echo "ERROR: 'tove' directory not found!"
    echo "Please ensure the Tove library is installed in the 'tove' directory"
    echo "Expected location: ./tove/libTove.so"
    exit 1
fi

if [ ! -f "src/tove/libTove.so" ]; then
    echo "ERROR: 'libTove.so' not found!"
    echo "Please ensure the Tove library is installed at: ./src/tove/libTove.so"
    exit 1
fi



# Debug: Check if Tove library exists and has correct permissions
if [ -f ".build/${APPLICATION_DIR}/.aesthetic/tove/libTove.so" ]; then
    echo "Tove library found"
    ls -l ".build/${APPLICATION_DIR}/.aesthetic/tove/libTove.so"
else
    echo "ERROR: Tove library not found!"
    exit 1
fi

# Copy application glyph
mkdir -p .build/"${GLYPH_DIR}"
rsync -a src/template/glyph/muxapp/aesthetic.png .build/"${GLYPH_DIR}"

# Create archive, exclude macOS system files
(cd .build && zip -9r "../.dist/${ARCHIVE_BASE_NAME}_${VERSION}.muxupd" * -x "*.DS_Store" -x "._*")

# Delete temporary build directory
rm -rf .build

if [ -z "$PRIVATE_KEY_PATH" ]; then
    echo "No PRIVATE_KEY_PATH provided, skipping SCP upload"
    exit 0
elif [ -z "$DEVICE_IP" ]; then
    echo "No DEVICE_IP provided, skipping SCP upload"
    exit 0
else
    echo "Uploading to $DEVICE_IP"
    scp -i "${PRIVATE_KEY_PATH}" .dist/"${ARCHIVE_BASE_NAME}_${VERSION}.muxupd" root@"${DEVICE_IP}":/mnt/mmc/ARCHIVE
    
    # Set proper permissions for libraries
    ssh -i "${PRIVATE_KEY_PATH}" root@"${DEVICE_IP}" "chmod 755 /mnt/mmc/MUOS/application/Aesthetic/.aesthetic/tove/libTove.so"
fi

echo "Done!"