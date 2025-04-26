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
local love = require("love")
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

	fonts = {},

	-- Font definitions mapping
	fontDefs = {
		header = { name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 32 },
		body = { name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 24 },
		bodyBold = { name = "Inter", path = "assets/fonts/inter/inter_24pt_extrabold.ttf", size = 24 },
		caption = { name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 20 },
		monoTitle = { name = "JetBrains Mono", path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", size = 48 },
		monoHeader = {
			name = "JetBrains Mono",
			path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
			size = 32,
		},
		monoBody = { name = "JetBrains Mono", path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", size = 24 },
		nunito = { name = "Nunito", path = "assets/fonts/nunito/nunito_bold.ttf", size = 24 },
		retroPixel = { name = "Retro Pixel", path = "assets/fonts/retro_pixel/retro_pixel_thick.ttf", size = 24 },
	},

	-- Font name to font key mapping for easy lookup
	fontNameToKey = {},

	selectedFont = "Inter", -- Default selected font
	fontSize = "Default", -- Default font size
	previousScreen = "menu", -- Default screen to return to after color picker
	glyphs_enabled = true, -- Default value for glyphs enabled

	-- Box art settings
	boxArtWidth = "Disabled", -- Default box art width

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
	local context = state.getColorContext(contextKey)
	context.currentColor = colorValue

	-- Initialize the hex input with the new value
	context.hex.input = colorValue:sub(2) -- Remove # sign

	-- Initialize HSV values based on RGB
	local colorUtils = require("utils.color")
	local r, g, b = colorUtils.hexToRgb(colorValue)
	local h, s, v = colorUtils.rgbToHsv(r, g, b)
	context.hsv.hue = h * 360 -- Convert 0-1 to 0-360
	context.hsv.sat = s
	context.hsv.val = v

	return colorValue
end

--- Helper function to get a font by name
function state.getFontByName(fontName)
	local fontKey = state.fontNameToKey[fontName]
	if fontKey then
		return state.fonts[fontKey]
	end
	return state.fonts.body -- Return default font if not found
end

--- Helper function to initialize font name to key mapping
function state.initFontNameMapping()
	state.fontNameToKey = {}
	for key, def in pairs(state.fontDefs) do
		state.fontNameToKey[def.name] = key
	end
end

--- Helper function to set the default font
function state.setDefaultFont()
	if love and state.fonts.body then
		love.graphics.setFont(state.fonts.body)
	end
end

return state
