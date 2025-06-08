--- Path constants
local system = require("utils.system")
local state = require("state")
local errorHandler = require("error_handler")

local paths = {}

-- muOS themes directories
paths.SOURCE_DIR = system.getEnvironmentVariable("SOURCE_DIR")
paths.ROOT_DIR = system.getEnvironmentVariable("ROOT_DIR")
paths.TEMPLATE_DIR = system.getEnvironmentVariable("TEMPLATE_DIR")

-- Working theme directory where files are written before archiving into a theme
paths.WORKING_THEME_DIR = paths.ROOT_DIR .. "/theme_working"

-- muOS themes directory and files
paths.THEME_DIR = system.getEnvironmentVariable("MUOS_STORAGE_THEME_DIR")
paths.THEME_VERSION = paths.THEME_DIR .. "/version.txt"

paths.THEME_ACTIVE_DIR = paths.THEME_DIR .. "/active"

-- `rgb` directory and files
paths.ACTIVE_RGB_DIR = paths.THEME_ACTIVE_DIR .. "/rgb"
paths.ACTIVE_RGB_CONF = paths.ACTIVE_RGB_DIR .. "/rgbconf.sh"
paths.ACTIVE_RGB_CONF_BACKUP = paths.ACTIVE_RGB_DIR .. "/rgbconf.sh.bak"

-- Generated theme path where the generated theme is written
-- Use a function to get the current theme name at time of use
function paths.getThemeOutputPath()
	return paths.THEME_DIR .. "/" .. state.themeName .. ".muxthm"
end

local DEVICE_SCRIPT_DIR_1 = "/opt/muos/device/current/script/led_control.sh" -- Pixie
local DEVICE_SCRIPT_DIR_2 = "/opt/muos/device/script/led_control.sh" -- Goose
paths.LED_CONTROL_SCRIPT = system.isFile(DEVICE_SCRIPT_DIR_1) and DEVICE_SCRIPT_DIR_1
	or system.isFile(DEVICE_SCRIPT_DIR_2) and DEVICE_SCRIPT_DIR_2

local MUOS_VERSION_FILE_1 = "/opt/muos/config/version.txt" -- Pixie
local MUOS_VERSION_FILE_2 = "/opt/muos/config/system/version" -- Goose
paths.MUOS_VERSION_FILE = system.isFile(MUOS_VERSION_FILE_1) and MUOS_VERSION_FILE_1
	or system.isFile(MUOS_VERSION_FILE_2) and MUOS_VERSION_FILE_2

paths.THEME_INSTALL_SCRIPT = "/opt/muos/script/package/theme.sh"

-- Assets used by the UI
paths.THEME_FONT_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/fonts"
paths.THEME_IMAGE_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/images"
paths.THEME_SOUND_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/sounds"

paths.KOFI_QR_CODE_IMAGE = "assets/images/kofi_qrcode.png"
paths.PRESETS_IMAGES_DIR = "assets/images/presets"

paths.THEME_CREDITS = paths.WORKING_THEME_DIR .. "/credits.txt"
paths.THEME_NAME = paths.WORKING_THEME_DIR .. "/name.txt"
paths.THEME_VERSION = paths.WORKING_THEME_DIR .. "/version.txt"
paths.THEME_GLYPH_DIR = paths.WORKING_THEME_DIR .. "/glyph"
paths.THEME_GLYPH_DIR_1024x768 = paths.WORKING_THEME_DIR .. "/1024x768/glyph"
paths.THEME_SOUND_DIR = paths.WORKING_THEME_DIR .. "/sound"

paths.HEADER_GLYPHS_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/icons/glyph/header"
paths.CONTROL_HINTS_SVG_DIR = paths.SOURCE_DIR .. "/assets/icons/kenney_input_prompts"

-- `scheme` directory and files
paths.THEME_SCHEME_DIR = paths.WORKING_THEME_DIR .. "/scheme"
paths.THEME_SCHEME_GLOBAL = paths.THEME_SCHEME_DIR .. "/global.ini"
paths.THEME_SCHEME_MUXPLORE = paths.THEME_SCHEME_DIR .. "/muxplore.ini"
paths.THEME_SCHEME_MUXHISTORY = paths.THEME_SCHEME_DIR .. "/muxhistory.ini"
paths.THEME_SCHEME_MUXCOLLECT = paths.THEME_SCHEME_DIR .. "/muxcollect.ini"

-- `font` directory and files
paths.THEME_FONT_DIR = paths.WORKING_THEME_DIR .. "/font"
paths.THEME_DEFAULT_FONT = paths.THEME_FONT_DIR .. "/default.bin"

paths.THEME_SCHEME_SOURCE_DIR = paths.TEMPLATE_DIR .. "/scheme"

-- `rgb` directory and files
paths.THEME_RGB_DIR = paths.WORKING_THEME_DIR .. "/rgb"
paths.THEME_RGB_CONF = paths.THEME_RGB_DIR .. "/rgbconf.sh"

-- Create getter functions for resolution-dependent paths so they update with screen dimensions
-- Get resolution directory path
function paths.getThemeResolutionDir(width, height)
	return string.format("%s/%dx%d", paths.WORKING_THEME_DIR, width, height)
end

-- Get preview image path
function paths.getThemePreviewImagePath(width, height)
	return paths.getThemeResolutionDir(width, height) .. "/preview.png"
end

-- Get resolution image directory path
function paths.getThemeResolutionImageDir(width, height)
	return paths.getThemeResolutionDir(width, height) .. "/image"
end

-- Get boot logo image path
function paths.getThemeBootlogoImagePath(width, height)
	return paths.getThemeResolutionImageDir(width, height) .. "/bootlogo.bmp"
end

-- Get muxlaunch.ini path in the resolution directory
function paths.getThemeResolutionMuxlaunchIniPath(width, height)
	return paths.getThemeResolutionDir(width, height) .. "/scheme/muxlaunch.ini"
end

paths.USERDATA_DIR = paths.ROOT_DIR .. "/userdata"

paths.USER_THEME_PRESETS_DIR = paths.USERDATA_DIR .. "/presets"
paths.SETTINGS_FILE = paths.USERDATA_DIR .. "/settings.lua"

paths.THEME_BOOTLOGO_SOURCE = paths.SOURCE_DIR .. "/assets/icons/muos/logo.svg"
paths.THEME_LOGO_OUTLINE_SOURCE = paths.SOURCE_DIR .. "/assets/icons/muos/logo_outline.svg"

paths.GLYPH_MAPPING_FILE = paths.SOURCE_DIR .. "/utils/glyph_mapping.txt"
paths.THEME_GLYPH_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/icons/lucide/glyph"

-- Theme `image` directory and files
paths.THEME_IMAGE_DIR = paths.WORKING_THEME_DIR .. "/image"
paths.THEME_REBOOT_IMAGE = paths.THEME_IMAGE_DIR .. "/reboot.png"
paths.THEME_REBOOT_ICON_SOURCE = "assets/icons/lucide/ui/refresh-cw.svg"
paths.THEME_SHUTDOWN_IMAGE = paths.THEME_IMAGE_DIR .. "/shutdown.png"
paths.THEME_SHUTDOWN_ICON_SOURCE = "assets/icons/lucide/ui/power.svg"
paths.THEME_CHARGE_IMAGE = paths.THEME_IMAGE_DIR .. "/wall/muxcharge.png"
paths.THEME_CHARGE_ICON_SOURCE = "assets/icons/lucide/ui/zap.svg"
paths.THEME_GRID_MUXLAUNCH = paths.THEME_IMAGE_DIR .. "/grid/muxlaunch"
paths.THEME_GRID_MUXLAUNCH_1024x768 = paths.WORKING_THEME_DIR .. "/1024x768/image/grid/muxlaunch"

-- Theme presets directory
paths.PRESETS_DIR = paths.SOURCE_DIR .. "/presets"

-- Home screen layout images
paths.HOME_SCREEN_LAYOUT_GRID_IMAGE = "assets/images/home_screen_layout/grid.png"
paths.HOME_SCREEN_LAYOUT_LIST_IMAGE = "assets/images/home_screen_layout/list.png"

-- Icons toggle images
paths.ICONS_TOGGLE_ENABLED_IMAGE = "assets/images/icons_toggle_samples/icons_enabled.png"
paths.ICONS_TOGGLE_DISABLED_IMAGE = "assets/images/icons_toggle_samples/icons_disabled.png"

--- TEMPORARILY DISABLED: Font size directory calculation while making font size feature more robust
--[[
paths.getFontSizeDir = function(displayWidth, displayHeight)
	return fonts.getFontSizeDir(displayWidth, displayHeight)
end
--]]

return paths
