--- Color management module

local colors = {}

-- Helper function to create a color entry with normalized (0-1) RGB values
local function color(r, g, b, a)
	return { r, g, b, a or 1 }
end

-- UI colors (named)
colors.ui = {
	foreground = color(0.804, 0.839, 0.957, 1), -- Text
	background = color(0.118, 0.118, 0.18, 1), -- Base
	surface = color(0.271, 0.278, 0.353, 1), -- Surface 1
	subtext = color(0.651, 0.678, 0.784, 1), -- Subtext 0
	overlay = color(0.424, 0.439, 0.525, 1), -- Overlay 0
	accent = color(0.537, 0.706, 0.98, 1), -- Blue
	background_dim = color(0.094, 0.094, 0.145, 1), -- Mantle
	green = color(0.651, 0.89, 0.631, 1), -- Green
	red = color(0.953, 0.545, 0.659, 1), -- Red
}

-- Palette colors (ordered array)
colors.palette = {
	color(1.0, 1.0, 1.0, 1), -- white
	color(0.700, 0.700, 0.700, 1), -- monochrome300
	color(0.600, 0.600, 0.600, 1), -- monochrome400
	color(0.500, 0.500, 0.500, 1), -- monochrome500
	color(0.400, 0.400, 0.400, 1), -- monochrome600
	color(0.300, 0.300, 0.300, 1), -- monochrome700
	color(0.200, 0.200, 0.200, 1), -- monochrome800
	color(0.0, 0.0, 0.0, 1), -- black
	-- ... (add more colors in the order you want them displayed)
}

return colors
