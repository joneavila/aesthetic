#!/bin/bash
# HELP: Aesthetic is an on-device theme creator.
# ICON: aesthetic
# GRID: Aesthetic

# Source muOS system functions
. /opt/muos/script/var/func.sh # For `GET_VAR`, `SET_VAR`
. -n /opt/muos/script/package/theme.sh # For `theme.sh` `install` function

# Define paths
# `$(GET_VAR "device" "storage/rom/mount")` will resolve to either `/mnt/mmc` (SD1) or `/mnt/sdcard` (SD2)
ROOT_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Aesthetic/.aesthetic"
LOG_DIR="$ROOT_DIR/logs"

# Make sure the directory exists
mkdir -p "$LOG_DIR"

# Generate a unique session ID based on timestamp
SESSION_ID=$(date +%Y%m%d_%H%M%S)
SESSION_LOG_FILE="$LOG_DIR/$SESSION_ID.log"

# Export environment variables
export ROOT_DIR
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export LOG_DIR
export SESSION_ID
export SESSION_LOG_FILE
export LD_LIBRARY_PATH="$ROOT_DIR/lib:$ROOT_DIR/tove:$LD_LIBRARY_PATH" # Add libraries to the library path
export TEMPLATE_DIR="$ROOT_DIR/template"

# Launch application
cd "$ROOT_DIR" || exit
SET_VAR "system" "foreground_process" "love"
./bin/love .
