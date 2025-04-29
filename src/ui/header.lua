--- Header UI component
-- This module provides a consistent header for screens

local love = require("love")
local colors = require("colors")
local fonts = require("ui.fonts")

local header = {}

-- Constants for styling
-- @field HORIZONTAL_PADDING The padding from the left edge of the screen to the title text (in pixels)
-- @field VERTICAL_PADDING The padding above and below the title text (in pixels)
header.HORIZONTAL_PADDING = 18
header.VERTICAL_PADDING = 10
header.BOTTOM_MARGIN = 14

-- Calculate the total header height based on font height plus vertical padding
-- @return number The total height of the header in pixels
function header.getHeight()
	return fonts.loaded.header:getHeight() + (header.VERTICAL_PADDING * 2) + header.BOTTOM_MARGIN
end

-- Draw a standard header with title
-- @param title The title text to display in the header
function header.draw(title)
	-- Draw background
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), header.getHeight() - header.BOTTOM_MARGIN)

	-- Draw header title
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.setFont(fonts.loaded.header)
	love.graphics.print(title, header.HORIZONTAL_PADDING, header.VERTICAL_PADDING)
end

return header
