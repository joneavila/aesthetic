--- State management module
---
--- This module centralizes all global application state
---
--- Note: When adding new state properties that should persist between sessions, consider updating the `settings.lua`
--- module to include these properties in the configuration file. The settings module handles saving and loading
--- persistent application settings.
local errorHandler = require("error_handler")

local colorUtils = require("utils.color")
local logger = require("utils.logger")

--- Creates a new color context with a default color
--- A color context represents a single configurable color in the application
--- Color contexts enable the same UI components to modify different colors (background, foreground, RGB lighting, etc.)
--- Each context stores:
---   1. The current color value in hex format
---   2. State for the color palette picker
---   3. State for the HSV color picker
---   4. State for the hex color picker
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
	themeName = "Aesthetic", -- Theme name
	screenWidth = 0, -- Set in `main.lua`
	screenHeight = 0, -- Set in `main.lua`
	isDevelopment = os.getenv("DEV_DIR") ~= nil, -- Development mode flag

	previousScreen = "main_menu", -- Default screen to return to after color picker
	themeApplied = false, -- Whether the theme has been applied
	source = "user", -- Source type for themes (user-created vs built-in)
	systemVersion = "Unknown", -- System version, set in `main.lua`
	activeColorContext = "background", -- Default active color context (background, backgroundGradient, foreground, rgb)

	-- Begin: Theme configuration and defaults
	glyphs_enabled = true, -- Glyphs (icons) enabled
	navigationAlignment = "Left", -- Navigation glyphs and text alignment (Left, Center, Right)
	navigationAlpha = 100, -- Navigation glyphs and textalpha (0-100)
	-- Status alignment (Left, Right, Center, Space Evenly, Equal Distribution, Edge Anchored)
	statusAlignment = "Right",
	boxArtWidth = 0, -- Box art width (content width)
	timeAlignment = "Left", -- Time alignment (Auto, Left, Center, Right)
	headerTextAlignment = 2, -- Header text alignment (0-Auto, 1-Left, 2-Center, 3-Right)
	rgbMode = "Solid", -- RGB lighting mode
	rgbBrightness = 5, -- RGB brightness (1-10)
	rgbSpeed = 5, -- RGB speed (1-10)
	backgroundType = "Solid", -- Background type (Solid or Gradient)
	backgroundGradientDirection = "Vertical", -- Gradient direction
	headerTextEnabled = "Disabled", -- Header text (Enabled/Disabled)
	headerTextAlpha = 255, -- Header text alpha (0-255, 255 = 100%)
	homeScreenLayout = "Grid", -- Home screen layout: "List" or "Grid"
	colorContexts = {
		background = createColorContext("#1E40AF"), -- Default background color
		backgroundGradient = createColorContext("#155CFB"), -- Default background gradient stop color
		foreground = createColorContext("#FFFFFF"), -- Default foreground color
		rgb = createColorContext("#1E40AF"), -- Default RGB lighting color
	},
	-- End: Theme configuration and defaults
}

--- Helper function to get a color context
function state.getColorContext(contextKey)
	if not state.colorContexts[contextKey] then
		local errorMessage = "Color context '" .. contextKey .. "' does not exist. Create it using createColorContext."
		errorHandler.setError(errorMessage)
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
		local errorMessage = "Failed to set color value. Only hex color strings starting with '#' are supported. Got: "
			.. tostring(colorValue)
		errorHandler.setError(errorMessage)
		return
	end
	local context = state.getColorContext(contextKey)
	context.currentColor = colorValue

	-- Initialize the hex input with the new value
	context.hex.input = colorValue:sub(2) -- Remove # sign

	-- Initialize HSV values based on RGB
	local r, g, b = colorUtils.hexToRgb(colorValue)
	local h, s, v = colorUtils.rgbToHsv(r, g, b)
	context.hsv.hue = h * 360 -- Convert 0-1 to 0-360
	context.hsv.sat = s
	context.hsv.val = v

	return colorValue
end

return state
