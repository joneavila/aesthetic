--- Background UI component
-- This module provides consistent background rendering for screens

local love = require("love")
local colors = require("colors")
local state = require("state")

local background = {}

-- Draw a standard background for screens
function background.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)
end

-- Draw a solid colored background with specified color
function background.drawWithColor(color)
	love.graphics.setColor(color)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)
end

return background
