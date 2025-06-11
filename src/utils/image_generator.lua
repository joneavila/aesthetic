--- Image generation utilities
--
-- This module handles image generation using LÖVE and TOVE for SVG rendering
--
-- Note on Canvas alpha blending:
-- When drawing content to a Canvas using regular alpha blending in LÖVE,
-- the alpha values get multiplied with RGB values, resulting in premultiplied alpha.
-- See: https://www.love2d.org/wiki/Canvas
--
-- To ensure proper color rendering:
-- 1. Use "alpha" blend mode when drawing TO the canvas
-- 2. Use "alpha", "premultiplied" when displaying the canvas elsewhere
-- 3. Restore original blend mode when finished
--
-- This approach fixes issues where SVG icons appear darker than text when rendered.
local love = require("love")

local state = require("state")

local fonts = require("ui.fonts")

local colorUtils = require("utils.color")
local logger = require("utils.logger")
local svg = require("utils.svg")
local system = require("utils.system")
local fail = require("utils.fail")

local imageGenerator = {}

-- Create a canvas with background color
function imageGenerator.createCanvas(width, height, bgColor)
	local canvas = love.graphics.newCanvas(width, height)
	local previousCanvas = love.graphics.getCanvas()

	-- Switch to our new canvas for drawing
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)

	return canvas, previousCanvas
end

-- Finish drawing on canvas and restore previous canvas
function imageGenerator.finishCanvas(previousCanvas)
	-- Restore the previous canvas (important for proper rendering pipeline)
	love.graphics.setCanvas(previousCanvas)
end

-- Create an image with centered svg icon and optional text
function imageGenerator.createIconImage(options)
	local width = options.width or state.screenWidth
	local height = options.height or state.screenHeight
	local bgColor = options.bgColor or colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = options.fgColor or colorUtils.hexToLove(state.getColorValue("foreground"))
	local iconPath = options.iconPath
	local iconSize = options.iconSize or 100
	local backgroundLogoPath = options.backgroundLogoPath
	local backgroundLogoSize = options.backgroundLogoSize or 180
	local text = options.text
	local outputPath = options.outputPath

	if not system.ensurePath(outputPath) then
		return fail("Failed to ensure output path: " .. tostring(outputPath))
	end

	local svgContent
	if iconPath then
		svgContent = system.readFile(iconPath)
		if not svgContent then
			return fail("Failed to read SVG file: " .. iconPath)
		end
	end

	local backgroundSvgContent
	if backgroundLogoPath then
		backgroundSvgContent = system.readFile(backgroundLogoPath)
		if not backgroundSvgContent then
			return fail("Failed to read background SVG file: " .. backgroundLogoPath)
		end
	end

	local canvas, previousCanvas = imageGenerator.createCanvas(width, height, { 0, 0, 0, 0 })
	local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()
	love.graphics.push("all")

	-- Apply background based on background type
	if state.backgroundType == "Gradient" then
		-- Create gradient using our existing function
		local gradientDirection = state.backgroundGradientDirection or "Vertical"
		local gradientColor = colorUtils.hexToLove(state.getColorValue("backgroundGradient"))

		-- Create gradient mesh with background color and gradient color
		local gradientMesh = imageGenerator.createGradientMesh(gradientDirection, bgColor, gradientColor)

		-- Draw gradient filling the entire canvas
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(gradientMesh, 0, 0, 0, width, height)
	else
		-- Solid background
		love.graphics.setColor(bgColor)
		love.graphics.rectangle("fill", 0, 0, width, height)
	end

	-- Draw background logo if provided
	local iconX = width / 2
	local iconY = height / 2 - (text and 50 or 0)

	if backgroundSvgContent then
		svg.drawIconOnCanvas(backgroundSvgContent, backgroundLogoSize, iconX, iconY, fgColor, true)
	end

	-- Draw foreground icon
	if svgContent then
		svg.drawIconOnCanvas(svgContent, iconSize, iconX, iconY, fgColor, true)
	end

	-- Draw text if provided
	if text then
		-- Set proper blend mode for text drawing
		-- Text needs "alpha" blend mode when drawing to canvas
		love.graphics.setBlendMode("alpha")

		-- Create a larger version of the font
		local imageFontSize = 28
		local fontKey = fonts.nameToKey[state.fontFamily]
		if not fontKey then
			logger.debug("state.fontFamily: " .. state.fontFamily)
			return fail("Font mapping not found or initialized")
		end
		local fontDef = fonts.themeDefinitions[fontKey]
		if not fontDef then
			return fail("Font definition not found")
		end
		local largerFont = love.graphics.newFont(fontDef.ttf, imageFontSize)

		-- Set the font and color
		love.graphics.setFont(largerFont)
		love.graphics.setColor(fgColor)

		-- Draw the text centered
		local textWidth = largerFont:getWidth(text)
		local textX = (width - textWidth) / 2
		local textY = height / 2 + 64
		love.graphics.print(text, textX, textY)
	end

	love.graphics.pop()

	-- Restore original blend mode
	-- This ensures that any subsequent rendering uses the correct blend mode
	love.graphics.setBlendMode(prevBlendMode, prevAlphaMode)

	-- Finish canvas operations
	imageGenerator.finishCanvas(previousCanvas)

	-- Get image data
	local imageData = canvas:newImageData()

	-- Save file (always as PNG)
	local pngData = imageData:encode("png")
	if not pngData then
		return fail("Failed to encode PNG")
	end

	if not system.writeFile(outputPath, pngData:getString()) then
		return fail("Failed to write PNG")
	end

	return true, imageData
end

-- Create a gradient mesh usable for various UI elements
function imageGenerator.createGradientMesh(direction, ...)
	-- Check for direction
	local isHorizontal = true
	if direction == "Vertical" then
		isHorizontal = false
	elseif direction ~= "Horizontal" then
		error("bad argument #1 to 'createGradientMesh' (invalid value)", 2)
	end

	-- Check for colors
	local colorLen = select("#", ...)
	if colorLen < 2 then
		error("color list is less than two", 2)
	end

	-- Generate mesh
	local meshData = {}
	if isHorizontal then
		for i = 1, colorLen do
			local color = select(i, ...)
			local x = (i - 1) / (colorLen - 1)

			meshData[#meshData + 1] = { x, 1, x, 1, color[1], color[2], color[3], color[4] or 1 }
			meshData[#meshData + 1] = { x, 0, x, 0, color[1], color[2], color[3], color[4] or 1 }
		end
	else
		for i = 1, colorLen do
			local color = select(i, ...)
			local y = (i - 1) / (colorLen - 1)

			meshData[#meshData + 1] = { 1, y, 1, y, color[1], color[2], color[3], color[4] or 1 }
			meshData[#meshData + 1] = { 0, y, 0, y, color[1], color[2], color[3], color[4] or 1 }
		end
	end

	-- Resulting Mesh has 1x1 image size
	return love.graphics.newMesh(meshData, "strip", "static")
end

-- Create a preview image for muOS theme selection
function imageGenerator.createPreviewImage(outputPath)
	-- See: https://muos.dev/themes/zipping.html#creating-a-preview-image
	local previewImageWidth = 288
	local previewImageHeight = 216

	-- Get colors from state
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	-- Create canvas
	local canvas, previousCanvas = imageGenerator.createCanvas(previewImageWidth, previewImageHeight)

	-- Save current blend mode and graphics state to restore later
	local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()

	-- Clear canvas with transparent color (we'll draw background after)
	love.graphics.clear(0, 0, 0, 0)

	love.graphics.push("all")

	-- Apply background based on background type
	if state.backgroundType == "Gradient" then
		-- Create gradient using gradientMesh function
		local gradientDirection = state.backgroundGradientDirection or "Vertical"
		local gradientColor = colorUtils.hexToLove(state.getColorValue("backgroundGradient"))

		-- Create gradient mesh with background color and gradient color
		local gradientMesh = imageGenerator.createGradientMesh(gradientDirection, bgColor, gradientColor)

		-- Set proper blend mode and color for gradient rendering
		love.graphics.setBlendMode("alpha")
		love.graphics.setColor(1, 1, 1, 1)

		-- Draw gradient filling the entire canvas
		love.graphics.draw(gradientMesh, 0, 0, 0, previewImageWidth, previewImageHeight)
	else
		-- Solid background
		love.graphics.setColor(bgColor)
		love.graphics.rectangle("fill", 0, 0, previewImageWidth, previewImageHeight)
	end

	-- Set font and draw text
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(fgColor)
	local fontFamilyName = state.fontFamily

	local font = fonts.getByName(fontFamilyName)
	love.graphics.setFont(font)

	-- Center text
	local previewImageText = "muOS"
	local textWidth, textHeight = font:getWidth(previewImageText), font:getHeight()
	local textX = (previewImageWidth - textWidth) / 2
	local textY = (previewImageHeight - textHeight) / 2
	love.graphics.print(previewImageText, textX, textY)

	love.graphics.pop()

	-- Restore original blend mode
	love.graphics.setBlendMode(prevBlendMode, prevAlphaMode)

	-- Finish canvas operations
	imageGenerator.finishCanvas(previousCanvas)

	-- Get image data and encode as PNG
	local imageData = canvas:newImageData()
	local pngData = imageData:encode("png")
	if not pngData then
		return fail("Failed to encode preview image to PNG")
	end

	-- Save to file
	return system.writeFile(outputPath, pngData:getString())
end

return imageGenerator
