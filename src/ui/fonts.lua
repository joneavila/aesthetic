--- Font definitions for the application
-- This module contains all font definitions and utilities used across the application

local love = require("love")
local logger = require("utils.logger")

local fonts = {}

-- Default selected font
fonts.defaultFont = "Inter"
fonts.defaultFontSize = "Default"

-- Loaded font objects container
fonts.loaded = {}

-- Font name to font key mapping for easy lookup
fonts.nameToKey = {}

-- Font available choices
fonts.choices = {
	{
		name = "Inter",
		file = "inter.bin",
	},
	{
		name = "Nunito",
		file = "nunito.bin",
	},
	{
		name = "JetBrains Mono",
		file = "jetbrains_mono.bin",
	},
	{
		name = "Cascadia Code",
		file = "cascadia_code.bin",
	},
	{
		name = "Retro Pixel",
		file = "retro_pixel.bin",
	},
}

-- Note: Antialiasing should be set to 0 for pixelated fonts
-- Font definitions mapping
local bodySize = 22
fonts.definitions = {
	header = { name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 16 },
	body = { name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf", size = bodySize },
	bodyBold = { name = "Inter", path = "assets/fonts/inter/inter_24pt_extrabold.ttf", size = bodySize },
	caption = { name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 16 },
	monoTitle = { name = "JetBrains Mono", path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", size = 48 },
	monoHeader = {
		name = "JetBrains Mono",
		path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
		size = 32,
	},
	monoBody = {
		name = "JetBrains Mono",
		path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
		size = bodySize,
	},
	nunito = { name = "Nunito", path = "assets/fonts/nunito/nunito_bold.ttf", size = 24 },
	retroPixel = { name = "Retro Pixel", path = "assets/fonts/retro_pixel/retro_pixel_thick.ttf", size = bodySize },
	cascadiaCode = {
		name = "Cascadia Code",
		path = "assets/fonts/cascadia_code/cascadia_code_bold.ttf",
		size = bodySize,
	},
}

-- Screen height to font size mapping
fonts.screenHeightMapping = {
	[768] = { fontSizeDir = "38", imageFontSize = 45 },
	[720] = { fontSizeDir = "36", imageFontSize = 42 },
	[576] = { fontSizeDir = "29", imageFontSize = 34 },
	[480] = { fontSizeDir = "24", imageFontSize = 28 },
}

-- Font size options mapping
fonts.fontSizeOptions = {
	["Default"] = "24",
	["Large"] = "28",
	["Extra Large"] = "32",
}

-- Helper function to get font size info based on screen height
fonts.getFontSizeInfo = function(height)
	return fonts.screenHeightMapping[height]
end

-- Image font size based on screen height
fonts.getImageFontSize = function(screenHeight)
	local sizeInfo = fonts.getFontSizeInfo(screenHeight)
	return sizeInfo and sizeInfo.imageFontSize
end

-- Function to get font size dir based on font size setting
fonts.getFontSizeDir = function(fontSize)
	return fonts.fontSizeOptions[fontSize] or "24" -- Default to 24 if not found
end

-- Helper function to get a font by name
fonts.getByName = function(fontName)
	logger.debug("Getting font by name: " .. (fontName or "nil"))
	local fontKey = fonts.nameToKey[fontName]
	if fontKey and fonts.loaded[fontKey] then
		logger.debug("Found font by name: " .. fontName .. " -> " .. fontKey)
		return fonts.loaded[fontKey]
	end
	logger.debug("Font not found by name: " .. (fontName or "nil") .. ", returning default")
	return fonts.loaded.body -- Return default font if not found
end

-- Helper function to initialize font name to key mapping
fonts.initNameMapping = function()
	logger.debug("Initializing font name to key mapping")
	fonts.nameToKey = {}
	for key, def in pairs(fonts.definitions) do
		fonts.nameToKey[def.name] = key
		logger.debug("Font name mapping: " .. def.name .. " -> " .. key)
	end
end

-- Helper function to set the default font
fonts.setDefault = function()
	logger.debug("Setting default font")
	if love and fonts.loaded.body then
		logger.debug("Default font set to body")
		love.graphics.setFont(fonts.loaded.body)
	else
		logger.error("Failed to set default font - body font not loaded")
	end
end

-- Helper function to check if a font is selected
fonts.isSelected = function(fontName, selectedFont)
	return fontName == (selectedFont or fonts.defaultFont)
end

-- Load all fonts defined in fonts.definitions
fonts.loadFonts = function()
	logger.debug("Loading all fonts")
	for key, def in pairs(fonts.definitions) do
		logger.debug("Loading font: " .. key .. " from " .. def.path .. " size " .. def.size)
		local success, result = pcall(function()
			return love.graphics.newFont(def.path, def.size)
		end)

		if success then
			fonts.loaded[key] = result
			logger.debug("Font loaded: " .. key)
		else
			logger.error("Failed to load font: " .. key .. " - " .. tostring(result))
		end
	end
	-- Initialize the name to key mapping after loading fonts
	fonts.initNameMapping()
end

return fonts
