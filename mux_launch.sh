#!/bin/bash
# HELP: Aesthetic is an on-device theme creator.
# ICON: aesthetic
# GRID: Aesthetic

# Source muOS system functions
. /opt/muos/script/var/func.sh # For `GET_VAR`, `SET_VAR`

echo "app" >/tmp/act_go

# Define paths
ROOT_DIR="/mnt/mmc/MUOS/application/Aesthetic"
SOURCE_DIR="$ROOT_DIR/.aesthetic"
USERDATA_DIR="$ROOT_DIR/userdata"

LOG_DIR="$SOURCE_DIR/logs"
SESSION_LOG_FILE="$LOG_DIR/$(date +%Y%m%d_%H%M%S).log"

LIB_DIR="$SOURCE_DIR/lib"
TOVE_DIR="$SOURCE_DIR/tove"

# Make sure the directory exists
mkdir -p "$LOG_DIR"
mkdir -p "$USERDATA_DIR"

export WIDTH=$(GET_VAR device mux/width)
export HEIGHT=$(GET_VAR device mux/height)
export ROOT_DIR
export SOURCE_DIR
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export SESSION_LOG_FILE
export LD_LIBRARY_PATH="$LIB_DIR:$TOVE_DIR:$LD_LIBRARY_PATH"

# Launch application
cd "$SOURCE_DIR" || exit
SET_VAR "system" "foreground_process" "love"
./bin/love .

unset WIDTH
unset HEIGHT
unset ROOT_DIR
unset SOURCE_DIR
unset SDL_GAMECONTROLLERCONFIG_FILE
unset SESSION_LOG_FILE
unset LD_LIBRARY_PATH
