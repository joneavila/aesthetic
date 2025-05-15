--- State management module
---
--- This module centralizes all global application state
---
--- Note: When adding new state properties that should persist between sessions, consider updating the `settings.lua`
--- module to include these properties in the configuration file. The settings module handles saving and loading
--- persistent application settings.

--- Creates a new color context with a default color
--- A color context represents a single configurable color in the application
--- Color contexts enable the same UI components to modify different colors (background, foreground, RGB lighting, etc.)
--- Each context stores:
---   1. The current color value in hex format
---   2. State for the color palette picker
---   3. State for the HSV color picker
---   4. State for the hex color picker
local fonts = require("ui.fonts")
local errorHandler = require("error_handler")
local colorUtils = require("utils.color")
local logger = require("utils.logger")

local function createColorContext(defaultColor)
	logger.debug("Creating color context with default color: " .. defaultColor)
	return {
		-- Palette state
		palette = {
			selectedRow = 0,
			selectedCol = 0,
			scrollY = 0,
		},
		-- HSV state
		hsv = {
			hue = 0,
			sat = 1,
			val = 1,
			focusSquare = false,
			cursor = { svX = nil, svY = nil, hueY = nil },
		},
		-- Hex state
		hex = {
			input = "",
			selectedButton = { row = 1, col = 1 },
		},
		-- The current hex color value
		currentColor = defaultColor,
	}
end

--- Main state table containing all global application state
local state = {
	applicationName = "Aesthetic",
	themeName = "Aesthetic", -- Default theme name

	-- Screen dimensions are set in `src/main.lua`
	screenWidth = 0,
	screenHeight = 0,

	-- Development mode flag
	isDevelopment = os.getenv("DEV_DIR") ~= nil,

	-- Font settings (moved to ui.fonts but kept references here for compatibility)
	fonts = fonts.loaded,
	selectedFont = "Inter",
	fontSize = "Default",

	previousScreen = "main_menu", -- Default screen to return to after color picker
	glyphs_enabled = true, -- Default value for glyphs enabled

	-- Set the alignment of the theme's bottom navigation icons and text
	navigationAlignment = "Left", -- Default navigation alignment (Left, Center, Right)
	navigationAlpha = 100, -- Default navigation alpha (0-100)

	-- Set the alignment of the status bar
	-- Default status alignment (Left, Right, Center, Space Evenly, Equal Distribution, Edge Anchored)
	statusAlignment = "Right",

	-- Box art settings
	boxArtWidth = 0, -- Default box art width (0 means disabled)

	-- Time alignment setting
	timeAlignment = "Left", -- Default time alignment (Auto, Left, Center, Right)

	-- RGB lighting related settings
	rgbMode = "Solid", -- Default RGB lighting mode
	rgbBrightness = 5, -- Default RGB brightness (1-10)
	rgbSpeed = 5, -- Default RGB speed (1-10)

	themeApplied = false, -- Whether the theme has been applied
	source = "user", -- Default source type for themes (user-created vs built-in)

	-- Color contexts
	activeColorContext = "background", -- Default active color context
	colorContexts = { -- Stores theme's configurable colors
		background = createColorContext("#1E40AF"), -- Default background color
		foreground = createColorContext("#DBEAFE"), -- Default foreground color
		rgb = createColorContext("#1E40AF"), -- Default RGB lighting color
	},

	headerTextEnabled = "Disabled", -- Default value for header text (Enabled/Disabled)
}

logger.debug("State initialized with dimensions: " .. state.screenWidth .. "x" .. state.screenHeight)
logger.debug("Application name: " .. state.applicationName)

--- Helper function to get a color context
function state.getColorContext(contextKey)
	if not state.colorContexts[contextKey] then
		local errorMsg = "Color context '"
			.. contextKey
			.. "' does not exist. Create it first using createColorContext."
		logger.error(errorMsg)
		error(errorMsg)
	end
	return state.colorContexts[contextKey]
end

--- Helper function to get the current color value for a context
function state.getColorValue(contextKey)
	local context = state.getColorContext(contextKey)
	return context.currentColor
end

--- Helper function to set the current color value for a context
function state.setColorValue(contextKey, colorValue)
	-- Only accept hex color values
	if colorValue:sub(1, 1) ~= "#" then
		local errorMsg = "Failed to set color value: only hex color strings (starting with #) are supported. Got: "
			.. tostring(colorValue)
		logger.error(errorMsg)
		errorHandler.setError(errorMsg)
		return
	end
	local normalizedColor = colorValue
	local context = state.getColorContext(contextKey)
	context.currentColor = normalizedColor

	-- Initialize the hex input with the new value
	context.hex.input = normalizedColor:sub(2) -- Remove # sign

	-- Initialize HSV values based on RGB
	local r, g, b = colorUtils.hexToRgb(normalizedColor)
	local h, s, v = colorUtils.rgbToHsv(r, g, b)
	context.hsv.hue = h * 360 -- Convert 0-1 to 0-360
	context.hsv.sat = s
	context.hsv.val = v

	return normalizedColor
end

--- Helper function to get a font by name (delegated to fonts)
function state.getFontByName(fontName)
	return fonts.getByName(fontName)
end

--- Helper function to set the default font (delegated to fonts)
function state.setDefaultFont()
	fonts.setDefault()
end

return state
