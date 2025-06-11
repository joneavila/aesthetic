--- Image component for displaying images with rounded corners and outline
local love = require("love")
local colors = require("colors")

local imageComponent = {}

-- Default corner radius and outline color (match gradient_preview.lua)
local DEFAULT_CORNER_RADIUS = 8 -- Matches default button corner radius
local OUTLINE_COLOR = colors.ui.foreground

--- Draws an image with rounded corners and outline
-- @param image The LÖVE image object to draw
-- @param x X position
-- @param y Y position
-- @param width Width to draw
-- @param height Height to draw
-- @param cornerRadius (optional) Corner radius for rounded corners
function imageComponent.draw(image, x, y, width, height, cornerRadius)
	cornerRadius = cornerRadius or DEFAULT_CORNER_RADIUS
	if not image then
		return
	end

	love.graphics.push("all")

	-- Create stencil for rounded corners
	if cornerRadius and cornerRadius > 0 then
		love.graphics.stencil(function()
			love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)
		end, "replace", 1)
		love.graphics.setStencilTest("greater", 0)
	end

	-- Draw the image
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, x, y, 0, width / image:getWidth(), height / image:getHeight())

	if cornerRadius and cornerRadius > 0 then
		love.graphics.setStencilTest()
	end

	-- Draw outline
	love.graphics.setColor(OUTLINE_COLOR)
	if cornerRadius and cornerRadius > 0 then
		love.graphics.rectangle("line", x, y, width, height, cornerRadius, cornerRadius)
	else
		love.graphics.rectangle("line", x, y, width, height)
	end

	love.graphics.pop()
end

return imageComponent
