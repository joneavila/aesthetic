--- Image generation utilities
local love = require("love")
local state = require("state")
local colorUtils = require("utils.color")
local errorHandler = require("error_handler")
local bmp = require("utils.bmp")
local system = require("utils.system")
local paths = require("paths")
local tove = require("tove")

local imageGenerator = {}

-- Create a canvas with background color
function imageGenerator.createCanvas(width, height, bgColor)
	local canvas = love.graphics.newCanvas(width, height)
	local previousCanvas = love.graphics.getCanvas()

	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)

	return canvas, previousCanvas
end

-- Finish drawing on canvas and restore previous canvas
function imageGenerator.finishCanvas(previousCanvas)
	love.graphics.setCanvas(previousCanvas)
end

-- Draw centered SVG icon on canvas
function imageGenerator.drawSvgIcon(svg, size, x, y, color)
	local icon = tove.newGraphics(svg, size)
	icon:setMonochrome(color[1], color[2], color[3])
	icon:draw(x, y)
	return icon
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

	-- Load icon SVG
	local svg
	if iconPath then
		svg = love.filesystem.read(iconPath)
		if not svg then
			errorHandler.setError("Failed to read SVG file: " .. iconPath)
			return false
		end
	end

	-- Create canvas
	local canvas, previousCanvas = imageGenerator.createCanvas(width, height, bgColor)

	love.graphics.push()

	-- Draw icon if provided
	if svg then
		local iconX = width / 2
		local iconY = height / 2 - (text and 50 or 0)
		imageGenerator.drawSvgIcon(svg, iconSize, iconX, iconY, fgColor)
	end

	-- Draw text if provided
	if text then
		-- Create a larger version of the font
		local imageFontSize = paths.getImageFontSize(height)
		local fontSize = math.floor(imageFontSize * 1.3)
		local fontDef = state.fontDefs[state.fontNameToKey[state.selectedFont]]
		local largerFont = love.graphics.newFont(fontDef.path, fontSize)

		-- Set the font and color
		love.graphics.setFont(largerFont)
		love.graphics.setColor(fgColor)

		-- Draw the text centered
		local textWidth = largerFont:getWidth(text)
		local textX = (width - textWidth) / 2
		local textY = height / 2 + 30
		love.graphics.print(text, textX, textY)
	end

	love.graphics.pop()

	-- Finish canvas operations
	imageGenerator.finishCanvas(previousCanvas)

	-- Get image data
	local imageData = canvas:newImageData()

	-- Save file
	if outputPath then
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
				return false
			end
		end
	end

	return imageData
end

-- Create a preview image for muOS theme selection
function imageGenerator.createPreviewImage(outputPath)
	-- Set the preview image dimensions based on the screen resolution
	local screenWidth, screenHeight = state.screenWidth, state.screenHeight

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

	-- Set font and draw text
	love.graphics.setColor(fgColor)
	local selectedFontName = state.selectedFont
	local fontMap = {
		["Inter"] = state.fonts.body,
		["Cascadia Code"] = state.fonts.monoBody,
		["Retro Pixel"] = state.fonts.retroPixel,
	}
	local font = fontMap[selectedFontName] or state.fonts.nunito
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
