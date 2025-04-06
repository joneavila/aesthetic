#!/bin/bash
# Usage: ./build.sh [--clean] [<PRIVATE_KEY_PATH>] [<DEVICE_IP>]
#
# If `PRIVATE_KEY_PATH` and `DEVICE_IP` are provided, the archive will be uploaded to the handheld using `scp`
# and automatically extracted.
# If `--clean` is provided, files from previous builds will be deleted from the handheld before the new archive is
# extracted.

echoHeader() {
    local text="$1"
    local PURPLE="\033[35m"
    local RESET="\033[0m"
    echo -e "${PURPLE}${text}...${RESET}"
}

# Check for --clean option
if [[ "$1" == "--clean" ]]; then
    CLEAN=true
    shift
else
    CLEAN=false
fi

PRIVATE_KEY_PATH=$1
DEVICE_IP=$2

APPLICATION_DIR="mnt/mmc/MUOS/application/Aesthetic"
LOGS_DIR="${APPLICATION_DIR}/.aesthetic/logs"
GLYPH_DIR="opt/muos/default/MUOS/theme/active/glyph/muxapp"

ARCHIVE_BASE_NAME=Aesthetic

mkdir -p .dist
mkdir -p .build/"${APPLICATION_DIR}"
mkdir -p .build/"${GLYPH_DIR}"
mkdir -p .build/"${LOGS_DIR}"

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
    "/mnt/mmc/MUOS/application/Aesthetic"
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
    
    echoHeader "Removing existing files"
    
    # Execute delete commands one by one to better handle wildcards
    for file in "${ITEMS_TO_DELETE[@]}"; do
        # Remove leading ./ if present
        remote_file="${file#./}"
        
        # Handle files with wildcards differently
        if [[ "$remote_file" == *"*"* ]]; then
            ssh -i "${PRIVATE_KEY_PATH}" root@"${DEVICE_IP}" "for f in ${remote_file}; do if [ -e \"\$f\" ]; then rm -rf \"\$f\" && echo \"\$f\"; fi; done"
        else
            ssh -i "${PRIVATE_KEY_PATH}" root@"${DEVICE_IP}" "if [ -e '${remote_file}' ]; then rm -rf '${remote_file}' && echo '${remote_file}'; fi"
        fi
    done
fi

echoHeader "Copying files to build directory"
rsync -aq mux_launch.sh .build/"${APPLICATION_DIR}" && echo "mux_launch.sh" || { echo "Failed to copy mux_launch.sh"; exit 1; }
rsync -aq src/ .build/"${APPLICATION_DIR}"/.aesthetic/ && echo "src/" || { echo "Failed to copy src/"; exit 1; }
rsync -aq bin/ .build/"${APPLICATION_DIR}"/.aesthetic/bin && echo "bin/" || { echo "Failed to copy bin/"; exit 1; }
rsync -aq lib/ .build/"${APPLICATION_DIR}"/.aesthetic/lib && echo "lib/" || { echo "Failed to copy lib/"; exit 1; }
rsync -aq src/tove/ .build/"${APPLICATION_DIR}"/.aesthetic/tove && echo "src/tove/" || { echo "Failed to copy src/tove/"; exit 1; }
rsync -aq src/template/glyph/muxapp/aesthetic.png .build/"${GLYPH_DIR}" && echo "aesthetic.png" || { echo "Failed to copy aesthetic.png"; exit 1; }

echoHeader "Creating archive"
# Create archive, exclude macOS system files
(cd .build && zip -9qr "../.dist/${ARCHIVE_BASE_NAME}_${VERSION}.muxupd" * -x "*.DS_Store" -x "._*") && echo "${ARCHIVE_BASE_NAME}_${VERSION}.muxupd" || { echo "Failed to create archive"; exit 1; }

echoHeader "Cleaning up"
# Delete temporary build directory
rm -rf .build && echo "Removed build directory" || echo "Failed to remove build directory"

echoHeader "Uploading to $DEVICE_IP"
if [ -z "$PRIVATE_KEY_PATH" ]; then
    echo "No PRIVATE_KEY_PATH provided"
    exit 0
elif [ -z "$DEVICE_IP" ]; then
    echo "No DEVICE_IP provided"
    exit 0
else
    scp -i "${PRIVATE_KEY_PATH}" .dist/"${ARCHIVE_BASE_NAME}_${VERSION}.muxupd" root@"${DEVICE_IP}":/mnt/mmc/ARCHIVE
    echoHeader "Extracting on $DEVICE_IP"
    ssh -i "${PRIVATE_KEY_PATH}" root@"${DEVICE_IP}" "bash /opt/muos/script/mux/extract.sh /mnt/mmc/ARCHIVE/${ARCHIVE_BASE_NAME}_${VERSION}.muxupd"
fi

# echoHeader "Running application"
# ssh -i "${PRIVATE_KEY_PATH}" root@"${DEVICE_IP}" "bash /mnt/mmc/MUOS/application/Aesthetic/mux_launch.sh"