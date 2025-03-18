#!/bin/bash
# Usage: ./build.sh [<PRIVATE_KEY_PATH>] [<DEVICE_IP>]
# If PRIVATE_KEY_PATH and DEVICE_IP are provided, the archive will be uploaded to the device with `scp`

PRIVATE_KEY_PATH=$1
DEVICE_IP=$2

APPLICATION_DIR=mnt/mmc/MUOS/application/Aesthetic
GLYPH_DIR=opt/muos/default/MUOS/theme/active/glyph/muxapp
ZIP_BASE_NAME=Aesthetic

# Get version from version.lua
MAJOR=$(awk '/version.major =/ {print $3}' src/version.lua)
MINOR=$(awk '/version.minor =/ {print $3}' src/version.lua)
PATCH=$(awk '/version.patch =/ {print $3}' src/version.lua)
VERSION="v${MAJOR}.${MINOR}.${PATCH}"

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