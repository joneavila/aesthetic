--- Font definitions for the application
-- This module contains font definitions used across the application

local state = require("state")

local fontDefs = {}

-- Font options
fontDefs.FONTS = {
	{
		name = "Inter",
		file = "inter.bin",
		selected = state.selectedFont == "Inter",
	},
	{
		name = "Nunito",
		file = "nunito.bin",
		selected = state.selectedFont == "Nunito",
	},
	{
		name = "JetBrains Mono",
		file = "jetbrains_mono.bin",
		selected = state.selectedFont == "JetBrains Mono",
	},
	{
		name = "Cascadia Code",
		file = "cascadia_code.bin",
		selected = state.selectedFont == "Cascadia Code",
	},
	{
		name = "Retro Pixel",
		file = "retro_pixel.bin",
		selected = state.selectedFont == "Retro Pixel",
	},
}

-- Screen height to font size mapping
fontDefs.SCREEN_HEIGHT_MAPPING = {
	[768] = { fontSizeDir = "38", imageFontSize = 45 },
	[720] = { fontSizeDir = "36", imageFontSize = 42 },
	[576] = { fontSizeDir = "29", imageFontSize = 34 },
	[480] = { fontSizeDir = "24", imageFontSize = 28 },
}

-- Helper function to get font size info based on screen height
fontDefs.getFontSizeInfo = function(height)
	local sizeInfo = fontDefs.SCREEN_HEIGHT_MAPPING[height]
	return sizeInfo
end

-- Image font size based on screen height
fontDefs.getImageFontSize = function()
	local sizeInfo = fontDefs.getFontSizeInfo(state.screenHeight)
	return sizeInfo and sizeInfo.imageFontSize
end

-- Function to get font size dir based on font size setting
fontDefs.getFontSizeDir = function(fontSize)
	-- Determine font size based on user setting
	local fontSizeDir = "24" -- Default font size
	if fontSize == "Large" then
		fontSizeDir = "28" -- "Large" font size
	elseif fontSize == "Extra Large" then
		fontSizeDir = "32" -- "Extra Large" font size
	end
	return fontSizeDir
end

return fontDefs
