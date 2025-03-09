#!/bin/bash

# Delete existing ZIP file if it exists
if [ -f Aesthetic.zip ]; then
    rm Aesthetic.zip
fi

# Create temporary build directory with required folder structure
mkdir -p build/mnt/mmc/MUOS/application/.aesthetic/{Aesthetic,lib,bin,conf/love/Aesthetic,Aesthetic/template/scheme}
# Create folder structure for the application icon
mkdir -p build/opt/muos/default/MUOS/theme/active/glyph/muxapp/

# Copy source files to their locations on-device
cp -r Aesthetic/* build/mnt/mmc/MUOS/application/.aesthetic/Aesthetic/
cp -r lib/* build/mnt/mmc/MUOS/application/.aesthetic/lib/
cp -r bin/* build/mnt/mmc/MUOS/application/.aesthetic/bin/

# Copy the application icon to the theme glyph folder
cp Aesthetic/template/glyph/muxapp/aesthetic.png build/opt/muos/default/MUOS/theme/active/glyph/muxapp/

# Copy shared libraries
cp /usr/lib/liblove-11.5.so build/mnt/mmc/MUOS/application/.aesthetic/lib/ 2>/dev/null || \
cp /usr/local/lib/liblove-11.5.so build/mnt/mmc/MUOS/application/.aesthetic/lib/ 2>/dev/null || \

# Copy shell script
cp Aesthetic.sh build/mnt/mmc/MUOS/application/

# Create the ZIP file with maximum compression, excluding .DS_Store files
cd build
zip -9r ../Aesthetic.zip ./* -x "*.DS_Store"

# Clean up
cd ..
rm -rf build

# Get the full path of Aesthetic.zip
FULL_PATH="$(pwd)/Aesthetic.zip"

echo "Build complete! Archive created at $FULL_PATH"