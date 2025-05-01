--- State management module
---
--- This module centralizes all global application state

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

local function createColorContext(defaultColor)
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

	-- Screen dimensions are set in `src/main.lua`
	screenWidth = 0,
	screenHeight = 0,

	-- Font settings (moved to ui.fonts but kept references here for compatibility)
	fonts = fonts.loaded,
	selectedFont = fonts.defaultFont,
	fontSize = fonts.defaultFontSize,

	previousScreen = "main_menu", -- Default screen to return to after color picker
	glyphs_enabled = true, -- Default value for glyphs enabled

	-- Set the alignment of the theme's bottom navigation icons and text
	navigationAlignment = "Left", -- Default navigation alignment (Left, Center, Right)

	-- Box art settings
	boxArtWidth = 0, -- Default box art width (0 means disabled)

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
}

--- Helper function to get a color context
function state.getColorContext(contextKey)
	if not state.colorContexts[contextKey] then
		error("Color context '" .. contextKey .. "' does not exist. Create it first using createColorContext.")
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
		errorHandler.setError(
			"Failed to set color value: only hex color strings (starting with #) are supported. Got: "
				.. tostring(colorValue)
		)
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

--- Helper function to initialize font name to key mapping (delegated to fonts)
function state.initFontNameMapping()
	fonts.initNameMapping()
end

--- Helper function to set the default font (delegated to fonts)
function state.setDefaultFont()
	fonts.setDefault()
end

return state
