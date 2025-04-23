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

return background
