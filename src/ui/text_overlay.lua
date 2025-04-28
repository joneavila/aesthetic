--- Text overlay component
--- This file provides functions for drawing text overlays such as "Working..."

local love = require("love")
local colors = require("colors")

-- Module table to export public functions
local textOverlay = {}

-- Function to display a full-screen text overlay with semi-transparent background
function textOverlay.draw(params)
	local text = params.text or "Working..."
	local bgColor = params.bgColor or colors.ui.background
	local textColor = params.textColor or colors.ui.foreground
	local opacity = params.opacity or 0.95
	local screenWidth = params.screenWidth or love.graphics.getWidth()
	local screenHeight = params.screenHeight or love.graphics.getHeight()
	local font = params.font or love.graphics.getFont()

	-- Semi-transparent background
	love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], opacity)
	love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

	-- Text
	love.graphics.setColor(textColor)
	local textWidth = font:getWidth(text)
	local textHeight = font:getHeight()

	-- Center the text on screen
	local x = (screenWidth - textWidth) / 2
	local y = (screenHeight - textHeight) / 2

	love.graphics.print(text, x, y)
end

return textOverlay
