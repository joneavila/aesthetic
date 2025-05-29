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
local colorUtils = require("utils.color")
local errorHandler = require("error_handler")
local bmp = require("utils.bmp")
local system = require("utils.system")
local paths = require("paths")
local fonts = require("ui.fonts")
local svg = require("utils.svg")
local logger = require("utils.logger")

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
	local saveAsBmp = options.saveAsBmp or false

	-- Ensure output path parent directory exists
	if not system.ensurePath(outputPath) then
		return false
	end

	-- Load icon SVG
	local svgContent = system.readFile(iconPath)
	if not svgContent then
		errorHandler.setError("Failed to read SVG file: " .. iconPath)
		return false
	end

	-- Load background logo SVG if provided
	local backgroundSvgContent
	if backgroundLogoPath then
		backgroundSvgContent = system.readFile(backgroundLogoPath)
		if not backgroundSvgContent then
			return false
		end
	end

	-- Create canvas with base background color
	local canvas, previousCanvas
	if saveAsBmp then
		canvas, previousCanvas = imageGenerator.createCanvas(width, height, bgColor)
	else
		canvas, previousCanvas = imageGenerator.createCanvas(width, height, { 0, 0, 0, 0 })
	end

	-- Save current blend mode to restore later
	-- This is crucial for proper alpha blending when drawing to canvas
	-- See: https://www.love2d.org/wiki/Canvas#Notes
	local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()

	love.graphics.push()

	if saveAsBmp then
		-- For BMP, draw background
		if state.backgroundType == "Gradient" then
			local gradientDirection = state.backgroundGradientDirection or "Vertical"
			local gradientColor = colorUtils.hexToLove(state.getColorValue("backgroundGradient"))
			local gradientMesh = imageGenerator.createGradientMesh(gradientDirection, bgColor, gradientColor)
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.draw(gradientMesh, 0, 0, 0, width, height)
		else
			love.graphics.setColor(bgColor)
			love.graphics.rectangle("fill", 0, 0, width, height)
		end
	end

	-- Draw background logo if provided
	local iconX = width / 2
	local iconY = height / 2 - (text and 50 or 0)

	if backgroundSvgContent then
		if saveAsBmp then
			local r, g, b = fgColor[1], fgColor[2], fgColor[3]
			svg.drawIconOnCanvas(backgroundSvgContent, backgroundLogoSize, iconX, iconY, { r, g, b }, false)
		else
			svg.drawIconOnCanvas(backgroundSvgContent, backgroundLogoSize, iconX, iconY, fgColor, true)
		end
	end

	-- Draw foreground icon
	if svgContent then
		if saveAsBmp then
			-- For BMP, draw background at full opacity
			local r, g, b = fgColor[1], fgColor[2], fgColor[3]
			svg.drawIconOnCanvas(svgContent, iconSize, iconX, iconY, { r, g, b }, false)
		else
			svg.drawIconOnCanvas(svgContent, iconSize, iconX, iconY, fgColor, true)
		end
	end

	-- Draw text if provided
	if text then
		love.graphics.setBlendMode("alpha")
		local imageFontSize = 28
		local fontKey = fonts.nameToKey[fonts.getSelectedFont()]
		if not fontKey then
			errorHandler.setError("Font mapping not found or initialized")
			return false
		end
		local fontDef = fonts.uiDefinitions[fontKey]
		local largerFont = love.graphics.newFont(fontDef.path, imageFontSize)
		love.graphics.setFont(largerFont)
		if saveAsBmp then
			love.graphics.setColor(fgColor[1], fgColor[2], fgColor[3], 1.0)
		else
			love.graphics.setColor(fgColor)
		end
		local textWidth = largerFont:getWidth(text)
		local textX = (width - textWidth) / 2
		local textY = height / 2 + 64
		love.graphics.print(text, textX, textY)
	end

	love.graphics.pop()

	-- Restore original blend mode
	-- This ensures that any subsequent rendering uses the correct blend mode
	love.graphics.setBlendMode(prevBlendMode, prevAlphaMode)

	imageGenerator.finishCanvas(previousCanvas)

	local imageData = canvas:newImageData()

	-- Save file
	if saveAsBmp then
		if not bmp.saveToFile(imageData, outputPath) then
			return false
		end
	else
		local pngData = imageData:encode("png")
		if not pngData then
			errorHandler.setError("Failed to encode PNG")
			return false
		end
		if not system.writeFile(outputPath, pngData:getString()) then
			errorHandler.setError("Failed to write PNG")
			return false
		end
	end

	return imageData
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
	-- Set the preview image dimensions based on the screen resolution
	local screenWidth, screenHeight = state.screenWidth, state.screenHeight

	-- Log dimensions for debugging
	logger.debug("Creating preview image with dimensions: " .. screenWidth .. "x" .. screenHeight)

	-- See: https://muos.dev/themes/zipping.html#creating-a-preview-image
	local previewImageWidth = 288
	local previewImageHeight = 216

	-- Get colors from state
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	-- Create canvas
	local canvas, previousCanvas = imageGenerator.createCanvas(previewImageWidth, previewImageHeight)

	-- Clear canvas with transparent color (we'll draw background after)
	love.graphics.clear(0, 0, 0, 0)

	-- Apply background based on background type
	if state.backgroundType == "Gradient" then
		-- Create gradient using gradientMesh function
		local gradientDirection = state.backgroundGradientDirection or "Vertical"
		local gradientColor = colorUtils.hexToLove(state.getColorValue("backgroundGradient"))

		-- Create gradient mesh with background color and gradient color
		local rainbow = imageGenerator.createGradientMesh(gradientDirection, bgColor, gradientColor)

		-- Draw gradient filling the entire canvas
		love.graphics.draw(rainbow, 0, 0, 0, previewImageWidth, previewImageHeight)
	else
		-- Solid background
		love.graphics.setColor(bgColor)
		love.graphics.rectangle("fill", 0, 0, previewImageWidth, previewImageHeight)
	end

	-- Set font and draw text
	love.graphics.setColor(fgColor)
	local selectedFontName = fonts.getSelectedFont()

	local font = fonts.getByName(selectedFontName)
	love.graphics.setFont(font)

	-- Center text
	local previewImageText = "muOS"
	local textWidth, textHeight = font:getWidth(previewImageText), font:getHeight()
	local textX = (previewImageWidth - textWidth) / 2
	local textY = (previewImageHeight - textHeight) / 2
	love.graphics.print(previewImageText, textX, textY)

	-- Finish canvas operations
	imageGenerator.finishCanvas(previousCanvas)

	-- Get image data and encode as PNG
	local imageData = canvas:newImageData()
	local pngData = imageData:encode("png")
	if not pngData then
		errorHandler.setError("Failed to encode preview image to PNG")
		return false
	end

	-- Save to file
	return system.writeFile(outputPath, pngData:getString())
end

return imageGenerator
