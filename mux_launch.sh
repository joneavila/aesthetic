#!/bin/bash
# HELP: Aesthetic is an on-device theme creator.
# ICON: aesthetic

# Source muOS system functions
. /opt/muos/script/var/func.sh

# Define paths
ROOT_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Aesthetic"
THEME_DIR="/run/muos/storage/theme"

# Create required directories
mkdir -p "$THEME_DIR/active"

# Export environment variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export THEME_DIR
export LD_LIBRARY_PATH="$ROOT_DIR/lib:${LD_LIBRARY_PATH:-}"

# Launch application
cd "$ROOT_DIR" || exit
SET_VAR "system" "foreground_process" "love"
./love .
