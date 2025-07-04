#!/bin/bash
# Development launch script for Aesthetic
# Use this script to run Aesthetic locally for development

set -e # Exit on error

# Default window dimensions
WIDTH=640
HEIGHT=480
INIT_SCREEN="splash"

# Parse command line arguments
if [ $# -eq 2 ]; then
  # Two arguments: width and height
  WIDTH=$1
  HEIGHT=$2
elif [ $# -eq 3 ]; then
  # Three arguments: width, height, and initial screen
  WIDTH=$1
  HEIGHT=$2
  INIT_SCREEN=$3
fi

# Detect OS
OS="$(uname -s)"
case "$OS" in
Darwin*)
  LOVE_PATH="/Applications/love.app/Contents/MacOS/love"
  ;;
Linux*)
  # Check for possible Linux love executable locations
  if command -v love &>/dev/null; then
    LOVE_PATH="love"
  elif [ -x "/usr/bin/love" ]; then
    LOVE_PATH="/usr/bin/love"
  elif [ -x "/usr/local/bin/love" ]; then
    LOVE_PATH="/usr/local/bin/love"
  else
    echo "Error: LÖVE executable not found. Please install LÖVE (https://love2d.org)"
    exit 1
  fi
  ;;
*)
  echo "Error: Unsupported operating system: $OS"
  echo "This script currently supports macOS and Linux only."
  exit 1
  ;;
esac

# Define project directories
SOURCE_DIR="$(pwd)"
ROOT_DIR="$SOURCE_DIR/.dev"
LOG_DIR="$ROOT_DIR/logs"
TEMPLATE_DIR="$SOURCE_DIR/src/scheme_templates"
THEME_PRESETS_DIR="$SOURCE_DIR/src/presets"
SCHEME_TEMPLATE_DIR="$SOURCE_DIR/src/scheme_templates"

# Make sure the development directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$ROOT_DIR/theme_working"

# Generate a unique session ID based on timestamp
SESSION_LOG_FILE="$LOG_DIR/$(date +%Y%m%d_%H%M%S).log"

# Create local development directories that emulate handheld paths
LOCAL_MUOS_STORAGE_DIR="$ROOT_DIR/run/muos/storage"
LOCAL_MUOS_DEVICE_DIR="$ROOT_DIR/opt/muos/device"
LOCAL_MUOS_CONFIG_DIR="$ROOT_DIR/opt/muos/config"

# Create directories for RGB config and other needed paths
mkdir -p "$LOCAL_MUOS_STORAGE_DIR/theme/active/rgb"
mkdir -p "$LOCAL_MUOS_DEVICE_DIR/current/script"
mkdir -p "$LOCAL_MUOS_CONFIG_DIR"

# Create and make executable the LED control script for development
touch "$LOCAL_MUOS_DEVICE_DIR/current/script/led_control.sh"
chmod +x "$LOCAL_MUOS_DEVICE_DIR/current/script/led_control.sh"

# Create version.txt file for development
echo "2502.0_GOOSE" >"$LOCAL_MUOS_CONFIG_DIR/version.txt"

# Export environment variables
export SOURCE_DIR
export ROOT_DIR
export SESSION_LOG_FILE
export TEMPLATE_DIR
export MUOS_DEVICE_SCRIPT_DIR_GOOSE="$LOCAL_MUOS_DEVICE_DIR/script"
export WIDTH
export HEIGHT
export DEV=true
export INIT_SCREEN
export THEME_PRESETS_DIR
export SCHEME_TEMPLATE_DIR

# Set LD_LIBRARY_PATH based on OS
if [ "$OS" = "Darwin" ]; then
  export DYLD_LIBRARY_PATH="$SOURCE_DIR/lib:$SOURCE_DIR/src/tove:$DYLD_LIBRARY_PATH"
else
  export LD_LIBRARY_PATH="$SOURCE_DIR/lib:$SOURCE_DIR/src/tove:$LD_LIBRARY_PATH"
fi

# Create symlink to assets directory in src if it doesn't exist
if [ ! -L "$SOURCE_DIR/src/assets" ]; then
  echo "Creating symlink to assets directory in src"
  ln -s "$SOURCE_DIR/assets" "$SOURCE_DIR/src/assets"
fi

# Set up symlink for scheme_templates
if [ ! -L "$ROOT_DIR/scheme_templates" ]; then
  ln -s "$SOURCE_DIR/src/scheme_templates" "$ROOT_DIR/scheme_templates"
fi

# Print environment info for debugging
echo "Starting Aesthetic in development mode..."
echo "DETECTED OS: $OS"
echo "USING LÖVE PATH: $LOVE_PATH"
echo "SOURCE_DIR: $SOURCE_DIR"
echo "ROOT_DIR: $ROOT_DIR"
echo "LOG_DIR: $LOG_DIR"
echo "SESSION_LOG_FILE: $SESSION_LOG_FILE"
echo "MUOS_DEVICE_SCRIPT_DIR: $MUOS_DEVICE_SCRIPT_DIR"
echo "WINDOW DIMENSIONS: ${WIDTH}x${HEIGHT}"

# Extract and print keyboard to action mappings from input_config.lua
echo ""
echo "KEYBOARD TO HANDHELD ACTION MAPPING:"
grep 'keyboard = {' "$SOURCE_DIR/src/ui/controllers/input_config.lua" |
  sed -E 's/([a-zA-Z_]+) = \{ keyboard = \{ ([^}]*) \}.*$/  \1 = \2/' |
  sed -E 's/","/, /g; s/"//g; s/, *$//'
echo ""

# Launch application with LÖVE and pass screen dimensions
cd "$SOURCE_DIR" || exit
# Launch with explicit width and height arguments
"$LOVE_PATH" src --width $WIDTH --height $HEIGHT 2>&1 | tee -a "$SESSION_LOG_FILE"
# "$LOVE_PATH" src 2>&1 | tee -a "$SESSION_LOG_FILE"
