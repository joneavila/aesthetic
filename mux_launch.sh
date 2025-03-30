#!/bin/bash
# HELP: Aesthetic is an on-device theme creator.
# ICON: aesthetic

# Source muOS system functions
. /opt/muos/script/var/func.sh

# Define paths
ROOT_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Aesthetic/.aesthetic"
THEME_DIR="/run/muos/storage/theme"
BINDIR="$ROOT_DIR/bin"
LOG_DIR="$ROOT_DIR/logs"

# Create required directories
mkdir -p "$THEME_DIR/active"
mkdir -p "$LOG_DIR"

# Export environment variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export THEME_DIR
export LOG_DIR
export LD_LIBRARY_PATH="$ROOT_DIR/lib:$ROOT_DIR/tove:$LD_LIBRARY_PATH"
export TEMPLATE_DIR="$ROOT_DIR/template"

# Launch application
cd "$ROOT_DIR" || exit
SET_VAR "system" "foreground_process" "love"

# Redirect both stdout and stderr to log files
./bin/love . > "$LOG_DIR/app.log" 2> "$LOG_DIR/error.log"
