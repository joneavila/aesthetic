#!/bin/bash
# Development launch script for Aesthetic
# Use this script to run Aesthetic locally for development

set -e  # Exit on error

# Default window dimensions
WIDTH=640
HEIGHT=480

# Parse command line arguments
if [ $# -eq 2 ]; then
  # Two arguments: width and height
  WIDTH=$1
  HEIGHT=$2
elif [ $# -eq 1 ]; then
  # One argument in format WIDTHxHEIGHT
  if [[ $1 =~ ^([0-9]+)x([0-9]+)$ ]]; then
    WIDTH=${BASH_REMATCH[1]}
    HEIGHT=${BASH_REMATCH[2]}
  else
    echo "Invalid format. Expected WIDTHxHEIGHT (e.g. 800x600)"
    exit 1
  fi
fi

# Detect OS
OS="$(uname -s)"
case "$OS" in
  Darwin*)  
    LOVE_PATH="/Applications/love.app/Contents/MacOS/love"
    ;;
  Linux*)   
    # Check for possible Linux love executable locations
    if command -v love &> /dev/null; then
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
ROOT_DIR="$(pwd)"
DEV_DIR="$ROOT_DIR/.dev"
LOG_DIR="$DEV_DIR/logs"
TEMPLATE_DIR="$ROOT_DIR/src/template"

# Make sure the development directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$DEV_DIR/theme_working"

# Generate a unique session ID based on timestamp
SESSION_ID=$(date +%Y%m%d_%H%M%S)
SESSION_LOG_FILE="$LOG_DIR/$SESSION_ID.log"

# Create local development directories that emulate handheld paths
LOCAL_MUOS_STORAGE_DIR="$DEV_DIR/run/muos/storage"
LOCAL_MUOS_DEVICE_DIR="$DEV_DIR/opt/muos/device"
LOCAL_MUOS_CONFIG_DIR="$DEV_DIR/opt/muos/config"

MUOS_VERSION="2502.0"

# Create directories for RGB config and other needed paths
mkdir -p "$LOCAL_MUOS_STORAGE_DIR/theme/active/rgb"
mkdir -p "$LOCAL_MUOS_DEVICE_DIR/current/script"
mkdir -p "$LOCAL_MUOS_CONFIG_DIR"

# Create and make executable the LED control script for development
touch "$LOCAL_MUOS_DEVICE_DIR/current/script/led_control.sh"
chmod +x "$LOCAL_MUOS_DEVICE_DIR/current/script/led_control.sh"

# Create version.txt file for development
echo "1.0.0-dev" > "$LOCAL_MUOS_CONFIG_DIR/version.txt"

# Export environment variables
export ROOT_DIR
export DEV_DIR
export LOG_DIR
export SESSION_ID
export SESSION_LOG_FILE
export TEMPLATE_DIR
export MUOS_STORAGE_THEME_DIR="$LOCAL_MUOS_STORAGE_DIR/theme"
export MUOS_DEVICE_SCRIPT_DIR="$LOCAL_MUOS_DEVICE_DIR/current/script"
export WIDTH
export HEIGHT
export MUOS_VERSION

# Set LD_LIBRARY_PATH based on OS
if [ "$OS" = "Darwin" ]; then
  export DYLD_LIBRARY_PATH="$ROOT_DIR/lib:$ROOT_DIR/src/tove:$DYLD_LIBRARY_PATH"
else
  export LD_LIBRARY_PATH="$ROOT_DIR/lib:$ROOT_DIR/src/tove:$LD_LIBRARY_PATH"
fi

# Create symlink to assets directory in src if it doesn't exist
if [ ! -L "$ROOT_DIR/src/assets" ]; then
  echo "Creating symlink to assets directory in src"
  ln -s "$ROOT_DIR/assets" "$ROOT_DIR/src/assets"
fi

# Print environment info for debugging
echo "Starting Aesthetic in development mode..."
echo "DETECTED OS: $OS"
echo "USING LÖVE PATH: $LOVE_PATH"
echo "ROOT_DIR: $ROOT_DIR"
echo "DEV_DIR: $DEV_DIR"
echo "LOG_DIR: $LOG_DIR"
echo "SESSION_LOG_FILE: $SESSION_LOG_FILE"
echo "MUOS_STORAGE_THEME_DIR: $MUOS_STORAGE_THEME_DIR"
echo "MUOS_DEVICE_SCRIPT_DIR: $MUOS_DEVICE_SCRIPT_DIR"
echo "WINDOW DIMENSIONS: ${WIDTH}x${HEIGHT}"

# Extract and print keyboard to button mappings from input.lua
echo ""
echo "KEYBOARD TO HANDHELD BUTTON MAPPING:"
grep -E '\["[^"]+"\] = "[^"]+",' "$ROOT_DIR/src/input.lua" | sed 's/\s*\["\([^"]*\)"\] = "\([^"]*\)",/  \1 = \2/'
echo ""

# Launch application with LÖVE and pass screen dimensions
cd "$ROOT_DIR" || exit
# Launch with explicit width and height arguments
"$LOVE_PATH" src --width $WIDTH --height $HEIGHT 2>&1 | tee -a "$SESSION_LOG_FILE" 
# "$LOVE_PATH" src 2>&1 | tee -a "$SESSION_LOG_FILE" 