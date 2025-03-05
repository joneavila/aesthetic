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
		background = "red700", -- Default background color
		foreground = "white", -- Default foreground color (currently unused)
	},
}

return state
