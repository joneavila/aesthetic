--- Font definitions for the application
-- This module contains all font definitions and utilities used across the application

local love = require("love")
local logger = require("utils.logger")

local fonts = {}

-- Default selected font
fonts.defaultFontName = "Inter"
fonts.defaultFontSize = "Default"

-- Loaded font objects container
fonts.loaded = {}

-- Font name to font key mapping for easy lookup
fonts.nameToKey = {}

-- Available font sizes for selection
local BIN_FONT_SIZES = { 24, 28, 32 }

--- Calculate a scaled font size based on display dimensions
fonts.calculateFontSize = function(displayWidth, displayHeight, baseFontSize, minFontSize, maxFontSize)
	local displayDiagonal = math.sqrt(displayWidth ^ 2 + displayHeight ^ 2)
	local baseDisplayDiagonal = math.sqrt(640 ^ 2 + 480 ^ 2) -- ≈ 800
	local scalingFactor = displayDiagonal / baseDisplayDiagonal
	local scaledFontSize = baseFontSize * scalingFactor
	local clampedFontSize = math.max(minFontSize, math.min(scaledFontSize, maxFontSize))
	local roundedFontSize = math.floor(clampedFontSize + 0.5)
	return roundedFontSize
end

-- Get the closest available font size to the desired size
fonts.getClosestBinFontSize = function(desiredSize)
	local closestSize = BIN_FONT_SIZES[1]
	local minDifference = math.abs(desiredSize - closestSize)
	for _, size in ipairs(BIN_FONT_SIZES) do
		local difference = math.abs(desiredSize - size)
		if difference < minDifference then
			minDifference = difference
			closestSize = size
		end
	end
	logger.debug("Desired font size: %d, Selected font size: %d", desiredSize, closestSize)
	return tostring(closestSize)
end

-- Font available choices
fonts.themeDefinitions = {
	{
		name = "Inter",
		file = "inter.bin",
		path = "assets/fonts/inter/inter_24pt_semibold.ttf",
	},
	{
		name = "Nunito",
		file = "nunito.bin",
		path = "assets/fonts/nunito/nunito_bold.ttf",
	},
	{
		name = "JetBrains Mono",
		file = "jetbrains_mono.bin",
		path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
	},
	{
		name = "Cascadia Code",
		file = "cascadia_code.bin",
		path = "assets/fonts/cascadia_code/cascadia_code_bold.ttf",
	},
	{
		name = "Retro Pixel",
		file = "retro_pixel.bin",
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
		size = bodySize,
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
for key, def in pairs(fonts.uiDefinitions) do
	fonts.nameToKey[def.name] = key
end

-- Screen height to font size mapping
fonts.screenHeightMapping = {
	[768] = { fontSizeDir = "38", imageFontSize = 45 },
	[720] = { fontSizeDir = "36", imageFontSize = 42 },
	[576] = { fontSizeDir = "29", imageFontSize = 34 },
	[480] = { fontSizeDir = "24", imageFontSize = 28 },
}

-- Initialize font size options with dynamic calculation
fonts.themeFontSizeOptions = {} -- Will be populated in the init function

-- Function to set fonts based on screen dimensions
local function initializeFonts(screenWidth, screenHeight)
	logger.debug("Initializing fonts")

	-- Base font sizes for 640x480 display
	local defaultBaseSize = 24
	local largeBaseSize = 28
	local extraLargeBaseSize = 32

	local minFontSize = 16
	local maxFontSize = 40

	local defaultSize = fonts.calculateFontSize(screenWidth, screenHeight, defaultBaseSize, minFontSize, maxFontSize)
	local largeSize = fonts.calculateFontSize(screenWidth, screenHeight, largeBaseSize, minFontSize, maxFontSize)
	local extraLargeSize =
		fonts.calculateFontSize(screenWidth, screenHeight, extraLargeBaseSize, minFontSize, maxFontSize)

	fonts.themeFontSizeOptions = {
		["Default"] = fonts.getClosestBinFontSize(defaultSize),
		["Large"] = fonts.getClosestBinFontSize(largeSize),
		["Extra Large"] = fonts.getClosestBinFontSize(extraLargeSize),
	}

	for key, def in pairs(fonts.uiDefinitions) do
		local success, result = pcall(function()
			return love.graphics.newFont(def.path, def.size)
		end)

		if success then
			fonts.loaded[key] = result
			logger.debug("Font loaded: " .. key .. " from " .. def.path .. " size " .. def.size)
		else
			logger.error("Failed to load font: " .. key .. " - " .. tostring(result))
		end
	end

	fonts.setDefault()
end

-- Helper function to get font size info based on screen height
fonts.getFontSizeInfo = function(height)
	return fonts.screenHeightMapping[height]
end

-- Image font size based on screen height
fonts.getImageFontSize = function(screenHeight)
	local sizeInfo = fonts.getFontSizeInfo(screenHeight)
	return sizeInfo and sizeInfo.imageFontSize
end

-- Helper function to get a font by name
fonts.getByName = function(fontName)
	local fontKey = fonts.nameToKey[fontName]
	if fontKey and fonts.loaded[fontKey] then
		return fonts.loaded[fontKey]
	end
	local defaultFont = fonts.loaded.body
	return defaultFont
end

-- Helper function to set the default font
fonts.setDefault = function()
	if love and fonts.loaded.body then
		logger.debug("Default font set to body")
		love.graphics.setFont(fonts.loaded.body)
	else
		logger.error("Failed to set default font - body font not loaded")
	end
end

-- Helper function to check if a font is selected
fonts.isSelected = function(fontName, selectedFont)
	return fontName == (selectedFont or fonts.defaultFontName)
end

return fonts
