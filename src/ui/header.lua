--- Header UI component
-- This module provides a consistent header for screens

local love = require("love")
local colors = require("colors")
local fonts = require("ui.fonts")

local header = {}

-- Constants for styling
header.HEIGHT = 50
header.PADDING = 20

-- Draw a standard header with title
-- @param title The title text to display in the header
function header.draw(title)
	-- Draw header title
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(fonts.loaded.bodyBold)
	love.graphics.print(title, header.PADDING, (header.HEIGHT - fonts.loaded.bodyBold:getHeight()) / 2)
end

return header
