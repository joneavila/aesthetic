#!/bin/bash
# HELP: Aesthetic is an on-device theme creator.
# ICON: aesthetic

# Source muOS system functions
. /opt/muos/script/var/func.sh
. -n /opt/muos/script/package/theme.sh

# Define paths
ROOT_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Aesthetic/.aesthetic"
BINDIR="$ROOT_DIR/bin"
LOG_DIR="$ROOT_DIR/logs"

# Create required directories
# Most directories are created by the application
mkdir -p "$LOG_DIR"

# Export environment variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export LOG_DIR
export LD_LIBRARY_PATH="$ROOT_DIR/lib:$ROOT_DIR/tove:$LD_LIBRARY_PATH"
export TEMPLATE_DIR="$ROOT_DIR/template"

# Launch application
cd "$ROOT_DIR" || exit
SET_VAR "system" "foreground_process" "love"

# Redirect stdout and stderr to log file
LOG_FILE="$LOG_DIR/$(date +%Y%m%d_%H%M%S).log"
./bin/love . > "$LOG_FILE" 2>&1
