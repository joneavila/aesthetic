--- State management module
---
--- This module centralizes all global application state
---
--- Note: When adding new state properties that should persist between sessions, consider updating the `settings.lua`
--- module to include these properties in the configuration file. The settings module handles saving and loading
--- persistent application settings.
local errorHandler = require("error_handler")
local fail = require("utils.fail")

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

--- Default theme configuration values - single source of truth
local themeDefaults = {
	themeName = "Aesthetic",
	fontFamily = "Inter",
	fontSize = "Default",
	homeScreenLayout = "Grid",
	backgroundType = "Gradient",
	backgroundGradientDirection = "Vertical",
	colorContexts = {
		background = "#1E40AF",
		backgroundGradient = "#155CFB",
		foreground = "#FFFFFF",
		rgb = "#1E40AF",
		batteryActive = "#4ADE80",
		batteryLow = "#F87171",
	},
	rgbMode = "Solid",
	rgbBrightness = 5,
	rgbSpeed = 2,
	glyphsEnabled = true,
	headerAlignment = 2,
	headerOpacity = 0,
	boxArtWidth = 0,
	navigationAlignment = "Left",
	navigationOpacity = 100,
	statusAlignment = "Right",
	timeAlignment = "Left",
	datetimeOpacity = 255,
	batteryOpacity = 255,
}

--- Main state table containing all global application state
local state = {
	applicationName = "Aesthetic",
	screenWidth = 0, -- Set in `main.lua`
	screenHeight = 0, -- Set in `main.lua`

	previousScreen = "main_menu", -- Default screen to return to after color picker
	themeApplied = false, -- Whether the theme has been applied
	source = "user", -- Source type for themes (user-created vs built-in)
	systemVersion = "Unknown", -- System version, set in `main.lua`
	activeColorContext = "background", -- Default active color context (background, backgroundGradient, foreground, rgb)

	-- Begin: Theme configuration and defaults
	themeName = themeDefaults.themeName,
	fontFamily = themeDefaults.fontFamily,
	fontSize = themeDefaults.fontSize,
	homeScreenLayout = themeDefaults.homeScreenLayout,
	backgroundType = themeDefaults.backgroundType,
	backgroundGradientDirection = themeDefaults.backgroundGradientDirection,
	colorContexts = {
		background = createColorContext(themeDefaults.colorContexts.background),
		backgroundGradient = createColorContext(themeDefaults.colorContexts.backgroundGradient),
		foreground = createColorContext(themeDefaults.colorContexts.foreground),
		rgb = createColorContext(themeDefaults.colorContexts.rgb),
		batteryActive = createColorContext(themeDefaults.colorContexts.batteryActive),
		batteryLow = createColorContext(themeDefaults.colorContexts.batteryLow),
	},
	rgbMode = themeDefaults.rgbMode,
	rgbBrightness = themeDefaults.rgbBrightness,
	rgbSpeed = themeDefaults.rgbSpeed,
	glyphsEnabled = themeDefaults.glyphsEnabled,
	headerAlignment = themeDefaults.headerAlignment,
	headerOpacity = themeDefaults.headerOpacity,
	boxArtWidth = themeDefaults.boxArtWidth,
	navigationAlignment = themeDefaults.navigationAlignment,
	navigationOpacity = themeDefaults.navigationOpacity,
	statusAlignment = themeDefaults.statusAlignment,
	timeAlignment = themeDefaults.timeAlignment,
	datetimeOpacity = themeDefaults.datetimeOpacity,
	batteryOpacity = themeDefaults.batteryOpacity,
	-- End: Theme configuration and defaults
}

--- Helper function to get a color context
function state.getColorContext(contextKey)
	if not state.colorContexts[contextKey] then
		return fail("Color context '" .. contextKey .. "' does not exist. Create it using createColorContext.")
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
		return fail(
			"Failed to set color value. Only hex color strings starting with '#' are supported. Got: "
				.. tostring(colorValue)
		)
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

--- Reset all theme configuration to default values
function state.resetToDefaults()
	logger.debug("Resetting theme configuration to defaults")

	-- Reset simple values
	state.themeName = themeDefaults.themeName
	state.fontFamily = themeDefaults.fontFamily
	state.fontSize = themeDefaults.fontSize
	state.homeScreenLayout = themeDefaults.homeScreenLayout
	state.backgroundType = themeDefaults.backgroundType
	state.backgroundGradientDirection = themeDefaults.backgroundGradientDirection
	state.rgbMode = themeDefaults.rgbMode
	state.rgbBrightness = themeDefaults.rgbBrightness
	state.rgbSpeed = themeDefaults.rgbSpeed
	state.glyphsEnabled = themeDefaults.glyphsEnabled
	state.headerAlignment = themeDefaults.headerAlignment
	state.headerOpacity = themeDefaults.headerOpacity
	state.boxArtWidth = themeDefaults.boxArtWidth
	state.navigationAlignment = themeDefaults.navigationAlignment
	state.navigationOpacity = themeDefaults.navigationOpacity
	state.statusAlignment = themeDefaults.statusAlignment
	state.timeAlignment = themeDefaults.timeAlignment
	state.datetimeOpacity = themeDefaults.datetimeOpacity
	state.batteryOpacity = themeDefaults.batteryOpacity

	-- Reset color contexts
	for contextKey, defaultColor in pairs(themeDefaults.colorContexts) do
		state.setColorValue(contextKey, defaultColor)
	end

	-- Apply RGB settings immediately if RGB is supported
	if state.hasRGBSupport then
		local rgb = require("utils.rgb")
		rgb.updateConfig()
		logger.debug("Applied RGB settings after reset to defaults")
	end
end

return state
