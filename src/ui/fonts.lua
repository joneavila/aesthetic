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

-- Available font sizes for selection
local AVAILABLE_FONT_SIZES = { 24, 28, 32 }

--[[
  Calculates a scaled font size based on screen dimensions
  
  @param width - The width of the display in pixels
  @param height - The height of the display in pixels
  @param baseFontSize - The font size for the reference display (640x480)
  @param minFontSize - The minimum allowed font size
  @param maxFontSize - The maximum allowed font size
  @return - The calculated font size in pixels (rounded to nearest integer)
--]]
local function calculateFontSize(width, height, baseFontSize, minFontSize, maxFontSize)
	-- Calculate the diagonal length of the current display
	local diagonal = math.sqrt(width ^ 2 + height ^ 2)

	-- Calculate the diagonal length of the base display (640x480)
	local baseDiagonal = math.sqrt(640 ^ 2 + 480 ^ 2) -- ≈ 800

	-- Calculate the scaling factor
	local scalingFactor = diagonal / baseDiagonal

	-- Apply scaling factor to base font size
	local scaledFontSize = baseFontSize * scalingFactor

	-- Apply constraints to keep font size within desired range
	local finalFontSize = math.max(minFontSize, math.min(scaledFontSize, maxFontSize))

	-- Return the font size rounded to the nearest integer
	return math.floor(finalFontSize + 0.5)
end

-- Get the closest available font size to the desired size
local function getClosestFontSize(desiredSize)
	-- Log the desired font size for debugging
	logger.debug("Desired font size: " .. desiredSize)

	-- Find the closest available font size
	local closestSize = AVAILABLE_FONT_SIZES[1]
	local minDifference = math.abs(desiredSize - closestSize)

	for _, size in ipairs(AVAILABLE_FONT_SIZES) do
		local difference = math.abs(desiredSize - size)
		if difference < minDifference then
			minDifference = difference
			closestSize = size
		end
	end

	logger.debug("Selected closest available font size: " .. closestSize)
	return tostring(closestSize)
end

-- Calculate dynamic font sizes based on current display dimensions
local function calculateDynamicFontSizes()
	local width, height = love.graphics.getDimensions()

	-- Base font sizes for 640x480 display
	local defaultBaseSize = 24
	local largeBaseSize = 28
	local extraLargeBaseSize = 32

	-- Min and max constraints
	local minFontSize = 16
	local maxFontSize = 40

	-- Calculate the dynamic sizes
	local defaultSize = calculateFontSize(width, height, defaultBaseSize, minFontSize, maxFontSize)
	local largeSize = calculateFontSize(width, height, largeBaseSize, minFontSize, maxFontSize)
	local extraLargeSize = calculateFontSize(width, height, extraLargeBaseSize, minFontSize, maxFontSize)

	-- Get the closest available sizes
	return {
		["Default"] = getClosestFontSize(defaultSize),
		["Large"] = getClosestFontSize(largeSize),
		["Extra Large"] = getClosestFontSize(extraLargeSize),
	}
end

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
	error = { name = "JetBrains Mono", path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", size = 16 },
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

-- Initialize font size options with dynamic calculation
fonts.fontSizeOptions = {} -- Will be populated in the init function

-- Initialize font size options based on current display dimensions
fonts.initFontSizeOptions = function()
	fonts.fontSizeOptions = calculateDynamicFontSizes()
	logger.info(
		"Dynamic font sizes initialized: Default="
			.. fonts.fontSizeOptions["Default"]
			.. ", Large="
			.. fonts.fontSizeOptions["Large"]
			.. ", Extra Large="
			.. fonts.fontSizeOptions["Extra Large"]
	)
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
	-- Initialize font size options first
	fonts.initFontSizeOptions()

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
