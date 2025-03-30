--- Global state management module
local love = require("love")

local state = {
	applicationName = "Aesthetic",
	screenWidth = 0,
	screenHeight = 0,
	-- Use default font initially, set in main.lua
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
