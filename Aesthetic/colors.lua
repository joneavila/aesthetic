--- Color management module

local OrderedDict = require("utils.ordereddict")
local colors = {}

-- Helper function to create a color entry with RGB values
local function color(r, g, b, a)
	return { r, g, b, a or 1 }
end

-- Color definitions with their RGB values
-- Most colors are adapted from Tailwind colors: https://tailwindcss.com/docs/colors
local definitions = OrderedDict.new()

-- Add colors in desired order
definitions:insert("white", color(1.0, 1.0, 1.0, 1))
definitions:insert("monochrome300", color(0.700, 0.700, 0.700, 1))
definitions:insert("monochrome400", color(0.600, 0.600, 0.600, 1))
definitions:insert("monochrome500", color(0.500, 0.500, 0.500, 1))
definitions:insert("monochrome600", color(0.400, 0.400, 0.400, 1))
definitions:insert("monochrome700", color(0.300, 0.300, 0.300, 1))
definitions:insert("monochrome800", color(0.200, 0.200, 0.200, 1))
definitions:insert("black", color(0.0, 0.0, 0.0, 1))

definitions:insert("red200", color(1.003, 0.790, 0.790, 1))
definitions:insert("red300", color(1.010, 0.635, 0.636, 1))
definitions:insert("red400", color(1.006, 0.391, 0.404, 1))
definitions:insert("red500", color(0.983, 0.172, 0.213, 1))
definitions:insert("red600", color(0.906, -0.096, 0.042, 1))
definitions:insert("red700", color(0.757, -0.062, 0.029, 1))
definitions:insert("red800", color(0.622, 0.029, 0.069, 1))
definitions:insert("red900", color(0.509, 0.092, 0.101, 1))

definitions:insert("orange200", color(1.000, 0.841, 0.657, 1))
definitions:insert("orange300", color(1.011, 0.722, 0.414, 1))
definitions:insert("orange400", color(1.012, 0.537, 0.014, 1))
definitions:insert("orange500", color(1.019, 0.411, -0.166, 1))
definitions:insert("orange600", color(0.961, 0.288, -0.154, 1))
definitions:insert("orange700", color(0.792, 0.207, -0.096, 1))
definitions:insert("orange800", color(0.624, 0.177, -0.004, 1))
definitions:insert("orange900", color(0.495, 0.165, 0.046, 1))

definitions:insert("amber200", color(0.996, 0.901, 0.522, 1))
definitions:insert("amber300", color(1.003, 0.824, 0.188, 1))
definitions:insert("amber400", color(1.000, 0.727, -0.230, 1))
definitions:insert("amber500", color(0.994, 0.602, -0.218, 1))
definitions:insert("amber600", color(0.884, 0.443, -0.170, 1))
definitions:insert("amber700", color(0.732, 0.301, -0.104, 1))
definitions:insert("amber800", color(0.590, 0.234, -0.031, 1))
definitions:insert("amber900", color(0.480, 0.200, 0.025, 1))

definitions:insert("yellow200", color(0.999, 0.941, 0.523, 1))
definitions:insert("yellow300", color(1.004, 0.876, 0.126, 1))
definitions:insert("yellow400", color(0.993, 0.782, -0.269, 1))
definitions:insert("yellow500", color(0.941, 0.693, -0.232, 1))
definitions:insert("yellow600", color(0.818, 0.530, -0.181, 1))
definitions:insert("yellow700", color(0.651, 0.373, -0.107, 1))
definitions:insert("yellow800", color(0.536, 0.293, -0.038, 1))
definitions:insert("yellow900", color(0.450, 0.242, 0.041, 1))

definitions:insert("lime200", color(0.848, 0.978, 0.600, 1))
definitions:insert("lime300", color(0.733, 0.955, 0.318, 1))
definitions:insert("lime400", color(0.602, 0.902, -0.188, 1))
definitions:insert("lime500", color(0.487, 0.810, -0.209, 1))
definitions:insert("lime600", color(0.369, 0.647, -0.162, 1))
definitions:insert("lime700", color(0.285, 0.492, -0.083, 1))
definitions:insert("lime800", color(0.237, 0.388, -0.002, 1))
definitions:insert("lime900", color(0.207, 0.327, 0.055, 1))

definitions:insert("green200", color(0.725, 0.971, 0.812, 1))
definitions:insert("green300", color(0.481, 0.946, 0.657, 1))
definitions:insert("green400", color(0.020, 0.875, 0.449, 1))
definitions:insert("green500", color(-0.194, 0.787, 0.316, 1))
definitions:insert("green600", color(-0.166, 0.651, 0.242, 1))
definitions:insert("green700", color(-0.090, 0.510, 0.210, 1))
definitions:insert("green800", color(0.006, 0.401, 0.189, 1))
definitions:insert("green900", color(0.051, 0.329, 0.170, 1))

definitions:insert("emerald200", color(0.644, 0.956, 0.813, 1))
definitions:insert("emerald300", color(0.370, 0.915, 0.709, 1))
definitions:insert("emerald400", color(-0.194, 0.833, 0.572, 1))
definitions:insert("emerald500", color(-0.217, 0.739, 0.489, 1))
definitions:insert("emerald600", color(-0.175, 0.599, 0.399, 1))
definitions:insert("emerald700", color(-0.123, 0.478, 0.334, 1))
definitions:insert("emerald800", color(-0.065, 0.378, 0.271, 1))
definitions:insert("emerald900", color(-0.011, 0.308, 0.230, 1))

definitions:insert("teal200", color(0.587, 0.967, 0.895, 1))
definitions:insert("teal300", color(0.276, 0.927, 0.834, 1))
definitions:insert("teal400", color(-0.222, 0.835, 0.743, 1))
definitions:insert("teal500", color(-0.212, 0.733, 0.655, 1))
definitions:insert("teal600", color(-0.164, 0.589, 0.537, 1))
definitions:insert("teal700", color(-0.094, 0.469, 0.435, 1))
definitions:insert("teal800", color(-0.027, 0.373, 0.352, 1))
definitions:insert("teal900", color(0.042, 0.308, 0.292, 1))

definitions:insert("cyan200", color(0.637, 0.955, 0.992, 1))
definitions:insert("cyan300", color(0.327, 0.917, 0.991, 1))
definitions:insert("cyan400", color(-0.259, 0.827, 0.951, 1))
definitions:insert("cyan500", color(-0.230, 0.722, 0.857, 1))
definitions:insert("cyan600", color(-0.171, 0.574, 0.723, 1))
definitions:insert("cyan700", color(-0.103, 0.459, 0.583, 1))
definitions:insert("cyan800", color(-0.003, 0.371, 0.471, 1))
definitions:insert("cyan900", color(0.064, 0.307, 0.394, 1))

definitions:insert("sky200", color(0.722, 0.903, 0.997, 1))
definitions:insert("sky300", color(0.453, 0.832, 1.008, 1))
definitions:insert("sky400", color(-0.131, 0.736, 1.004, 1))
definitions:insert("sky500", color(-0.203, 0.650, 0.957, 1))
definitions:insert("sky600", color(-0.162, 0.518, 0.820, 1))
definitions:insert("sky700", color(-0.111, 0.412, 0.660, 1))
definitions:insert("sky800", color(-0.062, 0.349, 0.540, 1))
definitions:insert("sky900", color(0.007, 0.290, 0.441, 1))

definitions:insert("blue200", color(0.745, 0.859, 1.001, 1))
definitions:insert("blue300", color(0.557, 0.773, 1.015, 1))
definitions:insert("blue400", color(0.316, 0.636, 1.021, 1))
definitions:insert("blue500", color(0.169, 0.498, 1.023, 1))
definitions:insert("blue600", color(0.084, 0.364, 0.986, 1))
definitions:insert("blue700", color(0.078, 0.279, 0.902, 1))
definitions:insert("blue800", color(0.100, 0.234, 0.723, 1))
definitions:insert("blue900", color(0.109, 0.222, 0.558, 1))

definitions:insert("indigo200", color(0.778, 0.823, 1.003, 1))
definitions:insert("indigo300", color(0.639, 0.702, 1.014, 1))
definitions:insert("indigo400", color(0.488, 0.527, 1.017, 1))
definitions:insert("indigo500", color(0.382, 0.372, 1.008, 1))
definitions:insert("indigo600", color(0.311, 0.224, 0.966, 1))
definitions:insert("indigo700", color(0.264, 0.177, 0.845, 1))
definitions:insert("indigo800", color(0.215, 0.163, 0.674, 1))
definitions:insert("indigo900", color(0.192, 0.173, 0.523, 1))

definitions:insert("violet200", color(0.867, 0.838, 1.001, 1))
definitions:insert("violet300", color(0.770, 0.704, 1.014, 1))
definitions:insert("violet400", color(0.653, 0.517, 1.021, 1))
definitions:insert("violet500", color(0.556, 0.318, 1.028, 1))
definitions:insert("violet600", color(0.500, 0.134, 0.996, 1))
definitions:insert("violet700", color(0.440, 0.031, 0.906, 1))
definitions:insert("violet800", color(0.365, 0.056, 0.753, 1))
definitions:insert("violet900", color(0.302, 0.089, 0.604, 1))

definitions:insert("purple200", color(0.915, 0.833, 1.005, 1))
definitions:insert("purple300", color(0.854, 0.698, 1.017, 1))
definitions:insert("purple400", color(0.760, 0.480, 1.026, 1))
definitions:insert("purple500", color(0.678, 0.276, 1.027, 1))
definitions:insert("purple600", color(0.597, 0.062, 0.981, 1))
definitions:insert("purple700", color(0.510, -0.026, 0.857, 1))
definitions:insert("purple800", color(0.430, 0.067, 0.691, 1))
definitions:insert("purple900", color(0.351, 0.087, 0.545, 1))

definitions:insert("fuchsia200", color(0.964, 0.813, 1.001, 1))
definitions:insert("fuchsia300", color(0.955, 0.657, 1.007, 1))
definitions:insert("fuchsia400", color(0.930, 0.418, 1.008, 1))
definitions:insert("fuchsia500", color(0.884, 0.166, 0.985, 1))
definitions:insert("fuchsia600", color(0.784, -0.111, 0.872, 1))
definitions:insert("fuchsia700", color(0.658, -0.073, 0.718, 1))
definitions:insert("fuchsia800", color(0.541, 0.005, 0.582, 1))
definitions:insert("fuchsia900", color(0.448, 0.075, 0.470, 1))

definitions:insert("pink200", color(0.988, 0.809, 0.911, 1))
definitions:insert("pink300", color(0.994, 0.646, 0.837, 1))
definitions:insert("pink400", color(0.986, 0.392, 0.714, 1))
definitions:insert("pink500", color(0.966, 0.198, 0.604, 1))
definitions:insert("pink600", color(0.901, -0.092, 0.463, 1))
definitions:insert("pink700", color(0.778, -0.093, 0.359, 1))
definitions:insert("pink800", color(0.639, -0.017, 0.298, 1))
definitions:insert("pink900", color(0.525, 0.063, 0.261, 1))

definitions:insert("rose200", color(1.000, 0.801, 0.826, 1))
definitions:insert("rose300", color(1.014, 0.630, 0.680, 1))
definitions:insert("rose400", color(1.016, 0.389, 0.494, 1))
definitions:insert("rose500", color(1.003, 0.125, 0.339, 1))
definitions:insert("rose600", color(0.927, -0.144, 0.249, 1))
definitions:insert("rose700", color(0.779, -0.115, 0.211, 1))
definitions:insert("rose800", color(0.647, -0.047, 0.212, 1))
definitions:insert("rose900", color(0.545, 0.030, 0.211, 1))

definitions:insert("slate200", color(0.886, 0.910, 0.943, 1))
definitions:insert("slate300", color(0.792, 0.836, 0.888, 1))
definitions:insert("slate400", color(0.565, 0.632, 0.725, 1))
definitions:insert("slate500", color(0.384, 0.455, 0.557, 1))
definitions:insert("slate600", color(0.271, 0.334, 0.424, 1))
definitions:insert("slate700", color(0.194, 0.255, 0.343, 1))
definitions:insert("slate800", color(0.112, 0.160, 0.239, 1))
definitions:insert("slate900", color(0.057, 0.090, 0.169, 1))

definitions:insert("gray200", color(0.898, 0.906, 0.923, 1))
definitions:insert("gray300", color(0.819, 0.836, 0.861, 1))
definitions:insert("gray400", color(0.600, 0.631, 0.685, 1))
definitions:insert("gray500", color(0.415, 0.447, 0.510, 1))
definitions:insert("gray600", color(0.289, 0.334, 0.396, 1))
definitions:insert("gray700", color(0.212, 0.255, 0.325, 1))
definitions:insert("gray800", color(0.117, 0.161, 0.222, 1))
definitions:insert("gray900", color(0.065, 0.094, 0.157, 1))

definitions:insert("zinc200", color(0.894, 0.894, 0.906, 1))
definitions:insert("zinc300", color(0.831, 0.831, 0.848, 1))
definitions:insert("zinc400", color(0.623, 0.623, 0.663, 1))
definitions:insert("zinc500", color(0.443, 0.443, 0.484, 1))
definitions:insert("zinc600", color(0.321, 0.321, 0.362, 1))
definitions:insert("zinc700", color(0.246, 0.246, 0.276, 1))
definitions:insert("zinc800", color(0.153, 0.153, 0.166, 1))
definitions:insert("zinc900", color(0.094, 0.094, 0.106, 1))

definitions:insert("neutral200", color(0.898, 0.898, 0.898, 1))
definitions:insert("neutral300", color(0.831, 0.831, 0.831, 1))
definitions:insert("neutral400", color(0.630, 0.630, 0.630, 1))
definitions:insert("neutral500", color(0.452, 0.452, 0.452, 1))
definitions:insert("neutral600", color(0.322, 0.322, 0.322, 1))
definitions:insert("neutral700", color(0.250, 0.250, 0.250, 1))
definitions:insert("neutral800", color(0.149, 0.149, 0.149, 1))
definitions:insert("neutral900", color(0.091, 0.091, 0.091, 1))

definitions:insert("stone200", color(0.907, 0.898, 0.893, 1))
definitions:insert("stone300", color(0.841, 0.828, 0.818, 1))
definitions:insert("stone400", color(0.652, 0.626, 0.609, 1))
definitions:insert("stone500", color(0.473, 0.442, 0.420, 1))
definitions:insert("stone600", color(0.343, 0.325, 0.302, 1))
definitions:insert("stone700", color(0.268, 0.250, 0.232, 1))
definitions:insert("stone800", color(0.162, 0.144, 0.140, 1))
definitions:insert("stone900", color(0.110, 0.098, 0.090, 1))

-- Store colors directly in the colors table
for key, value in definitions:pairs() do
	colors[key] = value
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

-- Custom color storage for different color types
colors._custom_colors = {
	background = nil,
	foreground = nil,
}

-- Function to store custom color
colors.addCustomColor = function(self, r, g, b)
	-- Get the current color type from state
	local colorType = require("state").lastSelectedColorButton
	local colorKey = "custom_" .. colorType

	-- Store the color values
	self[colorKey] = { r, g, b, 1 }

	return colorKey
end

return colors
