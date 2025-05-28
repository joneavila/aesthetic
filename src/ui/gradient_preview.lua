--- Gradient preview component for displaying color gradients
local love = require("love")
local colorUtils = require("utils.color")
local imageGenerator = require("utils.image_generator")

local gradientPreview = {}

-- Store the gradient mesh
local gradientMesh = nil

-- Function to update gradient mesh
function gradientPreview.updateMesh(startColor, stopColor, direction)
	local startRgb = colorUtils.hexToLove(startColor)
	local stopRgb = colorUtils.hexToLove(stopColor)
	gradientMesh = imageGenerator.createGradientMesh(direction, startRgb, stopRgb)
	return gradientMesh
end

-- Function to draw gradient preview in a specified area
function gradientPreview.draw(x, y, width, height, startColor, stopColor, direction, cornerRadius)
	-- Create or update mesh if needed
	if not gradientMesh or startColor or stopColor or direction then
		gradientPreview.updateMesh(startColor, stopColor, direction or "Vertical")
	end

	if gradientMesh then
		-- Save current state
		love.graphics.push()

		-- Create stencil function for rounded corners if needed
		if cornerRadius and cornerRadius > 0 then
			love.graphics.stencil(function()
				love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)
			end, "replace", 1)

			-- Use stencil
			love.graphics.setStencilTest("greater", 0)
		end

		-- Draw gradient preview
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(gradientMesh, x, y, 0, width, height)

		-- Reset stencil test and restore state
		if cornerRadius and cornerRadius > 0 then
			love.graphics.setStencilTest()
		end

		love.graphics.pop()

		-- Draw border with corner radius if specified (draw after fill, at same position/size)
		love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
		if cornerRadius and cornerRadius > 0 then
			love.graphics.rectangle("line", x, y, width, height, cornerRadius, cornerRadius)
		else
			love.graphics.rectangle("line", x, y, width, height)
		end
	end
end

-- Create a small square preview
function gradientPreview.drawSquare(x, y, size, startColor, stopColor, direction, cornerRadius)
	gradientPreview.draw(x, y, size, size, startColor, stopColor, direction, cornerRadius)
end

-- Function to get the current mesh
function gradientPreview.getMesh()
	return gradientMesh
end

return gradientPreview
