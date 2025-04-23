--- Header UI component
-- This module provides a consistent header for screens

local love = require("love")
local colors = require("colors")
local state = require("state")

local header = {}

-- Constants for styling
header.HEIGHT = 50
header.PADDING = 20

-- Draw a standard header with title
-- @param title The title text to display in the header
-- @param alpha Optional alpha transparency value (0.0-1.0), defaults to 0.95
function header.draw(title, alpha)
	-- Default alpha value if not provided
	alpha = alpha or 1.0

	-- Draw header background
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], alpha)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, header.HEIGHT)

	-- Draw header title
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(state.fonts.bodyBold)
	love.graphics.print(title, header.PADDING, (header.HEIGHT - state.fonts.bodyBold:getHeight()) / 2)
end

return header
