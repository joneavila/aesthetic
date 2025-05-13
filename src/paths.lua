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

-- muOS themes directory - using environment variable
local muosThemeDir = system.getEnvironmentVariable("MUOS_STORAGE_THEME_DIR")
paths.THEME_DIR = muosThemeDir

-- Working theme directory where files are written before archiving into a theme
if state.isDevelopment then
	-- Use .dev/theme_working when running from dev_launch.sh
	paths.WORKING_THEME_DIR = devDir .. "/theme_working"
else
	-- Use the standard directory otherwise
	paths.WORKING_THEME_DIR = paths.ROOT_DIR .. "/theme_working"
end

-- Active theme directory where files of the currently active theme are stored
paths.THEME_ACTIVE_DIR = paths.THEME_DIR .. "/active"

-- Active RGB configuration paths
paths.ACTIVE_RGB_DIR = paths.THEME_ACTIVE_DIR .. "/rgb"
paths.ACTIVE_RGB_CONF_PATH = paths.ACTIVE_RGB_DIR .. "/rgbconf.sh"
paths.ACTIVE_RGB_CONF_BACKUP_PATH = paths.ACTIVE_RGB_DIR .. "/rgbconf.sh.bak"

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
paths.MUOS_VERSION_PATH = muosConfigDir .. "/version.txt"
-- Theme version file path
-- Assuming the application is updated with every release, this file will contain
-- the version info read from muOS
paths.THEME_VERSION_PATH = paths.THEME_DIR .. "/version.txt"

-- Assets used by UI rather than generated theme
paths.THEME_FONT_SOURCE_DIR = paths.ROOT_DIR .. "/assets/fonts"
paths.THEME_IMAGE_SOURCE_DIR = paths.ROOT_DIR .. "/assets/images"
paths.THEME_SOUND_SOURCE_DIR = paths.ROOT_DIR .. "/assets/sounds"

-- `credits.txt`
paths.THEME_CREDITS_PATH = paths.WORKING_THEME_DIR .. "/credits.txt"

-- `version.txt`
paths.THEME_VERSION_PATH = paths.WORKING_THEME_DIR .. "/version.txt"

-- `name.txt`
paths.THEME_NAME_PATH = paths.WORKING_THEME_DIR .. "/name.txt"

-- `scheme`
paths.THEME_SCHEME_DIR = paths.WORKING_THEME_DIR .. "/scheme"
paths.THEME_SCHEME_SOURCE_DIR = paths.TEMPLATE_DIR .. "/scheme"
paths.THEME_SCHEME_GLOBAL_PATH = paths.THEME_SCHEME_DIR .. "/global.ini"
paths.THEME_SCHEME_MUXPLORE_PATH = paths.THEME_SCHEME_DIR .. "/muxplore.ini"

-- `font`
paths.THEME_FONT_DIR = paths.WORKING_THEME_DIR .. "/font"
paths.THEME_DEFAULT_FONT_PATH = paths.THEME_FONT_DIR .. "/default.bin"

-- `glyph`
paths.THEME_GLYPH_SOURCE_PATH = paths.ROOT_DIR .. "/assets/icons/glyph"
paths.THEME_GLYPH_PATH = paths.WORKING_THEME_DIR .. "/glyph"

-- `rgb`
paths.THEME_RGB_DIR = paths.WORKING_THEME_DIR .. "/rgb"
paths.THEME_RGB_CONF_PATH = paths.THEME_RGB_DIR .. "/rgbconf.sh"

-- `sound`
paths.THEME_SOUND_PATH = paths.WORKING_THEME_DIR .. "/sound"

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

-- Keep these for backwards compatibility but deprecate their use
paths.THEME_RESOLUTION_DIR = paths.WORKING_THEME_DIR .. "/0x0" -- Will be replaced by function call
paths.THEME_PREVIEW_IMAGE_PATH = paths.THEME_RESOLUTION_DIR .. "/preview.png" -- Will be replaced by function call
paths.THEME_RESOLUTION_IMAGE_DIR = paths.THEME_RESOLUTION_DIR .. "/image" -- Will be replaced by function call
paths.THEME_BOOTLOGO_SOURCE_PATH = paths.ROOT_DIR .. "/assets/icons/muos/logo.svg"
paths.THEME_BOOTLOGO_IMAGE_PATH = paths.THEME_RESOLUTION_IMAGE_DIR .. "/bootlogo.bmp" -- Will be replaced by function call

-- `image`
paths.THEME_IMAGE_DIR = paths.WORKING_THEME_DIR .. "/image"
paths.THEME_REBOOT_IMAGE_PATH = paths.THEME_IMAGE_DIR .. "/reboot.png"
paths.THEME_SHUTDOWN_IMAGE_PATH = paths.THEME_IMAGE_DIR .. "/shutdown.png"

-- `image/wall`
paths.THEME_CHARGE_IMAGE_PATH = paths.THEME_IMAGE_DIR .. "/wall/muxcharge.png"
paths.BATTERY_CHARGING_ICON_PATH = "assets/icons/lucide/ui/battery-charging.svg"

-- Theme presets directory
paths.PRESETS_DIR = paths.ROOT_DIR .. "/presets"

-- Presets images directory - use direct path for LÖVE compatibility
paths.PRESETS_IMAGES_DIR = "assets/images/presets"

-- Screen height to font size mapping
local SCREEN_HEIGHT_MAPPING = fonts.screenHeightMapping

-- Add font size directory paths based on screen height mapping
for _, info in pairs(SCREEN_HEIGHT_MAPPING) do
	paths["THEME_FONT_SIZE_" .. info.fontSizeDir .. "_DIR"] = paths.THEME_FONT_SOURCE_DIR .. "/" .. info.fontSizeDir
end

-- Function to get font size info based on screen height
paths.getFontSizeInfo = function(height)
	return fonts.screenHeightMapping[height]
end

-- Function to get image font size based on screen height
paths.getImageFontSize = function(height)
	return fonts.screenHeightMapping[height] and fonts.screenHeightMapping[height].imageFontSize
end

return paths
