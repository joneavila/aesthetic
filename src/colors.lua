--- Color management module

local colorUtils = require("src.utils.color")

local colors = {}

-- UI colors (named)
colors.ui = {
	foreground = colorUtils.hexToLove("#ccd6f4"), -- Text
	background = colorUtils.hexToLove("#1e1e2e"), -- Base
	surface = colorUtils.hexToLove("#45477a"), -- Surface 1
	subtext = colorUtils.hexToLove("#a6adc8"), -- Subtext 0
	overlay = colorUtils.hexToLove("#6c7086"), -- Overlay 0
	accent = colorUtils.hexToLove("#89b4fa"), -- Blue
	background_dim = colorUtils.hexToLove("#181825"), -- Mantle
	green = colorUtils.hexToLove("#a6e3a1"), -- Green
	red = colorUtils.hexToLove("#f38ba8"), -- Red
}

-- Palette colors (ordered array)
colors.palette = {
	colorUtils.hexToLove("#ffffff"), -- white
	colorUtils.hexToLove("#b3b3b3"), -- monochrome300
	colorUtils.hexToLove("#999999"), -- monochrome400
	colorUtils.hexToLove("#808080"), -- monochrome500
	colorUtils.hexToLove("#666666"), -- monochrome600
	colorUtils.hexToLove("#4d4d4d"), -- monochrome700
	colorUtils.hexToLove("#333333"), -- monochrome800
	colorUtils.hexToLove("#000000"), -- black
	-- ... (add more colors in the order you want them displayed)
}

return colors
