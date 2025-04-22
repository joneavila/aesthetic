--- Menu constants
local state = require("state")
local controls = require("controls")

local constants = {}

-- Screen identifiers
constants.COLOR_PICKER_SCREEN = "color_picker"
constants.ABOUT_SCREEN = "about"
constants.FONT_SCREEN = "font"
constants.RGB_SCREEN = "rgb"

-- Screen height to font size mapping
constants.SCREEN_HEIGHT_MAPPING = {
	[768] = { fontSizeDir = "38", imageFontSize = 45 },
	[720] = { fontSizeDir = "36", imageFontSize = 42 },
	[576] = { fontSizeDir = "29", imageFontSize = 34 },
	[480] = { fontSizeDir = "24", imageFontSize = 28 },
}

-- Helper function to get font size info based on screen height
constants.getFontSizeInfo = function(height)
	local sizeInfo = constants.SCREEN_HEIGHT_MAPPING[height]
	return sizeInfo
end

-- Image font size based on screen height
constants.getImageFontSize = function()
	local sizeInfo = constants.getFontSizeInfo(state.screenHeight)
	return sizeInfo and sizeInfo.imageFontSize
end

constants.IMAGE_FONT_SIZE = constants.getImageFontSize()

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
		text = "RGB lighting",
		selected = false,
		rgbLighting = true,
	},
	{
		text = "Font family",
		selected = false,
		fontSelection = true,
	},
	{
		text = "Font size",
		selected = false,
		fontSizeToggle = true,
	},
	{
		text = "Icons",
		selected = false,
		glyphsToggle = true,
	},
	{
		text = "Box art width",
		selected = false,
		boxArt = true,
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
