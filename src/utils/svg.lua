--- SVG rendering utility functions
--
-- This module handles SVG rendering using LÖVE and TOVE with proper blend mode handling
--
-- Note on SVG rendering and blend modes:
-- When drawing SVG content to a Canvas using TOVE in LÖVE, we need to handle blend modes carefully:
-- 1. Use "alpha" blend mode when drawing SVG icons to ensure correct color values
-- 2. Use "alpha", "premultiplied" blend mode when displaying the canvas elsewhere
-- 3. Ensure full opacity (1.0) when drawing SVG icons
-- 4. Restore original blend mode when finished
--
-- This approach fixes issues where SVG icons appear darker than text when rendered with the same color.
-- See also: https://www.love2d.org/wiki/Canvas for information on Canvas alpha blending

local love = require("love")
local tove = require("tove")
local errorHandler = require("error_handler")

local svg = {}

-- Icon cache to prevent reloading SVGs
local iconCache = {}

-- Load an SVG icon from file
function svg.loadIcon(name, size, basePath)
	-- Default to UI icons path if not specified
	basePath = basePath or "assets/icons/lucide/ui/"
	size = size or 24

	local cacheKey = basePath .. name .. "_" .. size

	if not iconCache[cacheKey] then
		local svgPath = basePath .. name .. ".svg"
		local svgContent = love.filesystem.read(svgPath)
		if svgContent then
			iconCache[cacheKey] = tove.newGraphics(svgContent, size)
		else
			if errorHandler then
				errorHandler.setError("Failed to load SVG icon: " .. svgPath)
			else
				error("Failed to load SVG icon: " .. svgPath)
			end
			return nil
		end
	end

	return iconCache[cacheKey]
end

-- Draw SVG icon with proper blend mode handling
function svg.drawIcon(icon, x, y, color, opacity)
	-- Save current graphics state
	local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()
	local prevR, prevG, prevB, prevA = love.graphics.getColor()

	-- Set color through monochrome if provided
	if color then
		icon:setMonochrome(color[1], color[2], color[3])
	end

	-- Set alpha blend mode for SVG drawing
	love.graphics.setBlendMode("alpha")

	-- Draw with full opacity (or specified opacity)
	opacity = opacity or 1.0
	love.graphics.setColor(1, 1, 1, opacity)

	-- Draw the icon at the specified position
	icon:draw(x, y)

	-- Restore original graphics state
	love.graphics.setBlendMode(prevBlendMode, prevAlphaMode)
	love.graphics.setColor(prevR, prevG, prevB, prevA)

	return icon
end

-- Draw SVG icon on a canvas with option to control blend mode restoration
function svg.drawIconOnCanvas(svg, size, x, y, color, restoreBlendMode)
	-- Set proper blend mode for drawing to canvas
	love.graphics.setBlendMode("alpha")

	local icon = tove.newGraphics(svg, size)
	if color then
		icon:setMonochrome(color[1], color[2], color[3])
	end

	-- Ensure full opacity when drawing SVG
	local r, g, b, _ = love.graphics.getColor()
	love.graphics.setColor(r, g, b, 1.0)

	icon:draw(x, y)

	-- Restore blend mode to premultiplied alpha for canvas rendering if requested
	if restoreBlendMode then
		love.graphics.setBlendMode("alpha", "premultiplied")
	end

	return icon
end

-- Draw SVG icon by name directly from the asset path
function svg.drawNamedIcon(name, x, y, color, size, opacity)
	local icon = svg.loadIcon(name, size)
	if icon then
		svg.drawIcon(icon, x, y, color, opacity)
	end
	return icon
end

-- Preload commonly used icons to prevent loading delays
function svg.preloadIcons(iconNames, size, basePath)
	for _, name in ipairs(iconNames) do
		svg.loadIcon(name, size, basePath)
	end
end

return svg
