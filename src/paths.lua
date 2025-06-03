--- Path constants
local system = require("utils.system")
local state = require("state")
local fonts = require("ui.fonts")
local errorHandler = require("error_handler")

local paths = {}

-- muOS themes directories
paths.SOURCE_DIR = system.getEnvironmentVariable("SOURCE_DIR")
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
paths.WORKING_THEME_DIR = paths.SOURCE_DIR .. "/theme_working"
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
paths.THEME_FONT_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/fonts"
paths.THEME_IMAGE_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/images"
paths.THEME_SOUND_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/sounds"

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

paths.HEADER_GLYPHS_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/icons/glyph/header"
paths.FOOTER_GLYPHS_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/icons/kenney_input_prompts"
paths.FOOTER_GLYPHS_TARGET_DIR = paths.WORKING_THEME_DIR .. "/glyph/footer"

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

-- Hardcoded paths for each supported resolution
function paths.getTheme640x480Dir()
	return paths.WORKING_THEME_DIR .. "/640x480"
end

function paths.getTheme720x480Dir()
	return paths.WORKING_THEME_DIR .. "/720x480"
end

function paths.getTheme720x576Dir()
	return paths.WORKING_THEME_DIR .. "/720x576"
end

function paths.getTheme720x720Dir()
	return paths.WORKING_THEME_DIR .. "/720x720"
end

function paths.getTheme1024x768Dir()
	return paths.WORKING_THEME_DIR .. "/1024x768"
end

function paths.getTheme1280x720Dir()
	return paths.WORKING_THEME_DIR .. "/1280x720"
end

-- Get boot logo image path for specific resolution
function paths.getThemeBootlogoImagePathForResolution(width, height)
	return paths.WORKING_THEME_DIR .. "/" .. width .. "x" .. height .. "/image/bootlogo.bmp"
end

function paths.getUserdataPath()
	local baseDir = state.isDevelopment and system.getEnvironmentVariable("DEV_DIR")
		or system.getEnvironmentVariable("ROOT_DIR")
	if not baseDir then
		return nil
	end
	return baseDir .. "/userdata"
end

function paths.getUserThemePresetsPath()
	local userdataPath = paths.getUserdataPath()
	if not userdataPath then
		return nil
	end
	return userdataPath .. "/presets"
end

function paths.getSettingsFilePath()
	local userdataPath = paths.getUserdataPath()
	if not userdataPath then
		return nil
	end
	return userdataPath .. "/settings.lua"
end

paths.THEME_BOOTLOGO_SOURCE = paths.SOURCE_DIR .. "/assets/icons/muos/logo.svg"
paths.THEME_LOGO_OUTLINE_SOURCE = paths.SOURCE_DIR .. "/assets/icons/muos/logo_outline.svg"

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
paths.PRESETS_DIR = paths.SOURCE_DIR .. "/presets"

-- Home screen layout images
paths.HOME_SCREEN_LAYOUT_GRID_IMAGE = "assets/images/home_screen_layout/grid.png"
paths.HOME_SCREEN_LAYOUT_LIST_IMAGE = "assets/images/home_screen_layout/list.png"

-- Icons toggle images
paths.ICONS_TOGGLE_ENABLED_IMAGE = "assets/images/icons_toggle_samples/icons_enabled.png"
paths.ICONS_TOGGLE_DISABLED_IMAGE = "assets/images/icons_toggle_samples/icons_disabled.png"

-- Header alignment images
paths.HEADER_ALIGNMENT_LEFT_IMAGE = "assets/images/header_alignment/header_alignment_left.png"
paths.HEADER_ALIGNMENT_CENTER_IMAGE = "assets/images/header_alignment/header_alignment_center.png"
paths.HEADER_ALIGNMENT_RIGHT_IMAGE = "assets/images/header_alignment/header_alignment_right.png"

--- TEMPORARILY DISABLED: Font size directory calculation while making font size feature more robust
--[[
paths.getFontSizeDir = function(displayWidth, displayHeight)
	return fonts.getFontSizeDir(displayWidth, displayHeight)
end
--]]

return paths
