--- Font definitions for the application
-- This module contains all font definitions and utilities used across the application

local love = require("love")

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
fonts.definitions = {
	header = { name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 32 },
	body = { name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 24 },
	bodyBold = { name = "Inter", path = "assets/fonts/inter/inter_24pt_extrabold.ttf", size = 24 },
	caption = { name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 20 },
	monoTitle = { name = "JetBrains Mono", path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", size = 48 },
	monoHeader = {
		name = "JetBrains Mono",
		path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
		size = 32,
	},
	monoBody = { name = "JetBrains Mono", path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", size = 24 },
	nunito = { name = "Nunito", path = "assets/fonts/nunito/nunito_bold.ttf", size = 24 },
	retroPixel = { name = "Retro Pixel", path = "assets/fonts/retro_pixel/retro_pixel_thick.ttf", size = 24 },
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
	local fontKey = fonts.nameToKey[fontName]
	if fontKey and fonts.loaded[fontKey] then
		return fonts.loaded[fontKey]
	end
	return fonts.loaded.body -- Return default font if not found
end

-- Helper function to initialize font name to key mapping
fonts.initNameMapping = function()
	fonts.nameToKey = {}
	for key, def in pairs(fonts.definitions) do
		fonts.nameToKey[def.name] = key
	end
end

-- Helper function to set the default font
fonts.setDefault = function()
	if love and fonts.loaded.body then
		love.graphics.setFont(fonts.loaded.body)
	end
end

-- Helper function to check if a font is selected
fonts.isSelected = function(fontName, selectedFont)
	return fontName == (selectedFont or fonts.defaultFont)
end

-- Load all fonts defined in fonts.definitions
fonts.loadFonts = function()
	for key, def in pairs(fonts.definitions) do
		fonts.loaded[key] = love.graphics.newFont(def.path, def.size)
	end
	-- Initialize the name to key mapping after loading fonts
	fonts.initNameMapping()
end

return fonts
