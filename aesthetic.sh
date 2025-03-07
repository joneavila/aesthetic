#!/bin/bash
# HELP: Aesthetic is an on-device theme creator.
# ICON: aesthetic

# Source muOS system functions
. /opt/muos/script/var/func.sh

# Define paths
ROOT_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.aesthetic"
TEMPLATE_DIR="$ROOT_DIR/template"
TEMPLATE_SOURCE_DIR="$ROOT_DIR/Aesthetic/template"
THEME_DIR="/run/muos/storage/theme"

# Create required directories
mkdir -p "$THEME_DIR"
mkdir -p "$THEME_DIR/active"

# Export environment variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export THEME_DIR="$THEME_DIR"
export TEMPLATE_DIR="$TEMPLATE_DIR"
export LD_LIBRARY_PATH="$ROOT_DIR/lib:${LD_LIBRARY_PATH:-}"

# Create theme template directory and copy source files
mkdir -p "$TEMPLATE_DIR"
cp -r "$TEMPLATE_SOURCE_DIR/"* "$TEMPLATE_DIR/"

# Launch application
cd "$ROOT_DIR" || exit
SET_VAR "system" "foreground_process" "love"
./bin/love Aesthetic
