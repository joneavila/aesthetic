#!/bin/bash
# HELP: Aesthetic is an on-device theme creator.
# ICON: aesthetic
# GRID: Aesthetic

# Source muOS system functions
. /opt/muos/script/var/func.sh # For `GET_VAR`, `SET_VAR`

echo "app" >/tmp/act_go

# Define paths
# `$(GET_VAR "device" "storage/rom/mount")` will resolve to either `/mnt/mmc` (SD1) or `/mnt/sdcard` (SD2)
ROOT_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Aesthetic"
SOURCE_DIR="$ROOT_DIR/.aesthetic"
LOG_DIR="$SOURCE_DIR/logs"

# Make sure the directory exists
mkdir -p "$LOG_DIR"
mkdir -p "$ROOT_DIR/userdata"

# Generate a unique session ID based on timestamp
SESSION_LOG_FILE="$LOG_DIR/$(date +%Y%m%d_%H%M%S).log"

WIDTH=$(GET_VAR device mux/width)
HEIGHT=$(GET_VAR device mux/height)

# Export environment variables
export ROOT_DIR
export SOURCE_DIR
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export SESSION_LOG_FILE
export LD_LIBRARY_PATH="$SOURCE_DIR/lib:$SOURCE_DIR/tove:$LD_LIBRARY_PATH" # Add libraries to the library path
export WIDTH
export HEIGHT

# Launch application
cd "$SOURCE_DIR" || exit
SET_VAR "system" "foreground_process" "love"
./bin/love .

# TODO: `unset` environment variables
