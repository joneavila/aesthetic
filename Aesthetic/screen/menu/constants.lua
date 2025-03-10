--- Menu constants
local state = require("state")
local controls = require("controls")

local constants = {}

-- Screen identifiers
constants.COLOR_PICKER_SCREEN = "color_picker"
constants.ABOUT_SCREEN = "about"
constants.FONT_SCREEN = "font"

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

-- Constants for paths
constants.ORIGINAL_TEMPLATE_DIR = os.getenv("TEMPLATE_DIR") or "template" -- Store original template path
constants.WORKING_TEMPLATE_DIR = constants.ORIGINAL_TEMPLATE_DIR .. "_working" -- Add working directory path
constants.THEME_OUTPUT_DIR = constants.WORKING_TEMPLATE_DIR

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
}

return constants
