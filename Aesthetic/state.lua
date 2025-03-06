--- Global state management module
local love = require("love")
local state = {
	applicationName = "Aesthetic",
	screenWidth = 0, -- Set in main.lua
	screenHeight = 0, -- Set in main.lua
	-- Use default font initially, set in main.lua
	fonts = {
		header = love.graphics.getFont(),
		body = love.graphics.getFont(),
		caption = love.graphics.getFont(),
	},
	colors = {
		background = "red600", -- Default background color
		foreground = "white", -- Default foreground color
	},
	selectedFont = "Inter", -- Default selected font
	lastSelectedColorButton = "background", -- Default selected button for color picker
}

return state
