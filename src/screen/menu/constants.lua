--- Menu constants
local state = require("state")
local controls = require("controls")

local constants = {}

-- Screen identifiers
constants.COLOR_PICKER_SCREEN = "color_picker"
constants.ABOUT_SCREEN = "about"
constants.FONT_SCREEN = "font"

constants.IMAGE_FONT_SIZE = 45

-- Error display time
constants.ERROR_DISPLAY_TIME_SECONDS = 5

-- Button dimensions and position
constants.BUTTON = {
	WIDTH = nil, -- Will be calculated in load()
	HEIGHT = 50,
	PADDING = 20,
	CORNER_RADIUS = 8,
	SELECTED_OUTLINE_WIDTH = 4,
	COLOR_DISPLAY_SIZE = 30,
	START_Y = nil, -- Will be calculated in load()
	HELP_BUTTON_SIZE = 40,
	BOTTOM_MARGIN = 100, -- Margin from bottom for the "Create theme" button
}

constants.BOTTOM_PADDING = controls.HEIGHT

-- Button state
constants.BUTTONS = {
	{
		text = "Background color",
		selected = true,
		colorKey = "background",
	},
	{
		text = "Foreground color",
		selected = false,
		colorKey = "foreground",
	},
	{
		text = "Font",
		selected = false,
		fontSelection = true,
	},
	{
		text = "Icons",
		selected = false,
		glyphsToggle = true,
	},
	{
		text = "Create theme",
		selected = false,
		isBottomButton = true,
	},
}

-- Popup buttons
constants.POPUP_BUTTONS = {
	{
		text = "Exit",
		selected = true,
	},
	{
		text = "Back",
		selected = false,
	},
}

-- TODO: Make os.getenv() safer
-- TODO: Create files like `name.txt` dynamically
-- TODO: You can initialize the paths here
constants.PATHS = {
	TEMPLATE_DIR = os.getenv("TEMPLATE_DIR"),
}

-- Create a local alias for easier access
local paths = constants.PATHS

-- muOS themes directory
paths.THEME_DIR = "/run/muos/storage/theme"

-- Working theme directory where files are written before archiving into a theme
paths.WORKING_THEME_DIR = paths.TEMPLATE_DIR .. "_working"

-- Active theme directory where files of the currently active theme are stored
paths.THEME_ACTIVE_DIR = paths.THEME_DIR .. "/active"

-- Generated theme path where the generated theme is written
paths.THEME_OUTPUT_PATH = paths.THEME_DIR .. "/" .. state.applicationName .. ".muxthm"

-- muOS version file path (contains version info)
paths.MUOS_VERSION_PATH = "/opt/muos/config/version.txt"
-- Theme version file path
-- Assuming the application is updated with every release, this file will contain
-- the version info read from muOS
paths.THEME_VERSION_PATH = paths.THEME_DIR .. "/version.txt"

-- Assets used by UI rather than generated theme
paths.THEME_FONT_SOURCE_DIR = paths.TEMPLATE_DIR .. "/font"

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

-- `font`
paths.THEME_FONT_DIR = paths.WORKING_THEME_DIR .. "/font"
paths.THEME_DEFAULT_FONT_PATH = paths.THEME_FONT_DIR .. "/default.bin"

-- `glyph`
paths.THEME_GLYPH_SOURCE_PATH = paths.TEMPLATE_DIR .. "/glyph"
paths.THEME_GLYPH_PATH = paths.WORKING_THEME_DIR .. "/glyph"

-- `<width>x<height>`
paths.THEME_RESOLUTION_DIR = paths.WORKING_THEME_DIR .. "/" .. state.screenWidth .. "x" .. state.screenHeight
paths.THEME_PREVIEW_IMAGE_PATH = paths.THEME_RESOLUTION_DIR .. "/preview.png"
-- `<width>x<height>/image`
paths.THEME_IMAGE_DIR = paths.THEME_RESOLUTION_DIR .. "/image"
paths.THEME_BOOTLOGO_IMAGE_PATH = paths.THEME_IMAGE_DIR .. "/bootlogo.bmp"
paths.THEME_REBOOT_IMAGE_PATH = paths.THEME_IMAGE_DIR .. "/reboot.png"

-- Font options
constants.FONTS = {
	{
		name = "Inter",
		file = "inter.bin",
		selected = state.selectedFont == "Inter",
	},
	{
		name = "Nunito",
		file = "nunito.bin",
		selected = state.selectedFont == "Nunito",
	},
	{
		name = "Cascadia Code",
		file = "cascadia_code.bin",
		selected = state.selectedFont == "Cascadia Code",
	},
	{
		name = "Retro Pixel",
		file = "retro_pixel.bin",
		selected = state.selectedFont == "Retro Pixel",
	},
}

return constants
