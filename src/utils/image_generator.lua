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
local tove = require("tove")
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
	local text = options.text
	local outputPath = options.outputPath
	local saveAsBmp = options.saveAsBmp or false

	-- Ensure output path parent directory exists
	if not system.ensurePath(outputPath) then
		return false
	end

	-- Load icon SVG
	local svgContent
	if iconPath then
		svgContent = system.readFile(iconPath)
		if not svgContent then
			errorHandler.setError("Failed to read SVG file: " .. iconPath)
			return false
		end
	end

	-- Create canvas
	local canvas, previousCanvas = imageGenerator.createCanvas(width, height, bgColor)

	-- Save current blend mode to restore later
	-- This is crucial for proper alpha blending when drawing to canvas
	-- See: https://www.love2d.org/wiki/Canvas#Notes
	local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()

	love.graphics.push()

	-- Special handling for boot image (BMP format)
	if saveAsBmp then
		-- For BMP images, use "alpha" blend mode but ensure full opacity
		love.graphics.setBlendMode("alpha")
		love.graphics.setColor(1, 1, 1, 1)
	end

	-- Draw icon
	-- SVG icons need careful blend mode handling to render with correct colors
	local iconX = width / 2
	local iconY = height / 2 - (text and 50 or 0)

	-- Set color for SVG with maximum opacity for BMP format
	if svgContent then
		if saveAsBmp then
			-- For BMP format, we need to ensure full opacity
			local r, g, b = fgColor[1], fgColor[2], fgColor[3]
			svg.drawIconOnCanvas(svgContent, iconSize, iconX, iconY, { r, g, b }, false)
		else
			svg.drawIconOnCanvas(svgContent, iconSize, iconX, iconY, fgColor, true)
		end
	end

	-- Draw text if provided
	if text then
		-- Set proper blend mode for text drawing
		-- Text needs "alpha" blend mode when drawing to canvas
		love.graphics.setBlendMode("alpha")

		-- Create a larger version of the font
		local imageFontSize = paths.getImageFontSize(height)
		local fontSize = math.floor(imageFontSize * 1.3)
		local fontKey = fonts.nameToKey[state.selectedFont]
		if not fontKey then
			errorHandler.setError("Font mapping not found or initialized")
			return false
		end
		local fontDef = fonts.definitions[fontKey]
		local largerFont = love.graphics.newFont(fontDef.path, fontSize)

		-- Set the font and color
		love.graphics.setFont(largerFont)

		-- For BMP images, ensure full opacity
		if saveAsBmp then
			love.graphics.setColor(fgColor[1], fgColor[2], fgColor[3], 1.0)
		else
			love.graphics.setColor(fgColor)
		end

		-- Draw the text centered
		local textWidth = largerFont:getWidth(text)
		local textX = (width - textWidth) / 2
		local textY = height / 2 + 30
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

		if not system.writeBinaryFile(outputPath, pngData:getString()) then
			errorHandler.setError("Failed to write PNG")
			return false
		end
	end

	return imageData
end

-- Create a preview image for muOS theme selection
function imageGenerator.createPreviewImage(outputPath, previewFonts)
	-- Set the preview image dimensions based on the screen resolution
	local screenWidth, screenHeight = state.screenWidth, state.screenHeight

	-- Log dimensions for debugging
	logger.debug("Creating preview image with dimensions: " .. screenWidth .. "x" .. screenHeight)

	-- Define preview dimensions based on screen resolution
	-- Default to the 640x480 ratio if no match is found
	local previewImageWidth, previewImageHeight
	if screenWidth == 640 and screenHeight == 480 then
		previewImageWidth, previewImageHeight = 288, 216
	elseif screenWidth == 720 and screenHeight == 480 then
		previewImageWidth, previewImageHeight = 340, 227
	elseif screenWidth == 720 and screenHeight == 756 then
		previewImageWidth, previewImageHeight = 340, 272
	elseif screenWidth == 720 and screenHeight == 720 then
		previewImageWidth, previewImageHeight = 340, 340
	elseif screenWidth == 1024 and screenHeight == 768 then
		previewImageWidth, previewImageHeight = 484, 363
	elseif screenWidth == 1280 and screenHeight == 720 then
		previewImageWidth, previewImageHeight = 604, 340
	else
		previewImageWidth, previewImageHeight = 288, 216
	end

	-- Get colors from state
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	-- Create canvas
	local canvas, previousCanvas = imageGenerator.createCanvas(previewImageWidth, previewImageHeight, bgColor)

	-- Save current blend mode
	-- Important for proper alpha blending with LÖVE canvas rendering
	-- See: https://www.love2d.org/wiki/Canvas
	local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()

	-- Set proper blend mode for text drawing
	-- Using "alpha" blend mode when drawing TO the canvas
	love.graphics.setBlendMode("alpha")

	-- Set font and draw text
	love.graphics.setColor(fgColor)
	local selectedFontName = state.selectedFont
	local fontMap = {
		["Inter"] = previewFonts and previewFonts.body or state.fonts.body,
		["Cascadia Code"] = previewFonts and previewFonts.monoBody or state.fonts.monoBody,
		["Retro Pixel"] = previewFonts and previewFonts.retroPixel or state.fonts.retroPixel,
	}
	local font = fontMap[selectedFontName] or (previewFonts and previewFonts.nunito or state.fonts.nunito)
	love.graphics.setFont(font)

	-- Center text
	local previewImageText = "muOS"
	local textWidth, textHeight = font:getWidth(previewImageText), font:getHeight()
	local textX = (previewImageWidth - textWidth) / 2
	local textY = (previewImageHeight - textHeight) / 2
	love.graphics.print(previewImageText, textX, textY)

	-- Restore original blend mode
	-- This ensures consistent rendering state after this operation
	love.graphics.setBlendMode(prevBlendMode, prevAlphaMode)

	-- Finish canvas operations
	imageGenerator.finishCanvas(previousCanvas)

	-- Get image data and encode as PNG
	local imageData = canvas:newImageData()
	if not imageData then
		errorHandler.setError("Failed to get image data from preview image canvas")
		return false
	end

	local pngData = imageData:encode("png")
	if not pngData then
		errorHandler.setError("Failed to encode preview image to PNG")
		return false
	end

	-- Save to file
	return system.writeBinaryFile(outputPath, pngData:getString())
end

return imageGenerator
