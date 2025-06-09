--- Path constants
local system = require("utils.system")
local state = require("state")
local errorHandler = require("error_handler")
local logger = require("utils.logger")

local paths = {}

paths.SOURCE_DIR = system.getEnvironmentVariable("SOURCE_DIR")
paths.ROOT_DIR = system.getEnvironmentVariable("ROOT_DIR")
logger.debug("ROOT_DIR: " .. paths.ROOT_DIR)

paths.MUOS_THEME_SCRIPT = "/opt/muos/script/package/theme.sh"
paths.MUOS_THEMES_DIR = "/run/muos/storage/theme"

paths.USERDATA_DIR = paths.ROOT_DIR .. "/userdata"
paths.USERDATA_THEME_PRESETS_DIR = paths.USERDATA_DIR .. "/presets"
paths.USERDATA_SETTINGS_FILE = paths.USERDATA_DIR .. "/settings.lua"

paths.WORKING_THEME_DIR = paths.ROOT_DIR .. "/theme_working"

paths.ACTIVE_THEME_DIR = paths.MUOS_THEMES_DIR .. "/active"
logger.debug("ACTIVE_THEME_DIR: " .. paths.ACTIVE_THEME_DIR)
paths.ACTIVE_RGB_CONF = paths.ACTIVE_THEME_DIR .. "/rgb/rgbconf.sh"
logger.debug("ACTIVE_RGB_CONF: " .. paths.ACTIVE_RGB_CONF)
paths.ACTIVE_RGB_CONF_BACKUP = paths.ACTIVE_THEME_DIR .. "/rgb/rgbconf.sh.bak"

local LED_CONTROL_SCRIPT_PIXIE = "/opt/muos/device/current/script/led_control.sh"
local LED_CONTROL_SCRIPT_GOOSE = "/opt/muos/device/script/led_control.sh"
paths.LED_CONTROL_SCRIPT = system.isFile(LED_CONTROL_SCRIPT_PIXIE) and LED_CONTROL_SCRIPT_PIXIE
	or system.isFile(LED_CONTROL_SCRIPT_GOOSE) and LED_CONTROL_SCRIPT_GOOSE

local MUOS_VERSION_FILE_PIXIE = "/opt/muos/config/version.txt"
local MUOS_VERSION_FILE_GOOSE = "/opt/muos/config/system/version"
paths.MUOS_VERSION_FILE = system.isFile(MUOS_VERSION_FILE_PIXIE) and MUOS_VERSION_FILE_PIXIE
	or system.isFile(MUOS_VERSION_FILE_GOOSE) and MUOS_VERSION_FILE_GOOSE

paths.THEME_SOUND_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/sounds"

paths.THEME_CREDITS = paths.WORKING_THEME_DIR .. "/credits.txt"
paths.THEME_NAME = paths.WORKING_THEME_DIR .. "/name.txt"
paths.THEME_VERSION = paths.WORKING_THEME_DIR .. "/version.txt"
paths.THEME_GLYPH_DIR = paths.WORKING_THEME_DIR .. "/glyph"
paths.THEME_GLYPH_DIR_1024x768 = paths.WORKING_THEME_DIR .. "/1024x768/glyph"
paths.THEME_SOUND_DIR = paths.WORKING_THEME_DIR .. "/sound"

paths.GLYPHS_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/icons/glyph"
paths.GLYPHS_SOURCE_DIR_1024x768 = paths.SOURCE_DIR .. "/assets/1024x768/glyph"
paths.HEADER_GLYPHS_SOURCE_DIR = paths.GLYPHS_SOURCE_DIR .. "/header"
paths.CONTROL_HINTS_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/icons/kenney_input_prompts"

paths.THEME_SCHEME_DIR = paths.WORKING_THEME_DIR .. "/scheme"
paths.THEME_SCHEME_GLOBAL = paths.THEME_SCHEME_DIR .. "/global.ini"
paths.THEME_SCHEME_MUXPLORE = paths.THEME_SCHEME_DIR .. "/muxplore.ini"
paths.THEME_SCHEME_MUXHISTORY = paths.THEME_SCHEME_DIR .. "/muxhistory.ini"
paths.THEME_SCHEME_MUXCOLLECT = paths.THEME_SCHEME_DIR .. "/muxcollect.ini"

paths.THEME_FONT_DIR = paths.WORKING_THEME_DIR .. "/font"
paths.THEME_DEFAULT_FONT = paths.THEME_FONT_DIR .. "/default.bin"

paths.SCHEME_TEMPLATE_DIR = paths.SOURCE_DIR .. "/scheme_templates"
paths.THEME_SCHEME_SOURCE_DIR = paths.SCHEME_TEMPLATE_DIR .. "/scheme"

paths.THEME_RGB_CONF = paths.WORKING_THEME_DIR .. "/rgb/rgbconf.sh"

paths.THEME_BOOTLOGO_SOURCE = paths.SOURCE_DIR .. "/assets/icons/muos/logo.svg"
paths.THEME_LOGO_OUTLINE_SOURCE = paths.SOURCE_DIR .. "/assets/icons/muos/logo_outline.svg"

paths.GLYPH_MAPPING_FILE = paths.SOURCE_DIR .. "/utils/glyph_mapping.txt"
paths.THEME_GLYPH_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/icons/lucide/glyph"

paths.THEME_IMAGE_DIR = paths.WORKING_THEME_DIR .. "/image"
paths.THEME_REBOOT_IMAGE = paths.THEME_IMAGE_DIR .. "/reboot.png"
paths.THEME_REBOOT_ICON_SOURCE = "assets/icons/lucide/ui/refresh-cw.svg"
paths.THEME_SHUTDOWN_IMAGE = paths.THEME_IMAGE_DIR .. "/shutdown.png"
paths.THEME_SHUTDOWN_ICON_SOURCE = "assets/icons/lucide/ui/power.svg"
paths.THEME_CHARGE_IMAGE = paths.THEME_IMAGE_DIR .. "/wall/muxcharge.png"
paths.THEME_CHARGE_ICON_SOURCE = "assets/icons/lucide/ui/zap.svg"
paths.THEME_GRID_MUXLAUNCH = paths.THEME_IMAGE_DIR .. "/grid/muxlaunch"
paths.THEME_GRID_MUXLAUNCH_1024x768 = paths.WORKING_THEME_DIR .. "/1024x768/image/grid/muxlaunch"

paths.THEME_PRESETS_DIR = paths.SOURCE_DIR .. "/presets"

paths.UI_KOFI_QR_CODE_IMAGE = "assets/images/kofi_qrcode.png"
paths.UI_HOME_SCREEN_LAYOUT_GRID_IMAGE = "assets/images/home_screen_layout/grid.png"
paths.UI_HOME_SCREEN_LAYOUT_LIST_IMAGE = "assets/images/home_screen_layout/list.png"
paths.UI_ICONS_TOGGLE_ENABLED_IMAGE = "assets/images/icons_toggle_samples/icons_enabled.png"
paths.UI_ICONS_TOGGLE_DISABLED_IMAGE = "assets/images/icons_toggle_samples/icons_disabled.png"

paths.SUPPORTED_THEME_RESOLUTIONS = {
	"640x480",
	"720x480",
	"720x576",
	"720x720",
	"1024x768",
	"1280x720",
}

function paths.getThemeResolutionDir(width, height)
	return string.format("%s/%dx%d", paths.WORKING_THEME_DIR, width, height)
end

function paths.getThemePreviewImagePath(width, height)
	return paths.getThemeResolutionDir(width, height) .. "/preview.png"
end

function paths.getThemeBootlogoImagePath(width, height)
	return paths.getThemeResolutionDir(width, height) .. "/image/bootlogo.bmp"
end

function paths.getThemeMuxlaunchSchemePath(width, height)
	return paths.getThemeResolutionDir(width, height) .. "/scheme/muxlaunch.ini"
end

-- Helper to execute a function for all supported resolutions
function paths.forEachResolution(func)
	for _, resolution in ipairs(paths.SUPPORTED_THEME_RESOLUTIONS) do
		local width, height = resolution:match("(%d+)x(%d+)")
		width, height = tonumber(width), tonumber(height)
		local success, err = func(width, height)
		if not success then
			return false, err
		end
	end
	return true
end

return paths
