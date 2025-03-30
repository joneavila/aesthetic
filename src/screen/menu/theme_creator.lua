--- Menu theme creation functionality
local love = require("love")
local state = require("state")
local constants = require("screen.menu.constants")
local fileUtils = require("screen.menu.file_utils")
local errorHandler = require("screen.menu.error_handler")
local colorUtils = require("utils.color")

local paths = constants.PATHS

local tove = require("tove")

-- Module table to export public functions
local themeCreator = {}

local function ensureDir(dir)
	local result = os.execute('mkdir -p "' .. dir .. '"')
	if not result then
		errorHandler.setError("Failed to create directory: " .. dir)
		return false
	end
	return result
	-- Extract directory from path
	-- local destDir = string.match(path, "(.*)/[^/]*$")
	-- if destDir then
	-- 	love.filesystem.createDirectory(destDir)
	-- end
	-- love.filesystem.write(path, data)
end

local function executeCommand(command, errorMessage)
	local result = os.execute(command)
	if not result and errorMessage then
		errorHandler.setError(errorMessage)
		return false
	end
	return result
end

-- Copy a file and create destination directory if needed
local function copyFile(sourcePath, destPath, errorMessage)
	-- Extract directory from destination path
	local destDir = string.match(destPath, "(.*)/[^/]*$")
	if destDir then
		if not ensureDir(destDir) then
			return false -- ensureDir already set the error
		end
	end
	return executeCommand(string.format('cp "%s" "%s"', sourcePath, destPath), errorMessage)
end

-- Function to create a preview image with the selected background color and "muOS" text
local function createPreviewImage()
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

	-- Get image data and encode as PNG
	local imageData = canvas:newImageData()
	if not imageData then
		errorHandler.setError("Failed to get image data from preview canvas")
		return false
	end

	local pngData = imageData:encode("png")
	if not pngData then
		errorHandler.setError("Failed to encode preview image to PNG")
		return false
	end

	-- Write file using direct file I/O
	local file = io.open(paths.THEME_PREVIEW_IMAGE_PATH, "wb")
	if not file then
		errorHandler.setError("Failed to open preview image file for writing: " .. paths.THEME_PREVIEW_IMAGE_PATH)
		return false
	end

	local success, writeErr = pcall(function()
		file:write(pngData:getString())
	end)
	file:close()

	if not success then
		errorHandler.setError("Failed to write preview image data: " .. tostring(writeErr))
		return false
	end

	return true
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

	local contentPadding = 4
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
		errorHandler.setError("Failed to open file for writing BMP: " .. filepath)
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

local function getBackgroundColor()
	local bgHex = state.colors.background
	local r, g, b = colorUtils.hexToRgb(bgHex)
	return { r, g, b, 1 }
end

local function getForegroundColor()
	local fgHex = state.colors.foreground
	local r, g, b = colorUtils.hexToRgb(fgHex)
	return { r, g, b, 1 }
end

local function createStartImage()
	-- Read properties from state
	local width, height = state.screenWidth, state.screenHeight
	local bgColor = getBackgroundColor()
	local fgColor = getForegroundColor()

	-- Load SVG
	local svg = love.filesystem.read("assets/muOS/logo.svg")
	local iconSize = 200
	local logo = tove.newGraphics(svg, iconSize)
	logo:setMonochrome(fgColor[1], fgColor[2], fgColor[3])

	local previousCanvas = love.graphics.getCanvas()

	-- Create new canvas, set it as the current canvas, and clear it
	local canvas = love.graphics.newCanvas(width, height)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)

	love.graphics.push()

	-- Draw the logo at the center
	local centerX = width / 2
	local centerY = height / 2
	logo:draw(centerX, centerY)

	love.graphics.pop()

	love.graphics.setCanvas(previousCanvas)

	local imageData = canvas:newImageData()
	if not saveAsBMP(imageData, paths.THEME_BOOTLOGO_IMAGE_PATH) then
		errorHandler.setError("Failed to save BMP file")
		return false
	end

	return true
end

-- Function to create reboot image with dynamic colors and centered icon
local function createRebootImage()
	-- Read properties from state
	local screenWidth, screenHeight = state.screenWidth, state.screenHeight
	local bgColor = getBackgroundColor()
	local fgColor = getForegroundColor()

	-- Load SVG
	local svg = love.filesystem.read("assets/icons/rotate-ccw.svg")
	if not svg then
		errorHandler.setError("Failed to load reboot icon SVG file")
		return false
	end

	local iconSize = 150
	local icon = tove.newGraphics(svg, iconSize)
	if not icon then
		errorHandler.setError("Failed to create graphics from reboot icon SVG")
		return false
	end
	icon:setMonochrome(fgColor[1], fgColor[2], fgColor[3])

	local previousCanvas = love.graphics.getCanvas()

	-- Create a new canvas, set it as the current canvas, and clear it
	local canvas = love.graphics.newCanvas(screenWidth, screenHeight)
	if not canvas then
		errorHandler.setError("Failed to create canvas for reboot image")
		return false
	end
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)

	love.graphics.push()

	-- Draw the icon
	local iconX = screenWidth / 2
	local iconY = screenHeight / 2 - 50
	icon:draw(iconX, iconY)

	-- Get the selected font from state
	-- TODO Refactor font code: Store fonts as pairs of name and loaded font (or find way to get name from loaded font)
	local selectedFontName = state.selectedFont
	local fontMap = {
		["Inter"] = state.fonts.body,
		["Cascadia Code"] = state.fonts.monoBody,
		["Retro Pixel"] = state.fonts.retroPixel,
	}
	local font = fontMap[selectedFontName] or state.fonts.body
	if not font then
		errorHandler.setError("Failed to get font for reboot image")
		love.graphics.pop()
		love.graphics.setCanvas(previousCanvas)
		return false
	end

	-- Draw the text centered
	love.graphics.setFont(font, constants.IMAGE_FONT_SIZE)
	love.graphics.setColor(fgColor)
	local text = "Rebooting..."
	local textWidth = font:getWidth(text)
	local textX = (screenWidth - textWidth) / 2
	local textY = screenHeight / 2 + 50
	love.graphics.print(text, textX, textY)

	love.graphics.pop()

	love.graphics.setCanvas(previousCanvas)

	-- Get image data and encode
	local imageData = canvas:newImageData()
	if not imageData then
		errorHandler.setError("Failed to get image data from reboot canvas")
		return false
	end

	local pngData = imageData:encode("png")
	if not pngData then
		errorHandler.setError("Failed to encode reboot image to PNG")
		return false
	end

	-- Write file using direct file I/O since love.filesystem.write() doesn't work (?)
	local file = io.open(paths.THEME_REBOOT_IMAGE_PATH, "wb")
	if not file then
		errorHandler.setError("Failed to open reboot image file for writing: " .. paths.THEME_REBOOT_IMAGE_PATH)
		return false
	end

	local success, writeErr = pcall(function()
		file:write(pngData:getString())
	end)
	file:close()

	if not success then
		errorHandler.setError("Failed to write reboot image data: " .. tostring(writeErr))
		return false
	end

	return true
end

-- Function to create theme
function themeCreator.createTheme()
	local status, err = xpcall(function()
		-- Clean up and prepare working directory
		executeCommand('rm -rf "' .. paths.WORKING_THEME_DIR .. '"')
		if not fileUtils.copyDir(paths.TEMPLATE_DIR, paths.WORKING_THEME_DIR) then
			errorHandler.setError("Failed to prepare working template directory")
		end

		-- Ensure all required directories exist
		for key, path in pairs(paths) do
			if type(path) == "string" and string.match(path, "/$") == nil then
				-- Only ensure directories for path strings that don't already end with a slash
				local dirPath = string.match(path, "(.*)/[^/]*$")
				if dirPath then
					if not ensureDir(dirPath) then
						return false -- ensureDir already set the error
					end
				end
			end
		end

		-- Create startup image
		if not createStartImage() then
			-- createStartImage() already sets the error handler message
			return false
		end

		-- Create reboot image
		if not createRebootImage() then
			-- Do not set error handler message here since it is set in createRebootImage()
			return false
		end

		-- Set preview path based on screen resolution
		if not createPreviewImage() then
			return false
		end

		-- Get hex colors from state (remove # prefix)
		local hexColors = {
			background = state.colors.background:gsub("^#", ""),
			foreground = state.colors.foreground:gsub("^#", ""),
		}

		-- Replace colors and apply glyph settings to theme files

		local glyphSettings = {
			list_pad_left = state.glyphs_enabled and 42 or 20,
			glyph_alpha = state.glyphs_enabled and 255 or 0,
		}
		local filepath = paths.THEME_SCHEME_GLOBAL_PATH
		if not fileUtils.replaceColor(filepath, hexColors) then
			errorHandler.setError("Failed to update colors in: " .. filepath)
			return false
		end
		if not applyGlyphSettings(filepath, glyphSettings) then
			errorHandler.setError("Failed to apply glyph settings to: " .. filepath)
			return false
		end
		if not applyScreenWidthSettings(filepath, state.screenWidth) then
			errorHandler.setError("Failed to apply screen width settings to: " .. filepath)
			return false
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
			errorHandler.setError("Selected font not found: " .. tostring(state.selectedFont))
			return false
		end

		-- Copy the selected font file as default.bin
		local fontSourcePath = paths.THEME_FONT_SOURCE_DIR .. "/" .. selectedFontFile
		if
			not copyFile(
				fontSourcePath,
				paths.THEME_DEFAULT_FONT_PATH,
				"Failed to copy font file: " .. selectedFontFile
			)
		then
			return false
		end

		-- Create name.txt file with the theme name
		local nameFile = io.open(paths.THEME_NAME_PATH, "w")
		if not nameFile then
			errorHandler.setError("Failed to create name.txt file")
			return false
		end
		nameFile:write(state.applicationName) -- Use application name as theme name
		nameFile:close()

		-- Create the ZIP archive
		local finalOutputPath = fileUtils.createZipArchive(paths.WORKING_THEME_DIR, paths.THEME_OUTPUT_PATH)
		if not finalOutputPath then
			errorHandler.setError("Failed to create theme archive")
			return false
		end

		return finalOutputPath
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
	-- Remove existing active theme directory and create a new one
	executeCommand('rm -rf "' .. paths.THEME_ACTIVE_DIR .. '"')
	executeCommand("sync")

	-- Extract the theme to the active directory
	if
		not executeCommand(
			string.format('unzip "%s" -d "%s"', outputPath, paths.THEME_ACTIVE_DIR),
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
	executeCommand('rm -rf "' .. paths.WORKING_THEME_DIR .. '"')
end

return themeCreator
