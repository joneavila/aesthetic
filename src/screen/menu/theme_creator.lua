--- Menu theme creation functionality
local love = require("love")
local state = require("state")
local constants = require("screen.menu.constants")
local system = require("utils.system")
local errorHandler = require("screen.menu.error_handler")
local colorUtils = require("utils.color")
local commands = require("utils.commands")

local paths = constants.PATHS

local tove = require("tove")

-- Module table to export public functions
local themeCreator = {}

-- Function to create `name.txt` containing the theme's name
local function createNameFile()
	local nameFile = io.open(paths.THEME_NAME_PATH, "w")
	if not nameFile then
		errorHandler.setError("Failed to create `name.txt` file: " .. paths.THEME_NAME_PATH)
		return false
	end
	local content = state.applicationName -- Use application name as theme name
	nameFile:write(content)
	nameFile:close()
	return true
end

-- Function to create preview image displayed in muOS theme selection menu
local function createPreviewImage()
	-- Set the preview image dimensions based on the screen resolution
	local screenWidth, screenHeight = state.screenWidth, state.screenHeight

	-- Define preview dimensions based on screen resolution
	-- These dimensions are based on the default 2502.0 PIXIE theme
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

	local previewImageText = "muOS"

	-- Get colors from state
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	-- Create canvas and draw
	local canvas = love.graphics.newCanvas(previewImageWidth, previewImageHeight)
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
	local textWidth, textHeight = font:getWidth(previewImageText), font:getHeight()
	local textX = (previewImageWidth - textWidth) / 2
	local textY = (previewImageHeight - textHeight) / 2
	love.graphics.print(previewImageText, textX, textY)
	love.graphics.setCanvas()

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

	-- Write the preview image to its destination
	local success, writeErr = pcall(function()
		local file = io.open(paths.THEME_PREVIEW_IMAGE_PATH, "wb")
		if not file then
			error("Failed to open preview image file for writing: " .. paths.THEME_PREVIEW_IMAGE_PATH)
		end
		file:write(pngData:getString())
		file:close()
	end)
	if not success then
		errorHandler.setError(writeErr)
		return false
	end

	return true
end

-- Function to apply glyph settings to a scheme file
-- This sets scheme values to adapt to either enabled or disabled glyphs
local function applyGlyphSettings(schemeFilePath)
	-- Read the scheme file content
	local schemeFile, err = io.open(schemeFilePath, "r")
	if not schemeFile then
		errorHandler.setError("Failed to open file for glyph settings (" .. schemeFilePath .. "): " .. err)
		return false
	end

	local schemeFileContent = schemeFile:read("*all")
	schemeFile:close()

	local glyphSettings = {
		list_pad_left = state.glyphs_enabled and 42 or 20,
		glyph_alpha = state.glyphs_enabled and 255 or 0,
	}

	-- Replace placeholders
	local listPadCount, glyphAlphaCount
	schemeFileContent, listPadCount =
		schemeFileContent:gsub("{%%%s*list_pad_left%s*}", tostring(glyphSettings["list_pad_left"]))
	schemeFileContent, glyphAlphaCount =
		schemeFileContent:gsub("%%{%s*glyph_alpha%s*}", tostring(glyphSettings["glyph_alpha"]))

	-- Check if replacements were successful
	if listPadCount == 0 then
		errorHandler.setError("Failed to replace list pad left in template")
		return false
	end
	if glyphAlphaCount == 0 then
		errorHandler.setError("Failed to replace glyph alpha in template")
		return false
	end

	-- Write the updated content back to the file
	schemeFile, err = io.open(schemeFilePath, "w")
	if not schemeFile then
		errorHandler.setError("Failed to write file for glyph settings (" .. schemeFilePath .. "): " .. err)
		return false
	end

	schemeFile:write(schemeFileContent)
	schemeFile:close()
	return true
end

-- Function to apply screen width settings to a scheme file
-- This sets scheme values to adapt to the screen width
local function applyScreenWidthSettings(schemeFilePath, screenWidth)
	-- Read the scheme file content
	local schemeFile, err = io.open(schemeFilePath, "r")
	if not schemeFile then
		errorHandler.setError("Failed to open file for screen width settings (" .. schemeFilePath .. "): " .. err)
		return false
	end

	local schemeFileContent = schemeFile:read("*all")
	schemeFile:close()

	local contentPadding = 4
	local contentWidth = screenWidth - (contentPadding * 2)

	-- Replace content-padding placeholder
	local contentPaddingCount
	schemeFileContent, contentPaddingCount =
		schemeFileContent:gsub("%%{%s*content%-padding%s*}", tostring(contentPadding))
	if contentPaddingCount == 0 then
		errorHandler.setError("Failed to replace content padding settings in template")
		return false
	end

	-- Replace screen-width placeholder
	local screenWidthCount
	schemeFileContent, screenWidthCount = schemeFileContent:gsub("%%{%s*screen%-width%s*}", tostring(contentWidth))
	if screenWidthCount == 0 then
		errorHandler.setError("Failed to replace screen width settings in template")
		return false
	end

	-- Write the updated content back to the file
	schemeFile, err = io.open(schemeFilePath, "w")
	if not schemeFile then
		errorHandler.setError("Failed to write file for screen width settings (" .. schemeFilePath .. "): " .. err)
		return false
	end

	schemeFile:write(schemeFileContent)
	schemeFile:close()
	return true
end

-- Function to apply content height settings to a scheme file
-- This sets the content height based on screen height minus header and footer heights
local function applyContentHeightSettings(schemeFilePath, screenHeight)
	-- Read the scheme file content
	local schemeFile, err = io.open(schemeFilePath, "r")
	if not schemeFile then
		errorHandler.setError("Failed to open file for content height settings (" .. schemeFilePath .. "): " .. err)
		return false
	end

	local schemeFileContent = schemeFile:read("*all")
	schemeFile:close()

	-- Extract HEADER_HEIGHT and FOOTER_HEIGHT from the scheme file
	local headerHeight = 0
	local footerHeight = 0

	-- Find HEADER_HEIGHT using pattern matching (allowing spaces around equals sign)
	local headerHeightMatch = schemeFileContent:match("HEADER_HEIGHT%s*=%s*(%d+)")
	if headerHeightMatch then
		local parsedHeight = tonumber(headerHeightMatch)
		if parsedHeight then
			headerHeight = parsedHeight
		else
			errorHandler.setError("HEADER_HEIGHT value is not a valid number")
			return false
		end
	else
		errorHandler.setError("Failed to find HEADER_HEIGHT in scheme file")
		return false
	end

	-- Find FOOTER_HEIGHT using pattern matching (allowing spaces around equals sign)
	local footerHeightMatch = schemeFileContent:match("FOOTER_HEIGHT%s*=%s*(%d+)")
	if footerHeightMatch then
		local parsedHeight = tonumber(footerHeightMatch)
		if parsedHeight then
			footerHeight = parsedHeight
		else
			errorHandler.setError("FOOTER_HEIGHT value is not a valid number")
			return false
		end
	else
		errorHandler.setError("Failed to find FOOTER_HEIGHT in scheme file")
		return false
	end

	-- Calculate content height (screen height minus header and footer heights)
	local contentHeight = screenHeight - headerHeight - footerHeight

	-- Replace content-height placeholder
	local contentHeightCount
	schemeFileContent, contentHeightCount = schemeFileContent:gsub("%%{%s*content%-height%s*}", tostring(contentHeight))
	if contentHeightCount == 0 then
		errorHandler.setError("Failed to replace content height settings in template")
		return false
	end

	-- Write the updated content back to the file
	schemeFile, err = io.open(schemeFilePath, "w")
	if not schemeFile then
		errorHandler.setError("Failed to write file for content height settings (" .. schemeFilePath .. "): " .. err)
		return false
	end

	schemeFile:write(schemeFileContent)
	schemeFile:close()
	return true
end

-- Function to save image data as a 24-bit BMP file
-- Currently LÖVE does not support encoding BMP
-- TODO: Consider using https://github.com/max1220/lua-bitmap
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
		for _ = 1, bytes do
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
			local r, g, b, _ = imageData:getPixel(x, y)
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

-- Function to create boot logo image shown during boot
local function createBootImage()
	local width, height = state.screenWidth, state.screenHeight
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	-- Load muOS logo SVG, set size and color
	local svg = love.filesystem.read("assets/muOS/logo.svg")
	local iconSize = 180
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
		errorHandler.setError("Failed to save BMP file: " .. paths.THEME_BOOTLOGO_IMAGE_PATH)
		return false
	end

	return true
end

-- Function to create reboot image shown during reboot
local function createRebootImage()
	-- Read properties from state
	local screenWidth, screenHeight = state.screenWidth, state.screenHeight
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	-- Load reboot icon SVG, set size and color
	local svg = love.filesystem.read("assets/icons/rotate-ccw.svg")
	if not svg then
		errorHandler.setError("Failed to load reboot icon SVG file: " .. paths.THEME_REBOOT_ICON_SVG_PATH)
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
	-- TODO: Refactor font code – Store fonts as pairs of name and loaded font
	-- (or find way to get name from loaded font)
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

	-- Set the font, size and color
	love.graphics.setFont(font, constants.IMAGE_FONT_SIZE)
	love.graphics.setColor(fgColor)

	-- Draw the text centered
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

	-- Write the PNG data to the reboot image file
	local rebootImageFile = io.open(paths.THEME_REBOOT_IMAGE_PATH, "wb")
	if not rebootImageFile then
		errorHandler.setError("Failed to open reboot image file: " .. paths.THEME_REBOOT_IMAGE_PATH)
		return false
	end
	local success, writeErr = pcall(function()
		rebootImageFile:write(pngData:getString())
	end)
	rebootImageFile:close()

	if not success then
		errorHandler.setError("Failed to write reboot image data: " .. tostring(writeErr))
		return false
	end

	return true
end

-- Function to create `credits.txt` file containing the theme's credits
local function createCreditsFile()
	local creditsFile = io.open(paths.THEME_CREDITS_PATH, "w")
	if not creditsFile then
		errorHandler.setError("Failed to create `credits.txt` file: " .. paths.THEME_CREDITS_PATH)
		return false
	end
	local creditsText = "Created using Aesthetic for muOS: https://github.com/joneavila/aesthetic"
	creditsFile:write(creditsText)
	creditsFile:close()
	return true
end

-- Function to create `version.txt` file containing the compatible muOS version
local function createVersionFile()
	local sourceFile = io.open(paths.MUOS_VERSION_PATH, "r")
	local versionContent = ""

	if sourceFile then
		-- Read the content from the source file
		local content = sourceFile:read("*all")
		sourceFile:close()

		-- Extract just the version number using pattern matching
		-- Pattern matches: digits with zero or more periods followed by underscore
		local versionNumber = content:match("(%d[%d%.]+)_")

		if versionNumber then
			versionContent = versionNumber
		else
			errorHandler.setError("Could not parse version number from muOS version file")
			return false
		end
	else
		errorHandler.setError("Could not read muOS version file at " .. paths.MUOS_VERSION_PATH)
		return false
	end

	-- Write to the theme version file
	local versionFile = io.open(paths.THEME_VERSION_PATH, "w")
	if not versionFile then
		errorHandler.setError("Failed to create `version.txt` file: " .. paths.THEME_VERSION_PATH)
		return false
	end
	versionFile:write(versionContent)
	versionFile:close()
	return true
end

-- Function to find and copy the selected font file to theme directory based on screen height
local function copySelectedFont()
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

	-- For now, always use size 24 fonts
	local fontSizeDir = "24"

	-- Copy the selected font file as default.bin
	local fontSourcePath = paths.THEME_FONT_SOURCE_DIR .. "/" .. fontSizeDir .. "/" .. selectedFontFile
	if
		not system.copyFile(
			fontSourcePath,
			paths.THEME_DEFAULT_FONT_PATH,
			"Failed to copy font file: " .. selectedFontFile .. " (size " .. fontSizeDir .. ")"
		)
	then
		return false
	end

	return true
end

-- Main function to create theme
function themeCreator.createTheme()
	local status, err = xpcall(function()
		-- Clean up and prepare working directory
		system.removeDir(paths.WORKING_THEME_DIR)
		system.ensurePath(paths.WORKING_THEME_DIR)

		-- Copy glyph directory and contents
		if not system.copyDir(paths.THEME_GLYPH_SOURCE_PATH, paths.THEME_GLYPH_PATH) then
			errorHandler.setError("Failed to copy glyph directory")
			return false
		end

		-- Copy scheme directory and contents
		if not system.copyDir(paths.THEME_SCHEME_SOURCE_DIR, paths.THEME_SCHEME_DIR) then
			errorHandler.setError("Failed to copy scheme directory")
			return false
		end

		-- Ensure all required directories exist
		for _, path in pairs(paths) do
			if type(path) == "string" then
				if not system.ensurePath(path) then
					return false
				end
			end
		end

		-- Create theme's boot image
		if not createBootImage() then
			return false
		end

		-- Create theme's reboot image
		if not createRebootImage() then
			return false
		end

		-- Create theme's preview image
		if not createPreviewImage() then
			return false
		end

		-- Get hex colors from state (remove # prefix)
		local colorReplacementts = {
			background = state.getColorValue("background"):gsub("^#", ""),
			foreground = state.getColorValue("foreground"):gsub("^#", ""),
		}

		-- Replace colors and apply glyph settings to theme files
		if not system.replaceColor(paths.THEME_SCHEME_GLOBAL_PATH, colorReplacementts) then
			return false
		end

		-- Set theme's glyph settings
		if not applyGlyphSettings(paths.THEME_SCHEME_GLOBAL_PATH) then
			errorHandler.setError("Failed to apply glyph settings to: " .. paths.THEME_SCHEME_GLOBAL_PATH)
			return false
		end

		-- Set theme's screen width settings
		if not applyScreenWidthSettings(paths.THEME_SCHEME_GLOBAL_PATH, state.screenWidth) then
			errorHandler.setError("Failed to apply screen width settings to: " .. paths.THEME_SCHEME_GLOBAL_PATH)
			return false
		end

		-- Set theme's content height settings
		if not applyContentHeightSettings(paths.THEME_SCHEME_GLOBAL_PATH, state.screenHeight) then
			errorHandler.setError("Failed to apply content height settings to: " .. paths.THEME_SCHEME_GLOBAL_PATH)
			return false
		end

		-- Copy the selected font file
		if not copySelectedFont() then
			return false
		end

		-- Create theme's `credits.txt` file
		if not createCreditsFile() then
			return false
		end

		-- Create theme's `version.txt` file
		if not createVersionFile() then
			return false
		end

		-- Create theme's `name.txt` file
		if not createNameFile() then
			return false
		end

		-- Create the ZIP archive
		local outputThemePath = system.createArchive(paths.WORKING_THEME_DIR, paths.THEME_OUTPUT_PATH)
		if not outputThemePath then
			return false
		end

		-- Call sync to make the theme available
		commands.executeCommand("sync")

		return outputThemePath
	end, debug.traceback)

	if not status then
		errorHandler.setError(tostring(err))
		return false
	end

	-- Return the path from the successful execution
	return err
end

-- Function to install the theme to muOS active theme directory
-- TODO: Reference new PIXIE code to update and fix bugs
function themeCreator.installTheme(themeName)
	local status, err = xpcall(function()
		local cmd = string.format('/opt/muos/script/package/theme.sh install "%s"', themeName)
		commands.executeCommand(cmd)
	end, debug.traceback)

	return status, err
end

-- Clean up working directory
function themeCreator.cleanup()
	system.removeDir(paths.WORKING_THEME_DIR)
end

return themeCreator
