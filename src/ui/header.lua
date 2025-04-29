--- Header UI component
-- This module provides a consistent header for screens

local love = require("love")
local colors = require("colors")
local fonts = require("ui.fonts")

local header = {}

-- Constants for styling
-- @field HORIZONTAL_PADDING The padding from the left edge of the screen to the title text (in pixels)
-- @field VERTICAL_PADDING The padding above and below the title text (in pixels)
header.HORIZONTAL_PADDING = 20
header.VERTICAL_PADDING = 12

-- Calculate the total header height based on font height plus vertical padding
-- @return number The total height of the header in pixels
function header.getHeight()
	return fonts.loaded.bodyBold:getHeight() + (header.VERTICAL_PADDING * 2)
end

-- Draw a standard header with title
-- @param title The title text to display in the header
function header.draw(title)
	-- Draw header title
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(fonts.loaded.bodyBold)
	love.graphics.print(title, header.HORIZONTAL_PADDING, header.VERTICAL_PADDING)
end

return header
