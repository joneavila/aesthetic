--- Menu theme creation functionality
local love = require("love")
local colors = require("colors")
local state = require("state")
local constants = require("screen.menu.constants")
local fileUtils = require("screen.menu.file_utils")
local errorHandler = require("screen.menu.error_handler")

-- Module table to export public functions
local themeCreator = {}

-- Function to create a preview image with the selected background color and "muOS" text
local function createPreviewImage(outputPath)
	-- Image dimensions
	local width, height = 288, 216

	-- Create a new image data object
	local imageData = love.image.newImageData(width, height)

	-- Get the background color from state
	local bgColor = colors[state.colors.background] or colors.bg

	-- Get the foreground color
	local fgColor = colors[state.colors.foreground] or colors.white

	-- Fill the image with the background color
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			imageData:setPixel(x, y, bgColor[1], bgColor[2], bgColor[3], 1)
		end
	end

	-- Create a canvas to draw text on the image
	local canvas = love.graphics.newCanvas(width, height)
	love.graphics.setCanvas(canvas)

	-- Clear the canvas with the background color
	love.graphics.clear(bgColor[1], bgColor[2], bgColor[3], 1)

	local selectedFontName = state.selectedFont

	-- Draw "muOS" text with the foreground color, centered
	love.graphics.setColor(fgColor[1], fgColor[2], fgColor[3], 1)

	-- Use the selected font for the preview
	if selectedFontName == "Inter" then
		love.graphics.setFont(state.fonts.body)
	else
		love.graphics.setFont(state.fonts.nunito)
	end

	local text = "muOS"
	local textWidth = love.graphics.getFont():getWidth(text)
	local textHeight = love.graphics.getFont():getHeight()
	love.graphics.print(text, (width - textWidth) / 2, (height - textHeight) / 2)

	-- Reset canvas
	love.graphics.setCanvas()

	local canvasData = canvas:newImageData()
	local fileData = canvasData:encode("png")

	-- Save to a temporary file in the save directory first
	local tempFilename = "preview_temp.png"
	local success, message = love.filesystem.write(tempFilename, fileData:getString())

	if not success then
		print("Failed to save temporary preview image: " .. (message or "unknown error"))
		return false
	end

	-- Get the full path to the temporary file
	local tempPath = love.filesystem.getSaveDirectory() .. "/" .. tempFilename

	-- Move the temporary file to the final location
	local cmd = string.format('cp "%s" "%s"', tempPath, outputPath)
	local result = os.execute(cmd)

	-- Clean up the temporary file
	love.filesystem.remove(tempFilename)

	return result == 0 or result == true
end

-- Function to create theme
function themeCreator.createTheme()
	-- Clean up any existing working directory
	os.execute('rm -rf "' .. constants.WORKING_TEMPLATE_DIR .. '"')

	-- Create fresh copy of template
	if not fileUtils.copyDir(constants.ORIGINAL_TEMPLATE_DIR, constants.WORKING_TEMPLATE_DIR) then
		errorHandler.setError("Failed to prepare working template directory")
		return false
	end

	-- Convert selected colors to hex
	local hexColors = {}
	local colorMappings = {
		background = state.colors.background,
		foreground = state.colors.foreground,
	}

	for key, color in pairs(colorMappings) do
		local hex = colors.toHex(color)
		if not hex then
			errorHandler.setError("Could not convert color to hex: " .. color)
			return false
		end
		hexColors[key] = hex:gsub("^#", "") -- Remove the # from hex colors
	end

	-- Replace colors in theme files
	local themeFiles = { constants.THEME_OUTPUT_DIR .. "/scheme/default.txt" }

	for _, filepath in ipairs(themeFiles) do
		if not fileUtils.replaceColor(filepath, hexColors) then
			print("Failed to update: " .. filepath)
			return false
		end
	end

	-- Find the selected font file based on state.selectedFont
	local selectedFontFile = nil
	for _, font in ipairs(constants.FONTS) do
		if font.name == state.selectedFont then
			selectedFontFile = font.file
			break
		end
	end

	-- Copy the selected font file as default.bin
	if selectedFontFile then
		local fontSourcePath = constants.ORIGINAL_TEMPLATE_DIR .. "/font/" .. selectedFontFile
		local fontDestPath = constants.THEME_OUTPUT_DIR .. "/font/default.bin"

		-- Ensure the font directory exists
		os.execute('mkdir -p "' .. constants.THEME_OUTPUT_DIR .. '/font"')

		-- Remove any existing default.bin that might have been copied from the template
		os.execute('rm -f "' .. fontDestPath .. '"')

		-- Copy the selected font file as default.bin
		local cmd = string.format('cp "%s" "%s"', fontSourcePath, fontDestPath)
		local success = os.execute(cmd)

		if not (success == 0 or success == true) then
			errorHandler.setError("Failed to copy font file: " .. selectedFontFile)
			return false
		end
	else
		errorHandler.setError("No font selected")
		return false
	end

	-- Create preview image
	local previewPath = constants.THEME_OUTPUT_DIR .. "/preview.png"

	-- Ensure the directory exists
	local previewDir = string.match(previewPath, "(.*)/[^/]*$")
	if previewDir then
		os.execute('mkdir -p "' .. previewDir .. '"')
	end

	-- Remove any existing preview image that might have been copied from the template
	os.execute('rm -f "' .. previewPath .. '"')

	local success = createPreviewImage(previewPath)
	if not success then
		errorHandler.setError("Failed to create preview image")
		return false
	end

	-- Try SD card location first
	local sdcardThemeDir = "/mnt/sdcard/MUOS/theme"
	local outputPath = sdcardThemeDir .. "/Custom Theme.zip"

	-- Try to create SD card directory
	os.execute('mkdir -p "' .. sdcardThemeDir .. '"')

	-- Attempt to write to SD card first
	success = fileUtils.createZipArchive(constants.THEME_OUTPUT_DIR, outputPath)
	if success then
		return true -- If SD card write succeeds, we're done
	end

	-- If SD card fails, try internal storage
	local themeDir = os.getenv("THEME_DIR")
	if not themeDir then
		errorHandler.setError("THEME_DIR environment variable not set")
		return false
	end

	-- Create and move ZIP archive to internal storage
	outputPath = themeDir .. "/Custom Theme.zip"
	success = fileUtils.createZipArchive(constants.THEME_OUTPUT_DIR, outputPath)

	if not success then
		errorHandler.setError("Failed to create theme archive in both SD card and internal storage")
		return false
	end

	return true
end

-- Clean up working directory
function themeCreator.cleanup()
	os.execute('rm -rf "' .. constants.WORKING_TEMPLATE_DIR .. '"')
end

return themeCreator
