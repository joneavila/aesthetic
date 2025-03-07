#!/bin/bash
# HELP: Aesthetic is an on-device theme creator.
# ICON: aesthetic

# Source muOS system functions
. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

# Define paths and commands
ROOT_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.aesthetic"
TEMPLATE_SOURCE="$ROOT_DIR/Aesthetic/template"
THEME_DIR="/run/muos/storage/theme"

# Create required directories
mkdir -p "$THEME_DIR"
mkdir -p "$THEME_DIR/active"

# Export environment variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export THEME_DIR="$THEME_DIR"
export TEMPLATE_DIR="$ROOT_DIR/template"
export LD_LIBRARY_PATH="$ROOT_DIR/lib:${LD_LIBRARY_PATH:-}"

# Create theme template folder and copy templates from source
mkdir -p "$ROOT_DIR/template"
cp -r "$TEMPLATE_SOURCE/"* "$ROOT_DIR/template/"

# Launcher
cd "$ROOT_DIR" || exit
SET_VAR "system" "foreground_process" "love"
./bin/love Aesthetic
