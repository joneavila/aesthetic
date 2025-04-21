#!/bin/bash
# Build and deploy Aesthetic for muOS handhelds
#
# Usage: 
#   ./build.sh [--clean] [<PRIVATE_KEY_PATH>] [<HANDHELD_IP>]
#
# Options:
#   --clean           Remove previous installation files before deploying
#   PRIVATE_KEY_PATH  SSH private key for authentication
#   HANDHELD_IP       IP address of the target muOS handheld
#
# When PRIVATE_KEY_PATH and HANDHELD_IP are provided, the package is deployed to the handheld via SSH
#
# Examples:
#   ./build.sh
#   ./build.sh ~/.ssh/id_ed25519 192.168.68.123
#   ./build.sh --clean ~/.ssh/id_ed25519 192.168.68.123

# Display formatted message
echoHeader() {
    local text="$1"
    local MAGENTA="\033[35m"
    local RESET="\033[0m"
    echo -e "${MAGENTA}${text}...${RESET}"
}

# Verify SSH connection to the handheld
checkConnection() {
    if [ -n "$PRIVATE_KEY_PATH" ] && [ -n "$HANDHELD_IP" ]; then
        echoHeader "Checking connection to $HANDHELD_IP"
        if ! ssh -i "${PRIVATE_KEY_PATH}" -o ConnectTimeout=5 -o BatchMode=yes root@"${HANDHELD_IP}" exit 2>/dev/null; then
            echo "Error: Could not connect to ${HANDHELD_IP}. Exiting."
            exit 1
        fi
        echo "Connection successful"
    fi
}

# Process command line arguments
if [[ "$1" == "--clean" ]]; then
    CLEAN=true
    shift
else
    CLEAN=false
fi
PRIVATE_KEY_PATH=$1
HANDHELD_IP=$2

# Verify connection if credentials are provided
# Assume the connection remains stable for the duration of the script
if [ -n "$PRIVATE_KEY_PATH" ] && [ -n "$HANDHELD_IP" ]; then
    checkConnection
fi

# Local directories
DIST_DIR=".dist"
BUILD_DIR=".build"

# Handheld directories
APP_DIR="mnt/mmc/MUOS/application/Aesthetic"
APP_GLYPH_DIR="opt/muos/default/MUOS/theme/active/glyph/muxapp"

ARCHIVE_BASE_NAME=Aesthetic

echoHeader "Setting up clean build environment"
rm -rf "${DIST_DIR}" "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"
mkdir -p "${BUILD_DIR}/${APP_DIR}"
mkdir -p "${BUILD_DIR}/${APP_DIR}/.aesthetic"
mkdir -p "${BUILD_DIR}/${APP_GLYPH_DIR}"

# Extract version information from Lua source
MAJOR=$(awk '/version.major =/ {print $3}' src/version.lua)
MINOR=$(awk '/version.minor =/ {print $3}' src/version.lua)
PATCH=$(awk '/version.patch =/ {print $3}' src/version.lua)
PRERELEASE=$(awk '/version.prerelease =/ {if ($3 != "nil") print $3}' src/version.lua | sed 's/"//g')
VERSION="v${MAJOR}.${MINOR}.${PATCH}"
if [ ! -z "$PRERELEASE" ]; then
    VERSION="${VERSION}-${PRERELEASE}"
fi

# Files to remove when using --clean option
# Targets both SD1 (/mnt/mmc/) and SD2 (/mnt/sdcard/) locations
ITEMS_TO_DELETE=(
    "/mnt/mmc/MUOS/application/Aesthetic"
    "/mnt/mmc/MUOS/theme/active/glyph/muxapp/aesthetic.png"
    "/mnt/sdcard/MUOS/theme/active/glyph/muxapp/aesthetic.png"
    "/mnt/mmc/MUOS/theme/Aesthetic*.muxthm"
    "/mnt/sdcard/MUOS/theme/Aesthetic*.muxthm"
    "/mnt/mmc/ARCHIVE/Aesthetic_*.muxupd"
    "/mnt/sdcard/ARCHIVE/Aesthetic_*.muxupd"
    "/mnt/mmc/MUOS/update/installed/Aesthetic_*.muxupd.done"
    "/opt/muos/default/MUOS/theme/active/glyph/muxapp/aesthetic.png"
)

# Remove previous installation files if requested
if [ "$CLEAN" = true ]; then
    if [ -z "$PRIVATE_KEY_PATH" ] || [ -z "$HANDHELD_IP" ]; then
        echo "Error: --clean requires both PRIVATE_KEY_PATH and HANDHELD_IP"
        exit 1
    fi
    
    echoHeader "Removing existing files on $HANDHELD_IP"
    
    # Process deletion commands individually to handle wildcards
    for file in "${ITEMS_TO_DELETE[@]}"; do
        # Remove leading ./ if present
        remote_file="${file#./}"
        
        if [[ "$remote_file" == *"*"* ]]; then
            ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "for f in ${remote_file}; do if [ -e \"\$f\" ]; then rm -rf \"\$f\" && echo \"\$f\"; fi; done"
        else
            ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "if [ -e '${remote_file}' ]; then rm -rf '${remote_file}' && echo '${remote_file}'; fi"
        fi
    done
    
    # Force sync to ensure all changes are written to disk
    echoHeader "Syncing filesystem on $HANDHELD_IP"
    ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "sync && echo 'Filesystem sync completed'"
    
fi

# Copy application files to build directory
echoHeader "Copying files to build directory"
rsync -aq mux_launch.sh "${BUILD_DIR}/${APP_DIR}" && echo "mux_launch.sh" || { echo "Failed to copy mux_launch.sh"; exit 1; }
rsync -aq src/ "${BUILD_DIR}/${APP_DIR}/.aesthetic/" && echo "src/" || { echo "Failed to copy src/"; exit 1; }
rsync -aq bin/ "${BUILD_DIR}/${APP_DIR}/.aesthetic/bin" && echo "bin/" || { echo "Failed to copy bin/"; exit 1; }
rsync -aq lib/ "${BUILD_DIR}/${APP_DIR}/.aesthetic/lib" && echo "lib/" || { echo "Failed to copy lib/"; exit 1; }
rsync -aq src/tove/ "${BUILD_DIR}/${APP_DIR}/.aesthetic/tove" && echo "src/tove/" || { echo "Failed to copy src/tove/"; exit 1; }
rsync -aq src/template/glyph/muxapp/aesthetic.png "${BUILD_DIR}/${APP_GLYPH_DIR}" && echo "aesthetic.png" || { echo "Failed to copy aesthetic.png"; exit 1; }

# Create .muxupd archive
echoHeader "Creating archive"
# Exclude macOS system files when archiving
(cd "${BUILD_DIR}" && zip -9qr "../${DIST_DIR}/${ARCHIVE_BASE_NAME}_${VERSION}.muxupd" * -x "*.DS_Store" -x "._*") && echo "${ARCHIVE_BASE_NAME}_${VERSION}.muxupd" || { echo "Failed to create archive"; exit 1; }

# Clean up temporary files
echoHeader "Cleaning up"
rm -rf "${BUILD_DIR}" && echo "Removed build directory" || echo "Failed to remove build directory"

echoHeader "Uploading to $HANDHELD_IP"
if [ -z "$PRIVATE_KEY_PATH" ]; then
    echo "No PRIVATE_KEY_PATH provided"
    exit 0
elif [ -z "$HANDHELD_IP" ]; then
    echo "No HANDHELD_IP provided"
    exit 0
else
    scp -i "${PRIVATE_KEY_PATH}" "${DIST_DIR}/${ARCHIVE_BASE_NAME}_${VERSION}.muxupd" root@"${HANDHELD_IP}":/mnt/mmc/ARCHIVE
    echoHeader "Extracting on $HANDHELD_IP"
    ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "bash /opt/muos/script/mux/extract.sh /mnt/mmc/ARCHIVE/${ARCHIVE_BASE_NAME}_${VERSION}.muxupd"
fi

# Automatically launch application after deployment
# TODO: The following command does not work as expected
# ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "bash /mnt/mmc/MUOS/application/Aesthetic/mux_launch.sh"