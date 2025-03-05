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
definitions:insert("red700", color(0.757, -0.062, 0.029, 1, "Red"))
definitions:insert("orange700", color(0.792, 0.207, -0.096, 1, "Orange"))
definitions:insert("amber700", color(0.732, 0.301, -0.104, 1, "Amber"))
definitions:insert("yellow700", color(0.651, 0.373, -0.107, 1, "Yellow"))
definitions:insert("lime700", color(0.285, 0.492, -0.083, 1, "Lime"))
definitions:insert("green700", color(-0.090, 0.510, 0.210, 1, "Green"))
definitions:insert("emerald700", color(-0.123, 0.478, 0.334, 1, "Emerald"))
definitions:insert("teal700", color(-0.094, 0.469, 0.435, 1, "Teal"))
definitions:insert("cyan700", color(-0.103, 0.459, 0.583, 1, "Cyan"))
definitions:insert("sky700", color(-0.111, 0.412, 0.660, 1, "Sky"))
definitions:insert("blue700", color(0.078, 0.279, 0.902, 1, "Blue"))
definitions:insert("indigo700", color(0.264, 0.177, 0.845, 1, "Indigo"))
definitions:insert("violet700", color(0.440, 0.031, 0.906, 1, "Violet"))
definitions:insert("purple700", color(0.510, -0.026, 0.857, 1, "Purple"))
definitions:insert("fuchsia700", color(0.658, -0.073, 0.718, 1, "Fuchsia"))
definitions:insert("pink700", color(0.778, -0.093, 0.359, 1, "Pink"))
definitions:insert("rose700", color(0.779, -0.115, 0.211, 1, "Rose"))
definitions:insert("slate700", color(0.194, 0.255, 0.343, 1, "Slate"))
definitions:insert("gray700", color(0.212, 0.255, 0.325, 1, "Gray"))
definitions:insert("zinc700", color(0.246, 0.246, 0.276, 1, "Zinc"))
definitions:insert("neutral700", color(0.250, 0.250, 0.250, 1, "Neutral"))
definitions:insert("stone700", color(0.268, 0.250, 0.232, 1, "Stone"))
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
colors.fg_dim = colors.slate700
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

-- Function to store custom color
colors.addCustomColor = function(self, r, g, b)
	local colorKey = "custom"

	-- Store the color values
	self[colorKey] = { r, g, b, 1 }
	self.names[colorKey] = self._custom_name

	-- Add to ordered keys if not already present
	if not self._has_custom then
		table.insert(self._ordered_keys, colorKey)
		self._has_custom = true
	end

	return colorKey
end

return colors
