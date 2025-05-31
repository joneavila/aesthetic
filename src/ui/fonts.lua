--- Font definitions for the application
-- This module contains all font definitions and utilities used across the application

local love = require("love")
local logger = require("utils.logger")

local fonts = {}

-- Loaded font objects container
fonts.loaded = {}

-- Font name to font key mapping for easy lookup
fonts.nameToKey = {}

-- Font state
fonts.selectedFont = "Inter"
fonts.fontSize = "Default"

-- Theme font choices
fonts.themeDefinitions = {
	{
		name = "Inter",
		file = "inter_semibold_default.bin",
		path = "assets/fonts/inter/inter_24pt_semibold.ttf",
	},
	{
		name = "Nunito",
		file = "nunito_bold_default.bin",
		path = "assets/fonts/nunito/nunito_bold.ttf",
	},
	{
		name = "JetBrains Mono",
		file = "jetbrains_mono_bold_default.bin",
		path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
	},
	{
		name = "Cascadia Code",
		file = "cascadia_code_bold_default.bin",
		path = "assets/fonts/cascadia_code/cascadia_code_bold.ttf",
	},
	{
		name = "Retro Pixel",
		file = "retro_pixel_thick_default.bin",
		path = "assets/fonts/retro_pixel/retro_pixel_thick.ttf",
	},
}

-- Font definitions mapping
local bodySize = 22
fonts.uiDefinitions = {
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
		size = 22,
	},
	console = {
		name = "JetBrains Mono",
		path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
		size = 16,
	},
	error = { name = "JetBrains Mono", path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", size = 16 },
	nunito = { name = "Nunito", path = "assets/fonts/nunito/nunito_bold.ttf", size = 24 },
	retroPixel = { name = "Retro Pixel", path = "assets/fonts/retro_pixel/retro_pixel_thick.ttf", size = bodySize },
	cascadiaCode = {
		name = "Cascadia Code",
		path = "assets/fonts/cascadia_code/cascadia_code_bold.ttf",
		size = bodySize,
	},
}

fonts.nameToKey = {}
for key, def in pairs(fonts.themeDefinitions) do
	fonts.nameToKey[def.name] = key
end

-- Initialize font size options with dynamic calculation
fonts.themeFontSizeOptions = {} -- Will be populated in the init function

-- Function to set fonts based on screen dimensions
fonts.initializeFonts = function()
	logger.debug("Initializing fonts")

	fonts.themeFontSizeOptions = {
		["Default"] = 24,
		["Large"] = 28,
		["Extra Large"] = 32,
	}

	for key, def in pairs(fonts.uiDefinitions) do
		local success, result = pcall(function()
			return love.graphics.newFont(def.path, def.size)
		end)

		if success then
			fonts.loaded[key] = result
		else
			logger.error("Failed to load font: " .. key .. " - " .. tostring(result))
		end
	end

	fonts.setDefault()
end

-- Helper function to get a font by name
fonts.getByName = function(fontName)
	local fontKey = fonts.nameToKey[fontName]
	local font = nil
	if fontKey then
		font = fonts.loaded[fontKey]
	end

	if font then
		return font
	else
		-- Fallback to the default body font if the requested font is not found
		logger.warning("Font '" .. tostring(fontName) .. "' not found, using default body font.")
		return fonts.loaded.body
	end
end

-- Helper function to set the default font
fonts.setDefault = function()
	if love and fonts.loaded.body then
		love.graphics.setFont(fonts.loaded.body)
	else
		logger.error("Failed to set default font - body font not loaded")
	end
end

-- Helper function to get the selected font
fonts.getSelectedFont = function()
	return fonts.selectedFont
end

-- Helper function to set the selected font
fonts.setSelectedFont = function(fontName)
	fonts.selectedFont = fontName
end

-- Helper function to get the font size
fonts.getFontSize = function()
	return fonts.fontSize
end

-- Helper function to set the font size
fonts.setFontSize = function(fontSize)
	fonts.fontSize = fontSize
end

return fonts
