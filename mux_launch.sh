#!/bin/bash
# HELP: Aesthetic is an on-device theme creator.
# ICON: aesthetic

# Source muOS system functions
. /opt/muos/script/var/func.sh

# SCREEN_WIDTH=$(GET_VAR device mux/width)
# SCREEN_HEIGHT=$(GET_VAR device mux/height)
# SCREEN_RESOLUTION="${SCREEN_WIDTH}x${SCREEN_HEIGHT}"

# echo app >/tmp/act_go

# Define paths
ROOT_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Aesthetic/.aesthetic"
THEME_DIR="/run/muos/storage/theme"
BINDIR="$ROOT_DIR/bin"
LOG_DIR="$ROOT_DIR/logs"

# Create required directories
mkdir -p "$THEME_DIR/active"
mkdir -p "$LOG_DIR"
chmod 777 "$LOG_DIR"

# Debug: Check directory creation and permissions
echo "Debug: Checking directories and permissions" > "$LOG_DIR/launch_debug.log"
echo "ROOT_DIR: $ROOT_DIR" >> "$LOG_DIR/launch_debug.log"
ls -la "$ROOT_DIR" >> "$LOG_DIR/launch_debug.log" 2>&1
echo "Logs directory:" >> "$LOG_DIR/launch_debug.log"
ls -la "$LOG_DIR" >> "$LOG_DIR/launch_debug.log" 2>&1
echo "Tove library:" >> "$LOG_DIR/launch_debug.log"
ls -la "$ROOT_DIR/tove" >> "$LOG_DIR/launch_debug.log" 2>&1

# Export environment variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export THEME_DIR
export LOG_DIR
export LD_LIBRARY_PATH="$ROOT_DIR/lib:$ROOT_DIR/tove:$LD_LIBRARY_PATH"

# Debug: Print environment
echo "Environment:" >> "$LOG_DIR/launch_debug.log"
env >> "$LOG_DIR/launch_debug.log"

# Launch application
cd "$ROOT_DIR" || exit
SET_VAR "system" "foreground_process" "love"

# Redirect both stdout and stderr to log files
./bin/love . > "$LOG_DIR/app.log" 2> "$LOG_DIR/error.log"

# Debug: Check if logs were created
echo "After LÖVE execution:" >> "$LOG_DIR/launch_debug.log"
ls -la "$LOG_DIR" >> "$LOG_DIR/launch_debug.log" 2>&1
