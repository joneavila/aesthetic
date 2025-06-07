# This is a modified version of /opt/muos/script/package/theme.sh (Goose) with only the code needed to install a theme.
# Notably, it doesn't stop the frontend, or start the frontend.

#!/bin/sh

. /opt/muos/script/var/func.sh

THEME_DIR="/run/muos/storage/theme"
THEME_ACTIVE_DIR="$THEME_DIR/active"
BOOTLOGO_MOUNT="$(GET_VAR "device" "storage/boot/mount")"

THEME_ARG="$1"
THEME="$THEME_DIR/$THEME_ARG.muxthm"

cp "/opt/muos/device/bootlogo.bmp" "$BOOTLOGO_MOUNT/bootlogo.bmp"

while [ -d "$THEME_ACTIVE_DIR" ]; do
        rm -rf "$THEME_ACTIVE_DIR"
        sync
        /opt/muos/bin/toybox sleep 1
done

unzip "$THEME" -d "$THEME_ACTIVE_DIR"

THEME_NAME=$(basename "$THEME" .muxthm)
echo "${THEME_NAME%-[0-9]*_[0-9]*}" >"$THEME_ACTIVE_DIR/name.txt"

BOOTLOGO_NEW="$THEME_ACTIVE_DIR/$(GET_VAR "device" "mux/width")x$(GET_VAR "device" "mux/height")/image/bootlogo.bmp"
[ -f "$BOOTLOGO_NEW" ] || BOOTLOGO_NEW="$THEME_ACTIVE_DIR/image/bootlogo.bmp"

if [ "$(GET_VAR "device" "led/rgb")" -eq 1 ]; then
        RGBCONF_SCRIPT="$THEME_ACTIVE_DIR/rgb/rgbconf.sh"
        if [ -f "$RGBCONF_SCRIPT" ]; then
                "$RGBCONF_SCRIPT"
        else
                /opt/muos/device/script/led_control.sh 1 0 0 0 0 0 0 0
        fi
fi

if [ -f "$BOOTLOGO_NEW" ]; then
        cp "$BOOTLOGO_NEW" "$BOOTLOGO_MOUNT/bootlogo.bmp"
        case "$(GET_VAR "device" "board/name")" in
                rg28xx-h) convert "$BOOTLOGO_MOUNT/bootlogo.bmp" -rotate 270 "$BOOTLOGO_MOUNT/bootlogo.bmp" ;;
        esac
fi

ASSETS_ZIP="$THEME_ACTIVE_DIR/assets.muxzip"
if [ -f "$ASSETS_ZIP" ]; then
        printf "Extracting theme assets\n"
        /opt/muos/script/mux/extract.sh "$ASSETS_ZIP"
fi

printf "Install complete\n"
sync