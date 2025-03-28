--- Menu theme creation functionality
local love = require("love")
local state = require("state")
local constants = require("screen.menu.constants")
local fileUtils = require("screen.menu.file_utils")
local errorHandler = require("screen.menu.error_handler")
local colorUtils = require("utils.color")

-- Module table to export public functions
local themeCreator = {}

-- Handles both Lua 5.1 (returns 0) and Lua 5.2+ (returns true) os.execute() success values
local function isSuccess(result)
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
	local text = "muOS"

	-- Get colors from state
	local bgHex, fgHex = state.colors.background, state.colors.foreground
	local r, g, b = colorUtils.hexToRgb(bgHex)
	local bgColor = { r, g, b, 1 }
	r, g, b = colorUtils.hexToRgb(fgHex)
	local fgColor = { r, g, b, 1 }

	-- Create canvas and draw
	local canvas = love.graphics.newCanvas(width, height)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)

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
	local textWidth, textHeight = font:getWidth(text), font:getHeight()
	love.graphics.print(text, (width - textWidth) / 2, (height - textHeight) / 2)
	love.graphics.setCanvas()

	-- Save image
	local tempFilename = "preview_temp.png"
	local success = love.filesystem.write(tempFilename, canvas:newImageData():encode("png"):getString())

	if not success then
		return false
	end

	-- Move to final location
	local tempPath = love.filesystem.getSaveDirectory() .. "/" .. tempFilename
	local result = copyFile(tempPath, outputPath)
	love.filesystem.remove(tempFilename)

	return result
end

-- Function to apply glyph settings to a scheme file
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

-- Function to apply screen width settings to a scheme file
local function applyScreenWidthSettings(filepath, screenWidth)
	local file = io.open(filepath, "r")
	if not file then
		errorHandler.setError("Failed to open file for screen width settings: " .. filepath)
		return false
	end

	local content = file:read("*all")
	file:close()

	-- Define content padding value
	local contentPadding = 4

	-- Calculate content width (screen width minus padding on both sides)
	local contentWidth = screenWidth - (contentPadding * 2)

	-- Replace content-padding placeholder
	local contentPaddingCount
	content, contentPaddingCount = content:gsub("%%{%s*content%-padding%s*}", tostring(contentPadding))

	-- Check if replacement was successful
	if contentPaddingCount == 0 then
		errorHandler.setError("Failed to replace content padding settings in template")
		return false
	end

	-- Replace screen-width placeholder
	local screenWidthCount
	content, screenWidthCount = content:gsub("%%{%s*screen%-width%s*}", tostring(contentWidth))

	-- Check if replacement was successful
	if screenWidthCount == 0 then
		errorHandler.setError("Failed to replace screen width settings in template")
		return false
	end

	-- Write the updated content back to the file
	file = io.open(filepath, "w")
	if not file then
		errorHandler.setError("Failed to write file for screen width settings: " .. filepath)
		return false
	end

	file:write(content)
	file:close()
	return true
end

-- Function to save image data as a 24-bit BMP file
local function saveAsBMP(imageData, filepath)
	-- Get image dimensions
	local width = imageData:getWidth()
	local height = imageData:getHeight()

	-- Calculate row size and padding
	-- BMP rows must be aligned to 4 bytes
	local rowSize = math.floor((24 * width + 31) / 32) * 4
	local padding = rowSize - width * 3

	-- Calculate file size
	local headerSize = 54 -- 14 bytes file header + 40 bytes info header
	local imageSize = rowSize * height
	local fileSize = headerSize + imageSize

	-- Create file
	local file = io.open(filepath, "wb")
	if not file then
		return false
	end

	-- Helper function to write little-endian integers
	local function writeInt(value, bytes)
		local result = ""
		for i = 1, bytes do
			result = result .. string.char(value % 256)
			value = math.floor(value / 256)
		end
		file:write(result)
	end

	-- Write BMP file header (14 bytes)
	file:write("BM") -- Signature
	writeInt(fileSize, 4) -- File size
	writeInt(0, 4) -- Reserved
	writeInt(headerSize, 4) -- Pixel data offset

	-- Write BMP info header (40 bytes)
	writeInt(40, 4) -- Info header size
	writeInt(width, 4) -- Width
	writeInt(height, 4) -- Height (positive for bottom-up)
	writeInt(1, 2) -- Planes
	writeInt(24, 2) -- Bits per pixel
	writeInt(0, 4) -- Compression (none)
	writeInt(imageSize, 4) -- Image size
	writeInt(2835, 4) -- X pixels per meter
	writeInt(2835, 4) -- Y pixels per meter
	writeInt(0, 4) -- Colors in color table
	writeInt(0, 4) -- Important color count

	-- Write pixel data (bottom-up, BGR format)
	local padBytes = string.rep("\0", padding)
	for y = height - 1, 0, -1 do
		for x = 0, width - 1 do
			local r, g, b, a = imageData:getPixel(x, y)
			-- Convert from 0-1 to 0-255 range and write BGR
			file:write(string.char(math.floor(b * 255), math.floor(g * 255), math.floor(r * 255)))
		end
		-- Add padding to align rows to 4 bytes
		if padding > 0 then
			file:write(padBytes)
		end
	end

	file:close()
	return true
end

-- Function to create startup image with dynamic colors and centered SVG
local function createStartImage()
	-- Get dimensions from state
	local width, height = state.screenWidth, state.screenHeight

	-- Get colors from state
	local bgHex, fgHex = state.colors.background, state.colors.foreground
	local r, g, b = colorUtils.hexToRgb(bgHex)
	local bgColor = { r, g, b, 1 }
	r, g, b = colorUtils.hexToRgb(fgHex)
	local fgColor = { r, g, b, 1 }

	-- Prepare file path first - do all non-canvas operations before setting any canvas
	-- TODO: Make this dynamic based on the screen resolution
	local resolutionDir = "640x480"
	local imageDir = resolutionDir .. "/image"
	local outputPath = constants.WORKING_TEMPLATE_DIR .. "/" .. imageDir .. "/bootlogo.bmp"

	-- Ensure directory exists before any drawing operations
	ensureDir(constants.WORKING_TEMPLATE_DIR .. "/" .. imageDir)

	local canvas = love.graphics.newCanvas(width, height)

	local tove = require("tove")

	local logoPath = "assets/muOS/logo.svg"
	local svgContent = love.filesystem.read(logoPath)
	local logo = tove.newGraphics(svgContent)

	logo:setLineColor(fgColor[1], fgColor[2], fgColor[3], 1)
	logo:stroke()
	logo:setFillColor(fgColor[1], fgColor[2], fgColor[3], 1)
	logo:fill()

	-- Save current graphics state
	local prevCanvas = love.graphics.getCanvas()
	local prevBlendMode = love.graphics.getBlendMode()
	local prevColor = { love.graphics.getColor() }

	-- Drawing operations
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)

	-- Draw logo centered correctly
	love.graphics.push()

	-- Calculate center points
	local screenCenterX = width / 2
	local screenCenterY = height / 2

	-- Draw the logo with error handling
	logo:draw(screenCenterX, screenCenterY, 0, 0.3, 0.3)

	love.graphics.pop()

	-- CRITICAL: Reset canvas BEFORE getting image data
	love.graphics.setCanvas(prevCanvas)
	love.graphics.setBlendMode(prevBlendMode)
	love.graphics.setColor(prevColor)

	local imageData = canvas:newImageData()

	-- Save directly as BMP (with no active canvas)
	if not saveAsBMP(imageData, outputPath) then
		error("Failed to save BMP file")
	end

	-- Always return with no active canvas
	return true
end

-- Function to create theme
function themeCreator.createTheme()
	local status, err = xpcall(function()
		-- Clean up and prepare working directory
		executeCommand('rm -rf "' .. constants.WORKING_TEMPLATE_DIR .. '"')
		if not fileUtils.copyDir(constants.ORIGINAL_TEMPLATE_DIR, constants.WORKING_TEMPLATE_DIR) then
			error("Failed to prepare working template directory")
		end

		-- Verify directory structure
		local requiredDirs = {
			constants.WORKING_TEMPLATE_DIR .. "/scheme",
			constants.WORKING_TEMPLATE_DIR .. "/font",
			constants.WORKING_TEMPLATE_DIR .. "/640x480/image",
		}
		for _, dir in ipairs(requiredDirs) do
			ensureDir(dir)
		end

		-- Create startup image
		local startupImagePath = constants.WORKING_TEMPLATE_DIR .. "/640x480/image/bootlogo.bmp"
		if not createStartImage() then
			error("Failed to create startup image")
		end

		-- Verify startup image exists
		if not love.filesystem.getInfo(startupImagePath) then
			error("Startup image was not created at: " .. startupImagePath)
		end

		-- Get hex colors from state (remove # prefix)
		local hexColors = {
			background = state.colors.background:gsub("^#", ""),
			foreground = state.colors.foreground:gsub("^#", ""),
		}

		-- Replace colors and apply glyph settings to theme files
		local themeFiles = { constants.WORKING_TEMPLATE_DIR .. "/scheme/global.ini" }
		local glyphSettings = {
			list_pad_left = state.glyphs_enabled and 42 or 20,
			glyph_alpha = state.glyphs_enabled and 255 or 0,
		}

		for _, filepath in ipairs(themeFiles) do
			if not fileUtils.replaceColor(filepath, hexColors) then
				error("Failed to update colors in: " .. filepath)
			end

			if not applyGlyphSettings(filepath, glyphSettings) then
				error("Failed to apply glyph settings to: " .. filepath)
			end

			if not applyScreenWidthSettings(filepath, state.screenWidth) then
				error("Failed to apply screen width settings to: " .. filepath)
			end
		end

		-- Find and copy the selected font file
		local selectedFontFile
		for _, font in ipairs(constants.FONTS) do
			if font.name == state.selectedFont then
				selectedFontFile = font.file
				break
			end
		end

		if not selectedFontFile then
			error("Selected font not found: " .. tostring(state.selectedFont))
		end

		-- Copy the selected font file as default.bin
		local fontSourcePath = constants.ORIGINAL_TEMPLATE_DIR .. "/font/" .. selectedFontFile
		local fontDestPath = constants.WORKING_TEMPLATE_DIR .. "/font/default.bin"
		if not copyFile(fontSourcePath, fontDestPath, "Failed to copy font file: " .. selectedFontFile) then
			return false
		end

		-- Create preview image with dynamic resolution path
		local screenWidth = state.screenWidth
		local screenHeight = state.screenHeight
		local resolutionDir = screenWidth .. "x" .. screenHeight

		-- Create directory if it doesn't exist
		local previewDir = constants.WORKING_TEMPLATE_DIR .. "/" .. resolutionDir
		ensureDir(previewDir)

		-- Set preview path based on screen resolution
		local previewPath = previewDir .. "/preview.png"
		if not createPreviewImage(previewPath) then
			error("Failed to create preview image at: " .. previewPath)
		end

		-- Double check the file exists
		if not love.filesystem.getInfo(previewPath) then
			error("Preview image was not created at: " .. previewPath)
		end

		-- Create name.txt file with the theme name
		local nameFilePath = constants.WORKING_TEMPLATE_DIR .. "/name.txt"
		local nameFile = io.open(nameFilePath, "w")
		if not nameFile then
			error("Failed to create name.txt file")
		end

		nameFile:write("Aesthetic")
		nameFile:close()

		-- Create and return ZIP archive
		local themeDir = os.getenv("THEME_DIR")
		if not themeDir then
			error("THEME_DIR environment variable not set")
		end

		local themeName = "Aesthetic"
		local outputPath = themeDir .. "/" .. themeName .. ".muxthm"

		-- Create the ZIP archive
		local actualPath = fileUtils.createZipArchive(constants.WORKING_TEMPLATE_DIR, outputPath)
		if not actualPath then
			error("Failed to create theme archive")
		end

		return actualPath
	end, debug.traceback)

	if not status then
		errorHandler.setError(tostring(err))
		return false
	end

	-- Return the path from the successful execution
	return err
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
