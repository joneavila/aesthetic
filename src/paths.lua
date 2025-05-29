--- Path constants
local system = require("utils.system")
local state = require("state")
local fonts = require("ui.fonts")
local errorHandler = require("error_handler")

local paths = {}

-- muOS themes directories
paths.ROOT_DIR = system.getEnvironmentVariable("ROOT_DIR")
paths.TEMPLATE_DIR = system.getEnvironmentVariable("TEMPLATE_DIR")

-- Get dev directory if in development mode
local devDir = nil
if state.isDevelopment then
	devDir = system.getEnvironmentVariable("DEV_DIR")
	if not devDir then
		errorHandler.setError("DEV_DIR environment variable not set but isDevelopment is true")
	end
end

-- Working theme directory where files are written before archiving into a theme
paths.WORKING_THEME_DIR = paths.ROOT_DIR .. "/theme_working"
if state.isDevelopment then
	paths.WORKING_THEME_DIR = devDir .. "/theme_working"
end

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

-- Device script directory for LED control
local deviceScriptDir = system.getEnvironmentVariable("MUOS_DEVICE_SCRIPT_DIR")
paths.DEVICE_SCRIPT_DIR = deviceScriptDir
paths.LED_CONTROL_SCRIPT = paths.DEVICE_SCRIPT_DIR .. "/led_control.sh"

-- muOS version file path (contains version info)
local muosConfigDir = deviceScriptDir:gsub("/device/current/script", "/config")
paths.MUOS_VERSION = muosConfigDir .. "/version.txt"

paths.THEME_INSTALL_SCRIPT = "/opt/muos/script/package/theme.sh"

-- Assets used by the UI
paths.THEME_FONT_SOURCE_DIR = paths.ROOT_DIR .. "/assets/fonts"
paths.THEME_IMAGE_SOURCE_DIR = paths.ROOT_DIR .. "/assets/images"
paths.THEME_SOUND_SOURCE_DIR = paths.ROOT_DIR .. "/assets/sounds"

paths.KOFI_QR_CODE_IMAGE = "assets/images/kofi_qrcode.png"
paths.PRESETS_IMAGES_DIR = "assets/images/presets"

-- Get preset image path for a specific preset
function paths.getPresetImagePath(presetName)
	return paths.PRESETS_IMAGES_DIR .. "/" .. presetName .. ".png"
end

paths.THEME_CREDITS = paths.WORKING_THEME_DIR .. "/credits.txt"
paths.THEME_NAME = paths.WORKING_THEME_DIR .. "/name.txt"
paths.THEME_VERSION = paths.WORKING_THEME_DIR .. "/version.txt"
paths.THEME_GLYPH_DIR = paths.WORKING_THEME_DIR .. "/glyph"
paths.THEME_SOUND_DIR = paths.WORKING_THEME_DIR .. "/sound"

paths.HEADER_GLYPHS_SOURCE_DIR = paths.ROOT_DIR .. "/assets/icons/glyph/header"

-- `scheme` directory and files
paths.THEME_SCHEME_DIR = paths.WORKING_THEME_DIR .. "/scheme"
paths.THEME_SCHEME_GLOBAL = paths.THEME_SCHEME_DIR .. "/global.ini"
paths.THEME_SCHEME_MUXPLORE = paths.THEME_SCHEME_DIR .. "/muxplore.ini"

-- `font` directory and files
paths.THEME_FONT_DIR = paths.WORKING_THEME_DIR .. "/font"
paths.THEME_DEFAULT_FONT = paths.THEME_FONT_DIR .. "/default.bin"

paths.THEME_SCHEME_SOURCE_DIR = paths.TEMPLATE_DIR .. "/scheme"

-- `rgb` directory and files
paths.THEME_RGB_DIR = paths.WORKING_THEME_DIR .. "/rgb"
paths.THEME_RGB_CONF = paths.THEME_RGB_DIR .. "/rgbconf.sh"

-- Create getter functions for resolution-dependent paths so they update with screen dimensions
-- Get resolution directory path
function paths.getThemeResolutionDir()
	return paths.WORKING_THEME_DIR .. "/" .. state.screenWidth .. "x" .. state.screenHeight
end

-- Get preview image path
function paths.getThemePreviewImagePath()
	return paths.getThemeResolutionDir() .. "/preview.png"
end

-- Get resolution image directory path
function paths.getThemeResolutionImageDir()
	return paths.getThemeResolutionDir() .. "/image"
end

-- Get boot logo image path
function paths.getThemeBootlogoImagePath()
	return paths.getThemeResolutionImageDir() .. "/bootlogo.bmp"
end

-- Get muxlaunch.ini path in the resolution directory
function paths.getThemeResolutionMuxlaunchIniPath()
	return paths.getThemeResolutionDir() .. "/scheme/muxlaunch.ini"
end

paths.THEME_BOOTLOGO_SOURCE = paths.ROOT_DIR .. "/assets/icons/muos/logo.svg"
paths.THEME_LOGO_OUTLINE_SOURCE = paths.ROOT_DIR .. "/assets/icons/muos/logo_outline.svg"

-- Theme `image` directory and files
paths.THEME_IMAGE_DIR = paths.WORKING_THEME_DIR .. "/image"
paths.THEME_REBOOT_IMAGE = paths.THEME_IMAGE_DIR .. "/reboot.png"
paths.THEME_REBOOT_ICON_SOURCE = "assets/icons/lucide/ui/refresh-cw.svg"
paths.THEME_SHUTDOWN_IMAGE = paths.THEME_IMAGE_DIR .. "/shutdown.png"
paths.THEME_SHUTDOWN_ICON_SOURCE = "assets/icons/lucide/ui/power.svg"
paths.THEME_CHARGE_IMAGE = paths.THEME_IMAGE_DIR .. "/wall/muxcharge.png"
paths.THEME_CHARGE_ICON_SOURCE = "assets/icons/lucide/ui/zap.svg"
paths.THEME_GRID_MUXLAUNCH = paths.THEME_IMAGE_DIR .. "/grid/muxlaunch"

-- Theme presets directory
paths.PRESETS_DIR = paths.ROOT_DIR .. "/presets"

--- Returns the closest available bin font size directory (as a string) for the given display dimensions, using the
--- diagonal and a base size of 28 for 640x480.
paths.getFontSizeDir = function(displayWidth, displayHeight)
	return fonts.getFontSizeDir(displayWidth, displayHeight)
end

return paths
