#!/bin/bash
# Build and deploy Aesthetic for muOS handhelds
#
# Usage:
#   ./build.sh [--clean] [--launch] [<PRIVATE_KEY_PATH>] [<HANDHELD_IP>]
#
# Options:
#   --clean           Remove previous installation files before deploying
#   --launch          Launch the application after deploying
#   PRIVATE_KEY_PATH  SSH private key for authentication
#   HANDHELD_IP       IP address of the target muOS handheld
#
# When PRIVATE_KEY_PATH and HANDHELD_IP are provided, the package is deployed to the handheld via SSH
#
# Examples:
#   ./build.sh
#   ./build.sh ~/.ssh/id_ed25519 192.168.68.123
#   ./build.sh --clean ~/.ssh/id_ed25519 192.168.68.123
#   ./build.sh --clean --launch ~/.ssh/id_ed25519 192.168.68.123
#   ./build.sh --launch ~/.ssh/id_ed25519 192.168.68.123

echoHeader() {
    local text="$1"
    local CYAN="\033[36m"
    local RESET="\033[0m"
    echo -e "${CYAN}${text}${RESET}"
}

echoError() {
    local text="$1"
    local RED="\033[31m"
    local RESET="\033[0m"
    echo -e "${RED}Error: ${text}${RESET}" >&2
}

echoWarning() {
    local text="$1"
    local YELLOW="\033[33m"
    local RESET="\033[0m"
    echo -e "Warning: ${YELLOW}${text}${RESET}"
}

verifyConnection() {
    echoHeader "Verifying connection to $HANDHELD_IP"

    # Set up verbose output capture for SSH connection attempt
    SSH_OUTPUT=$(ssh -i "${PRIVATE_KEY_PATH}" -o ConnectTimeout=5 -o BatchMode=yes root@"${HANDHELD_IP}" exit 2>&1)
    SSH_STATUS=$?

    if [ $SSH_STATUS -ne 0 ]; then
        echo "${SSH_OUTPUT}"
        echoError "Could not connect to ${HANDHELD_IP}."
        if [[ "$SSH_OUTPUT" == *"Host key verification failed"* ]]; then
            echo "Your handheld's IP address may have changed, try:"
            echo "  ssh-keygen -R ${HANDHELD_IP}"
            echo "  ssh -o StrictHostKeyChecking=accept-new root@${HANDHELD_IP} exit"
            echo "Consider setting up reserved IPs in your router to prevent changes."
        elif [[ "$SSH_OUTPUT" == *"Permission denied"* ]]; then
            echo "Your SSH key may not be authorized on the device. Try:"
            echo "  ssh-copy-id -i ${PRIVATE_KEY_PATH}.pub root@${HANDHELD_IP}"
        elif [[ "$SSH_OUTPUT" == *"Connection refused"* ]]; then
            echo "Your handheld may not be connected to the network, or SSH may not be enabled."
            echo "If SSH is disabled, you can enable it in muOS settings (Configuration > Connectivity > Web Services)."
            echo "If you just powered on your handheld, it may need some time to connect to the network."
        elif [[ "$SSH_OUTPUT" == *"Connection timed out"* ]]; then
            echo "Check that your handheld is powered on and connected to your network."
        fi
        exit 1
    fi

    echo "Connection successful"
}

# Process command line arguments
CLEAN=false
LAUNCH=false

while [[ "$1" == --* ]]; do
    case "$1" in
    --clean)
        CLEAN=true
        shift
        ;;
    --launch)
        LAUNCH=true
        shift
        ;;
    *)
        echoError "Unknown option: $1"
        exit 1
        ;;
    esac
done

PRIVATE_KEY_PATH=$1
HANDHELD_IP=$2

# Verify connection if credentials are provided
# Assume the connection remains stable for the duration of the script
if [ -n "$PRIVATE_KEY_PATH" ] && [ -n "$HANDHELD_IP" ]; then
    verifyConnection
fi

# Local directories
DIST_DIR=".dist"
BUILD_DIR=".build"

# Target directories
APP_DIR="mnt/mmc/MUOS/application/Aesthetic"
APP_SOURCE_DIR="mnt/mmc/MUOS/application/Aesthetic/.aesthetic"
APP_GLYPH_SOURCE="assets/icons/glyph/muxapp/aesthetic.png"
APP_GLYPH_TARGET="opt/muos/default/MUOS/theme/active/glyph/muxapp"
APP_GLYPH_DIR="opt/muos/default/MUOS/theme/active/glyph/muxapp"
UPDATE_SCRIPT_DIR="opt"

ARCHIVE_BASE_NAME=Aesthetic

# This would be a .muxzip if there were no update script needed, see: https://muos.dev/help/archive
ARCHIVE_TYPE="muxupd"

echoHeader "Setting up clean build environment"
rm -rf "${DIST_DIR}" "${BUILD_DIR}"
mkdir -p "${DIST_DIR}" || {
    echoError "Failed to create distribution directory"
    exit 1
}
mkdir -p "${BUILD_DIR}/${APP_DIR}/.aesthetic" || {
    echoError "Failed to create app directory structure"
    exit 1
}
mkdir -p "${BUILD_DIR}/${APP_GLYPH_DIR}" || {
    echoError "Failed to create glyph directory"
    exit 1
}
mkdir -p "${BUILD_DIR}/${UPDATE_SCRIPT_DIR}" || {
    echoError "Failed to create update script directory"
    exit 1
}

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
    "/mnt/mmc/MUOS/update/installed/Aesthetic_*.muxupd.done"
    "/opt/muos/default/MUOS/theme/active/glyph/muxapp/aesthetic.png"
)

# Remove previous installation files if requested
if [ "$CLEAN" = true ]; then
    if [ -z "$PRIVATE_KEY_PATH" ] || [ -z "$HANDHELD_IP" ]; then
        echoError "--clean requires both PRIVATE_KEY_PATH and HANDHELD_IP"
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

# Generate PNG glyphs from SVGs before building
echoHeader "Generating glyph PNGs"
bash utils/generate_glyph_pngs_if_needed.sh || {
    echo "Failed to generate glyph PNGs"
    exit 1
}

# Copy application files to build directory
echoHeader "Copying files to build directory"
rsync -aq mux_launch.sh "${BUILD_DIR}/${APP_DIR}" || {
    echoError "Failed to copy mux_launch.sh"
    exit 1
}
rsync -aq src/ "${BUILD_DIR}/${APP_SOURCE_DIR}" || {
    echoError "Failed to copy src/"
    exit 1
}
rsync -aq bin/ "${BUILD_DIR}/${APP_SOURCE_DIR}/bin" || {
    echoError "Failed to copy bin/"
    exit 1
}
rsync -aq lib/ "${BUILD_DIR}/${APP_SOURCE_DIR}/lib" || {
    echoError "Failed to copy lib/"
    exit 1
}

# Copy glyph mapping files
mkdir -p "${BUILD_DIR}/${APP_SOURCE_DIR}/utils" || {
    echoError "Failed to create utils directory"
    exit 1
}
rsync -aq utils/glyph_mapping.txt "${BUILD_DIR}/${APP_SOURCE_DIR}/utils/glyph_mapping.txt" || {
    echoError "Failed to copy glyph mapping file"
    exit 1
}

# assets/fonts (.bin and .ttf files)
mkdir -p "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/fonts"
rsync -aq --include="*.ttf" --include="*.bin" --include="*/" --exclude="*" assets/fonts/ "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/fonts/" || {
    echoError "Failed to copy font files"
    exit 1
}

# assets/icons/material_symbols
mkdir -p "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/icons/material_symbols"
rsync -aq assets/icons/material_symbols/ "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/icons/material_symbols/" || {
    echoError "Failed to copy material symbols"
    exit 1
}

# assets/icons/lucide/ui
mkdir -p "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/icons/lucide/ui"
rsync -aq assets/icons/lucide/ui/ "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/icons/lucide/ui/" || {
    echoError "Failed to copy lucide UI icons"
    exit 1
}

# assets/icons/muos
mkdir -p "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/icons/muos"
rsync -aq assets/icons/muos/ "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/icons/muos/" || {
    echoError "Failed to copy muos icons"
    exit 1
}

# assets/images (includes presets subdirectory)
mkdir -p "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/images"
rsync -aq assets/images/ "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/images/" || {
    echoError "Failed to copy images"
    exit 1
}

# assets/sounds
mkdir -p "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/sounds"
rsync -aq assets/sounds/ "${BUILD_DIR}/${APP_SOURCE_DIR}/assets/sounds/" || {
    echoError "Failed to copy sounds"
    exit 1
}

# Remove macOS extended attributes that can interfere with find command
xattr -rc "${BUILD_DIR}/${APP_SOURCE_DIR}/assets" 2>/dev/null || true

# Generate manifest of all files that should exist in the source directory
echoHeader "Generating file manifest"
MANIFEST_FILE="${BUILD_DIR}/${APP_SOURCE_DIR}/.manifest"
(cd "${BUILD_DIR}/${APP_SOURCE_DIR}" && {
    # List all non-asset files
    find . -type f -not -path "./assets/*" -print
    # Manually list asset files using ls and find in subdirectories
    if [ -d "assets" ]; then
        for subdir in assets/*/; do
            if [ -d "$subdir" ]; then
                find "$subdir" -type f -print 2>/dev/null || true
            fi
        done
    fi
} | sort >".manifest") || {
    echoError "Failed to generate manifest"
    exit 1
}
echo "Generated manifest with $(wc -l <"$MANIFEST_FILE" | xargs) files"

# Application glyph
rsync -aq "${APP_GLYPH_SOURCE}" "${BUILD_DIR}/${APP_GLYPH_TARGET}" || {
    echoError "Failed to copy application glyph"
    exit 1
}

# Update script
rsync -aq update.sh "${BUILD_DIR}/${UPDATE_SCRIPT_DIR}/update.sh" || {
    echoError "Failed to copy update script"
    exit 1
}

echoHeader "Creating archive"
# Exclude macOS system files when archiving
(cd "${BUILD_DIR}" && zip -9qr "../${DIST_DIR}/${ARCHIVE_BASE_NAME}_${VERSION}.${ARCHIVE_TYPE}" * -x "*.DS_Store" -x "._*") || {
    echoError "Failed to create archive"
    exit 1
}
echo "Created ${ARCHIVE_BASE_NAME}_${VERSION}.${ARCHIVE_TYPE}"

echoHeader "Removing build directory"
rm -rf "${BUILD_DIR}" || { echoWarning "Failed to remove build directory, continuing anyway"; }

if [ -z "$PRIVATE_KEY_PATH" ] || [ -z "$HANDHELD_IP" ]; then
    echo "Skipping upload. To enable automatic upload, provide PRIVATE_KEY_PATH and HANDHELD_IP arguments."
    echo "Done!"
    exit 0
fi

echoHeader "Uploading to $HANDHELD_IP"
scp -i "${PRIVATE_KEY_PATH}" "${DIST_DIR}/${ARCHIVE_BASE_NAME}_${VERSION}.${ARCHIVE_TYPE}" root@"${HANDHELD_IP}":/mnt/mmc/ARCHIVE || {
    echoError "Failed to upload archive"
    exit 1
}

echoHeader "Extracting on $HANDHELD_IP"
ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "bash /opt/muos/script/mux/extract.sh /mnt/mmc/ARCHIVE/${ARCHIVE_BASE_NAME}_${VERSION}.${ARCHIVE_TYPE}" || {
    echoError "Failed to extract archive"
    exit 1
}

if [ "$LAUNCH" = true ]; then
    echoHeader "Launching application on $HANDHELD_IP"
    # Check for version files and run the appropriate launch command
    if ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "[ -f /opt/muos/config/version.txt ]"; then
        echo "Launching for Pixie"
        ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "
            . /opt/muos/script/var/func.sh
            killall -9 \$(GET_VAR 'system' 'foreground_process')
            /mnt/mmc/MUOS/application/Aesthetic/mux_launch.sh
            echo '0' > /tmp/safe_quit
        "
    elif ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "[ -f /opt/muos/config/system/version ]"; then
        echo "Launching for Goose"
        ssh -i "${PRIVATE_KEY_PATH}" root@"${HANDHELD_IP}" "
            . /opt/muos/script/var/func.sh
            FRONTEND stop
            /mnt/mmc/MUOS/application/Aesthetic/mux_launch.sh
            FRONTEND start
        "
    else
        echoError "Could not find a supported muOS version file on the device. Launch aborted."
    fi
fi
