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

# Print in color
echoHeader() {
    local text="$1"
    local CYAN="\033[36m"
    local RESET="\033[0m"
    echo -e "${CYAN}${text}${RESET}"
}

# Print in color to stderr
echoError() {
    local text="$1"
    local RED="\033[31m"
    local RESET="\033[0m"
    echo -e "${RED}${text}${RESET}" >&2
}

# Verify SSH connection to the handheld
checkConnection() {
    if [ -n "$PRIVATE_KEY_PATH" ] && [ -n "$HANDHELD_IP" ]; then
        echoHeader "Checking connection to $HANDHELD_IP"
        
        # Set up verbose output capture for SSH connection attempt
        SSH_OUTPUT=$(ssh -i "${PRIVATE_KEY_PATH}" -o ConnectTimeout=5 -o BatchMode=yes root@"${HANDHELD_IP}" exit 2>&1)
        SSH_STATUS=$?
        
        if [ $SSH_STATUS -ne 0 ]; then
            echo "${SSH_OUTPUT}"
            echoError "Error: Could not connect to ${HANDHELD_IP}."
            if [[ "$SSH_OUTPUT" == *"Host key verification failed"* ]]; then
                echo "Your handheld's IP address may have changed, try:"
                echo "  ssh-keygen -R ${HANDHELD_IP}"
                echo "  ssh -o StrictHostKeyChecking=accept-new root@${HANDHELD_IP} exit"
                echo "Consider setting up reserved IPs in your router to prevent changes."
            elif [[ "$SSH_OUTPUT" == *"Permission denied"* ]]; then
                echo "Your SSH key may not be authorized on the device. Try:"
                echo "  ssh-copy-id -i ${PRIVATE_KEY_PATH}.pub root@${HANDHELD_IP}"
            elif [[ "$SSH_OUTPUT" == *"Connection refused"* ]]; then
                echo "Your handheld may not have SSH enabled. Try enabling it in mUOS settings."
            elif [[ "$SSH_OUTPUT" == *"Connection timed out"* ]]; then
                echo "Check that your handheld is powered on and connected to your network."
            fi
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

# This would be a .muxupd if there were an additional `update.sh` script in `opt/`: https://muos.dev/help/archive
ARCHIVE_TYPE="muxzip"

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
# Targets both .muxupd and .muxzip archives
ITEMS_TO_DELETE=(
    "/mnt/mmc/MUOS/application/Aesthetic"
    "/mnt/mmc/MUOS/theme/active/glyph/muxapp/aesthetic.png"
    "/mnt/sdcard/MUOS/theme/active/glyph/muxapp/aesthetic.png"
    "/mnt/mmc/MUOS/theme/Aesthetic*.muxthm"
    "/mnt/sdcard/MUOS/theme/Aesthetic*.muxthm"
    "/mnt/mmc/ARCHIVE/Aesthetic_*.muxupd"
    "/mnt/mmc/ARCHIVE/Aesthetic_*.muxzip"
    "/mnt/sdcard/ARCHIVE/Aesthetic_*.muxupd"
    "/mnt/sdcard/ARCHIVE/Aesthetic_*.muxzip"
    "/mnt/mmc/MUOS/update/installed/Aesthetic_*.muxupd.done"
    "/mnt/mmc/MUOS/update/installed/Aesthetic_*.muxzip.done"
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
rsync -aq assets/ "${BUILD_DIR}/${APP_DIR}/.aesthetic/assets" && echo "assets/" || { echo "Failed to copy assets/"; exit 1; }
rsync -aq assets/icons/glyph/muxapp/aesthetic.png "${BUILD_DIR}/${APP_GLYPH_DIR}" && echo "aesthetic.png" || { echo "Failed to copy aesthetic.png"; exit 1; }

echoHeader "Creating archive"
# Exclude macOS system files when archiving
(cd "${BUILD_DIR}" && zip -9qr "../${DIST_DIR}/${ARCHIVE_BASE_NAME}_${VERSION}.${ARCHIVE_TYPE}" * -x "*.DS_Store" -x "._*") && echo "${ARCHIVE_BASE_NAME}_${VERSION}.${ARCHIVE_TYPE}" || { echo "Failed to create archive"; exit 1; }

echoHeader "Cleaning up temporary files"
rm -rf "${BUILD_DIR}" && echo "Removed build directory" || echo "Failed to remove build directory"

if [ -z "$PRIVATE_KEY_PATH" ] && [ -z "$HANDHELD_IP" ]; then
    echo "Skipping upload. To enable automatic upload, provide PRIVATE_KEY_PATH and HANDHELD_IP arguments."
    echo "Done!"
    exit 0
fi

if [ -z "$PRIVATE_KEY_PATH" ] || [ -z "$HANDHELD_IP" ]; then
    echo "Skipping upload. To enable automatic upload, provide PRIVATE_KEY_PATH and HANDHELD_IP arguments."
    echo "Done!"
    exit 0
fi

echoHeader "Uploading to $HANDHELD_IP"
scp -i "${PRIVATE_KEY_PATH}" "${DIST_DIR}/${ARCHIVE_BASE_NAME}_${VERSION}.${ARCHIVE_TYPE}" root@"${HANDHELD_IP}":/mnt/mmc/ARCHIVE

echoHeader "Extracting on $HANDHELD_IP"
ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "bash /opt/muos/script/mux/extract.sh /mnt/mmc/ARCHIVE/${ARCHIVE_BASE_NAME}_${VERSION}.${ARCHIVE_TYPE}"

# echoHeader "Attempting to run"
# ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "echo 'flip' > /tmp/act_go"

echo "Done!"

