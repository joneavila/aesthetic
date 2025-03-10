--- Menu theme creation functionality
local love = require("love")
local state = require("state")
local constants = require("screen.menu.constants")
local fileUtils = require("screen.menu.file_utils")
local errorHandler = require("screen.menu.error_handler")
local colorUtils = require("utils.color")

-- Module table to export public functions
local themeCreator = {}

local function isSuccess(result)
	-- Handles both Lua 5.1 (returns 0) and Lua 5.2+ (returns true) os.execute() success values
	return result == 0 or result == true
end

local function ensureDir(dir)
	return os.execute('mkdir -p "' .. dir .. '"')
end

local function executeCommand(command, errorMessage)
	local result = os.execute(command)
	if not isSuccess(result) and errorMessage then
		errorHandler.setError(errorMessage)
		return false
	end
	return isSuccess(result)
end

-- Copy a file and create destination directory if needed
local function copyFile(sourcePath, destPath, errorMessage)
	-- Extract directory from destination path
	local destDir = string.match(destPath, "(.*)/[^/]*$")
	if destDir then
		ensureDir(destDir)
	end
	return executeCommand(string.format('cp "%s" "%s"', sourcePath, destPath), errorMessage)
end

-- Function to create a preview image with the selected background color and "muOS" text
local function createPreviewImage(outputPath)
	-- Image dimensions
	local width, height = 288, 216

	local imageData = love.image.newImageData(width, height)

	-- Get the background color from state
	local bgHex = state.colors.background
	local r, g, b = colorUtils.hexToRgb(bgHex)
	local bgColor = { r, g, b, 1 }

	-- Get the foreground color from state
	local fgHex = state.colors.foreground
	r, g, b = colorUtils.hexToRgb(fgHex)
	local fgColor = { r, g, b, 1 }

	-- Fill the image with the background color
	imageData:mapPixel(function(_, _, _, _)
		return bgColor[1], bgColor[2], bgColor[3], 1
	end)

	-- Create a canvas to draw text on the image
	local canvas = love.graphics.newCanvas(width, height)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)

	local selectedFontName = state.selectedFont

	-- Draw "muOS" text with the foreground color, centered
	-- Use the selected font for the preview
	love.graphics.setColor(fgColor)
	local fontMap = {
		["Inter"] = state.fonts.body,
		["Cascadia Code"] = state.fonts.monoBody,
	}
	love.graphics.setFont(fontMap[selectedFontName] or state.fonts.nunito)

	local text = "muOS"
	local textWidth = love.graphics.getFont():getWidth(text)
	local textHeight = love.graphics.getFont():getHeight()
	love.graphics.print(text, (width - textWidth) / 2, (height - textHeight) / 2)

	love.graphics.setCanvas()

	local canvasData = canvas:newImageData()
	local fileData = canvasData:encode("png")

	-- Save to a temporary file in the save directory first
	local tempFilename = "preview_temp.png"
	local success, message = love.filesystem.write(tempFilename, fileData:getString())

	if not success then
		-- TODO: Display error message
		-- print("Failed to save temporary preview image: " .. (message or "unknown error"))
		return false
	end

	-- Get the full path to the temporary file
	local tempPath = love.filesystem.getSaveDirectory() .. "/" .. tempFilename

	-- Move the temporary file to the final location
	local result = copyFile(tempPath, outputPath)

	-- Clean up the temporary file
	love.filesystem.remove(tempFilename)

	return result
end

-- Function to apply glyph settings to a file
local function applyGlyphSettings(filepath, glyphSettings)
	local file = io.open(filepath, "r")
	if not file then
		errorHandler.setError("Failed to open file for glyph settings: " .. filepath)
		return false
	end

	local content = file:read("*all")
	file:close()

	-- Replace placeholders
	local listPadCount, glyphAlphaCount
	content, listPadCount = content:gsub("{%%%s*list_pad_left%s*}", tostring(glyphSettings["list_pad_left"]))
	content, glyphAlphaCount = content:gsub("%%{%s*glyph_alpha%s*}", tostring(glyphSettings["glyph_alpha"]))

	-- Check if replacements were successful
	if listPadCount == 0 or glyphAlphaCount == 0 then
		errorHandler.setError("Failed to replace glyph settings in template")
		return false
	end

	-- Write the updated content back to the file
	file = io.open(filepath, "w")
	if not file then
		errorHandler.setError("Failed to write file for glyph settings: " .. filepath)
		return false
	end

	file:write(content)
	file:close()
	return true
end

-- Function to create theme
function themeCreator.createTheme()
	-- Clean up any existing working directory
	executeCommand('rm -rf "' .. constants.WORKING_TEMPLATE_DIR .. '"')

	-- Create fresh copy of template
	if not fileUtils.copyDir(constants.ORIGINAL_TEMPLATE_DIR, constants.WORKING_TEMPLATE_DIR) then
		errorHandler.setError("Failed to prepare working template directory")
		return false
	end

	-- Get hex colors from state
	local hexColors = {
		background = state.colors.background:gsub("^#", ""),
		foreground = state.colors.foreground:gsub("^#", ""),
	}

	-- Replace colors in theme files
	local themeFiles = { constants.THEME_OUTPUT_DIR .. "/scheme/default.txt" }

	for _, filepath in ipairs(themeFiles) do
		if not fileUtils.replaceColor(filepath, hexColors) then
			errorHandler.setError("Failed to update: " .. filepath)
			return false
		end
	end

	-- Replace glyph settings based on state.glyphs_enabled
	local glyphSettings = {
		list_pad_left = state.glyphs_enabled and 45 or 20,
		glyph_alpha = state.glyphs_enabled and 255 or 0,
	}

	-- Apply glyph settings to theme files
	for _, filepath in ipairs(themeFiles) do
		if not applyGlyphSettings(filepath, glyphSettings) then
			errorHandler.setError("Failed to apply glyph settings to: " .. filepath)
			return false
		end
	end

	-- Find the selected font file
	local selectedFontFile
	for _, font in ipairs(constants.FONTS) do
		if font.name == state.selectedFont then
			selectedFontFile = font.file
			break
		end
	end

	-- Copy the selected font file as default.bin
	local fontSourcePath = constants.ORIGINAL_TEMPLATE_DIR .. "/font/" .. selectedFontFile
	local fontDestPath = constants.THEME_OUTPUT_DIR .. "/font/default.bin"

	-- Copy the selected font file as default.bin
	if not copyFile(fontSourcePath, fontDestPath, "Failed to copy font file: " .. selectedFontFile) then
		return false
	end

	-- Create preview image
	local previewPath = constants.THEME_OUTPUT_DIR .. "/preview.png"

	if not createPreviewImage(previewPath) then
		errorHandler.setError("Failed to create preview image")
		return false
	end

	local themeDir = os.getenv("THEME_DIR")
	if not themeDir then
		errorHandler.setError("THEME_DIR environment variable not set")
		return false
	end

	local outputPath = themeDir .. "/Custom Theme.zip"

	-- Create ZIP archive
	local actualPath = fileUtils.createZipArchive(constants.THEME_OUTPUT_DIR, outputPath)
	if not actualPath then
		errorHandler.setError("Failed to create theme archive")
		return false
	end

	return actualPath
end

-- Function to install the theme
function themeCreator.installTheme(outputPath)
	local themeDir = os.getenv("THEME_DIR")
	if not themeDir then
		errorHandler.setError("THEME_DIR environment variable not set")
		return false
	end

	local themeActiveDir = themeDir .. "/active"

	-- Remove existing active theme directory and create a new one
	executeCommand('rm -rf "' .. themeActiveDir .. '"')
	executeCommand("sync")
	ensureDir(themeActiveDir)

	-- Extract the theme to the active directory
	if
		not executeCommand(
			string.format('unzip "%s" -d "%s"', outputPath, themeActiveDir),
			"Failed to install theme to active directory"
		)
	then
		return false
	end

	-- Sync to ensure all writes are complete
	executeCommand("sync")
	return true
end

-- Clean up working directory
function themeCreator.cleanup()
	executeCommand('rm -rf "' .. constants.WORKING_TEMPLATE_DIR .. '"')
end

return themeCreator
