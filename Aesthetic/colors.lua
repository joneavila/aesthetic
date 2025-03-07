--- Color management module

local OrderedDict = require("utils.ordereddict")
local colors = {}

-- Helper function to create a color entry with RGB values and display name
local function color(r, g, b, a, name)
	return {
		value = { r, g, b, a or 1 },
		name = name,
	}
end

-- Color definitions with their RGB values and display names
-- Colors adapted from Tailwind colors: https://tailwindcss.com/docs/colors
local definitions = OrderedDict.new()

-- Add colors in desired order
-- Colors can still be referenced by their name

-- `600` shades
definitions:insert("red600", color(0.906, -0.096, 0.042, 1, "Red"))
definitions:insert("orange600", color(0.961, 0.288, -0.154, 1, "Orange"))
definitions:insert("amber600", color(0.884, 0.443, -0.170, 1, "Amber"))
definitions:insert("yellow600", color(0.818, 0.530, -0.181, 1, "Yellow"))
definitions:insert("lime600", color(0.369, 0.647, -0.162, 1, "Lime"))
definitions:insert("green600", color(-0.166, 0.651, 0.242, 1, "Green"))
definitions:insert("emerald600", color(-0.175, 0.599, 0.399, 1, "Emerald"))
definitions:insert("teal600", color(-0.164, 0.589, 0.537, 1, "Teal"))
definitions:insert("cyan600", color(-0.171, 0.574, 0.723, 1, "Cyan"))
definitions:insert("sky600", color(-0.162, 0.518, 0.820, 1, "Sky"))
definitions:insert("blue600", color(0.084, 0.364, 0.986, 1, "Blue"))
definitions:insert("indigo600", color(0.311, 0.224, 0.966, 1, "Indigo"))
definitions:insert("violet600", color(0.500, 0.134, 0.996, 1, "Violet"))
definitions:insert("purple600", color(0.597, 0.062, 0.981, 1, "Purple"))
definitions:insert("fuchsia600", color(0.784, -0.111, 0.872, 1, "Fuchsia"))
definitions:insert("pink600", color(0.901, -0.092, 0.463, 1, "Pink"))
definitions:insert("rose600", color(0.927, -0.144, 0.249, 1, "Rose"))
definitions:insert("slate600", color(0.271, 0.334, 0.424, 1, "Slate"))
definitions:insert("gray600", color(0.289, 0.334, 0.396, 1, "Gray"))
definitions:insert("zinc600", color(0.321, 0.321, 0.362, 1, "Zinc"))
definitions:insert("neutral600", color(0.322, 0.322, 0.322, 1, "Neutral"))
definitions:insert("stone600", color(0.343, 0.325, 0.302, 1, "Stone"))

-- `200` shades
definitions:insert("red200", color(1.003, 0.790, 0.790, 1, "Red"))
definitions:insert("orange200", color(1.000, 0.841, 0.657, 1, "Orange"))
definitions:insert("amber200", color(0.996, 0.901, 0.522, 1, "Amber"))
definitions:insert("yellow200", color(0.999, 0.941, 0.523, 1, "Yellow"))
definitions:insert("lime200", color(0.848, 0.978, 0.600, 1, "Lime"))
definitions:insert("green200", color(0.725, 0.971, 0.812, 1, "Green"))
definitions:insert("emerald200", color(0.644, 0.956, 0.813, 1, "Emerald"))
definitions:insert("teal200", color(0.587, 0.967, 0.895, 1, "Teal"))
definitions:insert("cyan200", color(0.637, 0.955, 0.992, 1, "Cyan"))
definitions:insert("sky200", color(0.722, 0.903, 0.997, 1, "Sky"))
definitions:insert("blue200", color(0.745, 0.859, 1.001, 1, "Blue"))
definitions:insert("indigo200", color(0.778, 0.823, 1.003, 1, "Indigo"))
definitions:insert("violet200", color(0.867, 0.838, 1.001, 1, "Violet"))
definitions:insert("purple200", color(0.915, 0.833, 1.005, 1, "Purple"))
definitions:insert("fuchsia200", color(0.964, 0.813, 1.001, 1, "Fuchsia"))
definitions:insert("pink200", color(0.988, 0.809, 0.911, 1, "Pink"))
definitions:insert("rose200", color(1.000, 0.801, 0.826, 1, "Rose"))
definitions:insert("slate200", color(0.886, 0.910, 0.943, 1, "Slate"))
definitions:insert("gray200", color(0.898, 0.906, 0.923, 1, "Gray"))
definitions:insert("zinc200", color(0.894, 0.894, 0.906, 1, "Zinc"))
definitions:insert("neutral200", color(0.898, 0.898, 0.898, 1, "Neutral"))
definitions:insert("stone200", color(0.907, 0.898, 0.893, 1, "Stone"))

definitions:insert("white", color(1.0, 1.0, 1.0, 1, "White"))
definitions:insert("black", color(0.0, 0.0, 0.0, 1, "Black"))

-- Create a table to store color names
colors.names = {}
for key, def in definitions:pairs() do
	colors[key] = def.value
	colors.names[key] = def.name
end

-- Store color keys in their defined order to maintain consistent UI display order
colors._ordered_keys = definitions:keys()

-- Semantic colors (used in the UI)
colors.fg = colors.white
colors.fg_dim = colors.slate600
colors.bg = colors.black

-- Helper function to convert a decimal number to a 2-digit hex string
local function decToHex(dec)
	local value = math.floor(math.max(0, math.min(255, dec * 255)))
	return string.format("%02X", value)
end

-- Convert RGB values to hex color code
function colors.toHex(colorKey)
	local colorValues = colors[colorKey]
	if not colorValues then
		return nil
	end

	local r = decToHex(colorValues[1])
	local g = decToHex(colorValues[2])
	local b = decToHex(colorValues[3])

	return "#" .. r .. g .. b
end

-- Single custom color storage
colors._custom_color = nil
colors._custom_name = "Custom"

-- Custom color storage for different color types
colors._custom_colors = {
	background = nil,
	foreground = nil,
}
colors._custom_name = "Custom"

-- Function to store custom color
colors.addCustomColor = function(self, r, g, b)
	-- Get the current color type from state
	local colorType = require("state").lastSelectedColorButton
	local colorKey = "custom_" .. colorType

	-- Store the color values
	self[colorKey] = { r, g, b, 1 }
	self.names[colorKey] = self._custom_name

	return colorKey
end

return colors
