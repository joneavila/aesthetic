--- Global state management module
local love = require("love")

-- TODO: Ensure state variables are not added outside of this file

local state = {
	applicationName = "Aesthetic",

	-- Screen dimensions are set using `love.graphics.getDimensions()`
	-- Alternatively, use the muOS GET_VAR function (load the file containing the GET_VAR function first)
	-- 		$(GET_VAR device mux/width)
	-- 		$(GET_VAR device mux/height)
	screenWidth = 0,
	screenHeight = 0,

	fonts = {
		header = love.graphics.getFont(),
		body = love.graphics.getFont(),
		caption = love.graphics.getFont(),
	},
	selectedFont = "Inter", -- Default selected font
	lastSelectedColorButton = "background", -- Default selected button for color picker
	glyphs_enabled = true, -- Default value for glyphs enabled

	-- Centralized color contexts storage
	colorContexts = {},
}

-- Color defaults to initialize contexts with
local colorDefaults = {
	background = "#1E1E2E", -- Default background color
	foreground = "#CDD6F4", -- Default foreground color
}

-- Helper function to get or create a color context
-- This enables scalable state management for multiple color buttons
function state.getColorContext(contextKey)
	if not state.colorContexts[contextKey] then
		-- Initialize a new context with default values
		state.colorContexts[contextKey] = {
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
			-- Palette state
			palette = {
				selectedRow = 0,
				selectedCol = 0,
				scrollY = 0,
			},
			-- The current hex color value
			currentColor = colorDefaults[contextKey] or "#000000", -- Default to known default or black
		}
	end
	return state.colorContexts[contextKey]
end

-- Helper function to get the current color value for a context
function state.getColorValue(contextKey)
	local context = state.getColorContext(contextKey)
	return context.currentColor
end

-- Helper function to set the current color value for a context
function state.setColorValue(contextKey, colorValue)
	local context = state.getColorContext(contextKey)
	context.currentColor = colorValue
	return colorValue
end

-- Initialize default contexts
state.getColorContext("background")
state.getColorContext("foreground")

return state
