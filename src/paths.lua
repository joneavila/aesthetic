--- Path constants
local system = require("utils.system")
local state = require("state")

local paths = {}

-- muOS themes directories
paths.ROOT_DIR = system.getEnvironmentVariable("ROOT_DIR")
paths.TEMPLATE_DIR = system.getEnvironmentVariable("TEMPLATE_DIR")

-- muOS themes directory
paths.THEME_DIR = "/run/muos/storage/theme"

-- Working theme directory where files are written before archiving into a theme
paths.WORKING_THEME_DIR = paths.TEMPLATE_DIR .. "_working"

-- Active theme directory where files of the currently active theme are stored
paths.THEME_ACTIVE_DIR = paths.THEME_DIR .. "/active"

-- Active RGB configuration paths
paths.ACTIVE_RGB_DIR = "/run/muos/storage/theme/active/rgb"
paths.ACTIVE_RGB_CONF_PATH = paths.ACTIVE_RGB_DIR .. "/rgbconf.sh"
paths.ACTIVE_RGB_CONF_BACKUP_PATH = paths.ACTIVE_RGB_DIR .. "/rgbconf.sh.bak"

-- Generated theme path where the generated theme is written
paths.THEME_OUTPUT_PATH = paths.THEME_DIR .. "/" .. state.applicationName .. ".muxthm"

-- muOS version file path (contains version info)
paths.MUOS_VERSION_PATH = "/opt/muos/config/version.txt"
-- Theme version file path
-- Assuming the application is updated with every release, this file will contain
-- the version info read from muOS
paths.THEME_VERSION_PATH = paths.THEME_DIR .. "/version.txt"

-- Assets used by UI rather than generated theme
paths.THEME_FONT_SOURCE_DIR = paths.ROOT_DIR .. "/assets/fonts"
paths.THEME_IMAGE_SOURCE_DIR = paths.ROOT_DIR .. "/assets/images"

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
paths.THEME_GLYPH_SOURCE_PATH = paths.TEMPLATE_DIR .. "/glyph"
paths.THEME_GLYPH_PATH = paths.WORKING_THEME_DIR .. "/glyph"

-- `rgb`
paths.THEME_RGB_DIR = paths.WORKING_THEME_DIR .. "/rgb"
paths.THEME_RGB_CONF_PATH = paths.THEME_RGB_DIR .. "/rgbconf.sh"

-- `<width>x<height>`
paths.THEME_RESOLUTION_DIR = paths.WORKING_THEME_DIR .. "/" .. state.screenWidth .. "x" .. state.screenHeight
paths.THEME_PREVIEW_IMAGE_PATH = paths.THEME_RESOLUTION_DIR .. "/preview.png"
-- `<width>x<height>/image`
paths.THEME_IMAGE_DIR = paths.THEME_RESOLUTION_DIR .. "/image"
paths.THEME_BOOTLOGO_IMAGE_PATH = paths.THEME_IMAGE_DIR .. "/bootlogo.bmp"
paths.THEME_REBOOT_IMAGE_PATH = paths.THEME_IMAGE_DIR .. "/reboot.png"
paths.THEME_SHUTDOWN_IMAGE_PATH = paths.THEME_IMAGE_DIR .. "/shutdown.png"

-- Theme presets directory
paths.PRESETS_DIR = paths.ROOT_DIR .. "/presets"

-- Screen height to font size mapping
local SCREEN_HEIGHT_MAPPING = {
	[768] = { fontSizeDir = "38", imageFontSize = 45 },
	[720] = { fontSizeDir = "36", imageFontSize = 42 },
	[576] = { fontSizeDir = "29", imageFontSize = 34 },
	[480] = { fontSizeDir = "24", imageFontSize = 28 },
}

-- Add font size directory paths based on screen height mapping
for height, info in pairs(SCREEN_HEIGHT_MAPPING) do
	paths["THEME_FONT_SIZE_" .. info.fontSizeDir .. "_DIR"] = paths.THEME_FONT_SOURCE_DIR .. "/" .. info.fontSizeDir
end

-- Function to get font size info based on screen height
paths.getFontSizeInfo = function(height)
	return SCREEN_HEIGHT_MAPPING[height]
end

-- Function to get image font size based on screen height
paths.getImageFontSize = function(height)
	local sizeInfo = SCREEN_HEIGHT_MAPPING[height]
	return sizeInfo and sizeInfo.imageFontSize
end

return paths
