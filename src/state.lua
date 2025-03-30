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
	colors = {
		background = "#1E1E2E", -- Default background color
		foreground = "#CDD6F4", -- Default foreground color
	},
	selectedFont = "Inter", -- Default selected font
	lastSelectedColorButton = "background", -- Default selected button for color picker
	glyphs_enabled = true, -- Default value for glyphs enabled
}

return state
