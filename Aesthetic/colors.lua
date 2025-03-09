--- Color management module

local OrderedDict = require("utils.ordereddict")
local colors = {}

-- Helper function to create a color entry with normalized (0-1) RGB values
local function color(r, g, b, a)
	return { r, g, b, a or 1 }
end

-- Create separate color sets for the application UI, palette screen, and user selected colors
colors.ui = {}
colors.palette = {}
colors.user = {}

-- Colors are stored in their desired order
local paletteDefinitions = OrderedDict.new()
local uiDefinitions = OrderedDict.new()

-- Add UI colors
uiDefinitions:insert("foreground", color(0.804, 0.839, 0.957, 1)) -- Text
uiDefinitions:insert("background", color(0.118, 0.118, 0.18, 1)) -- Base
uiDefinitions:insert("surface", color(0.192, 0.196, 0.267, 1)) -- Surface 1
uiDefinitions:insert("subtext", color(0.651, 0.678, 0.784, 1)) -- Subtext 0
uiDefinitions:insert("accent", color(0.537, 0.706, 0.98, 1)) --  Blue

-- Add palette colors
-- Most palette colors are adapted from Tailwind colors: https://tailwindcss.com/docs/colors
paletteDefinitions:insert("white", color(1.0, 1.0, 1.0, 1))
paletteDefinitions:insert("monochrome300", color(0.700, 0.700, 0.700, 1))
paletteDefinitions:insert("monochrome400", color(0.600, 0.600, 0.600, 1))
paletteDefinitions:insert("monochrome500", color(0.500, 0.500, 0.500, 1))
paletteDefinitions:insert("monochrome600", color(0.400, 0.400, 0.400, 1))
paletteDefinitions:insert("monochrome700", color(0.300, 0.300, 0.300, 1))
paletteDefinitions:insert("monochrome800", color(0.200, 0.200, 0.200, 1))
paletteDefinitions:insert("black", color(0.0, 0.0, 0.0, 1))

paletteDefinitions:insert("red200", color(1.003, 0.790, 0.790, 1))
paletteDefinitions:insert("red300", color(1.010, 0.635, 0.636, 1))
paletteDefinitions:insert("red400", color(1.006, 0.391, 0.404, 1))
paletteDefinitions:insert("red500", color(0.983, 0.172, 0.213, 1))
paletteDefinitions:insert("red600", color(0.906, -0.096, 0.042, 1))
paletteDefinitions:insert("red700", color(0.757, -0.062, 0.029, 1))
paletteDefinitions:insert("red800", color(0.622, 0.029, 0.069, 1))
paletteDefinitions:insert("red900", color(0.509, 0.092, 0.101, 1))

paletteDefinitions:insert("orange200", color(1.000, 0.841, 0.657, 1))
paletteDefinitions:insert("orange300", color(1.011, 0.722, 0.414, 1))
paletteDefinitions:insert("orange400", color(1.012, 0.537, 0.014, 1))
paletteDefinitions:insert("orange500", color(1.019, 0.411, -0.166, 1))
paletteDefinitions:insert("orange600", color(0.961, 0.288, -0.154, 1))
paletteDefinitions:insert("orange700", color(0.792, 0.207, -0.096, 1))
paletteDefinitions:insert("orange800", color(0.624, 0.177, -0.004, 1))
paletteDefinitions:insert("orange900", color(0.495, 0.165, 0.046, 1))

paletteDefinitions:insert("amber200", color(0.996, 0.901, 0.522, 1))
paletteDefinitions:insert("amber300", color(1.003, 0.824, 0.188, 1))
paletteDefinitions:insert("amber400", color(1.000, 0.727, -0.230, 1))
paletteDefinitions:insert("amber500", color(0.994, 0.602, -0.218, 1))
paletteDefinitions:insert("amber600", color(0.884, 0.443, -0.170, 1))
paletteDefinitions:insert("amber700", color(0.732, 0.301, -0.104, 1))
paletteDefinitions:insert("amber800", color(0.590, 0.234, -0.031, 1))
paletteDefinitions:insert("amber900", color(0.480, 0.200, 0.025, 1))

paletteDefinitions:insert("yellow200", color(0.999, 0.941, 0.523, 1))
paletteDefinitions:insert("yellow300", color(1.004, 0.876, 0.126, 1))
paletteDefinitions:insert("yellow400", color(0.993, 0.782, -0.269, 1))
paletteDefinitions:insert("yellow500", color(0.941, 0.693, -0.232, 1))
paletteDefinitions:insert("yellow600", color(0.818, 0.530, -0.181, 1))
paletteDefinitions:insert("yellow700", color(0.651, 0.373, -0.107, 1))
paletteDefinitions:insert("yellow800", color(0.536, 0.293, -0.038, 1))
paletteDefinitions:insert("yellow900", color(0.450, 0.242, 0.041, 1))

paletteDefinitions:insert("lime200", color(0.848, 0.978, 0.600, 1))
paletteDefinitions:insert("lime300", color(0.733, 0.955, 0.318, 1))
paletteDefinitions:insert("lime400", color(0.602, 0.902, -0.188, 1))
paletteDefinitions:insert("lime500", color(0.487, 0.810, -0.209, 1))
paletteDefinitions:insert("lime600", color(0.369, 0.647, -0.162, 1))
paletteDefinitions:insert("lime700", color(0.285, 0.492, -0.083, 1))
paletteDefinitions:insert("lime800", color(0.237, 0.388, -0.002, 1))
paletteDefinitions:insert("lime900", color(0.207, 0.327, 0.055, 1))

paletteDefinitions:insert("green200", color(0.725, 0.971, 0.812, 1))
paletteDefinitions:insert("green300", color(0.481, 0.946, 0.657, 1))
paletteDefinitions:insert("green400", color(0.020, 0.875, 0.449, 1))
paletteDefinitions:insert("green500", color(-0.194, 0.787, 0.316, 1))
paletteDefinitions:insert("green600", color(-0.166, 0.651, 0.242, 1))
paletteDefinitions:insert("green700", color(-0.090, 0.510, 0.210, 1))
paletteDefinitions:insert("green800", color(0.006, 0.401, 0.189, 1))
paletteDefinitions:insert("green900", color(0.051, 0.329, 0.170, 1))

paletteDefinitions:insert("emerald200", color(0.644, 0.956, 0.813, 1))
paletteDefinitions:insert("emerald300", color(0.370, 0.915, 0.709, 1))
paletteDefinitions:insert("emerald400", color(-0.194, 0.833, 0.572, 1))
paletteDefinitions:insert("emerald500", color(-0.217, 0.739, 0.489, 1))
paletteDefinitions:insert("emerald600", color(-0.175, 0.599, 0.399, 1))
paletteDefinitions:insert("emerald700", color(-0.123, 0.478, 0.334, 1))
paletteDefinitions:insert("emerald800", color(-0.065, 0.378, 0.271, 1))
paletteDefinitions:insert("emerald900", color(-0.011, 0.308, 0.230, 1))

paletteDefinitions:insert("teal200", color(0.587, 0.967, 0.895, 1))
paletteDefinitions:insert("teal300", color(0.276, 0.927, 0.834, 1))
paletteDefinitions:insert("teal400", color(-0.222, 0.835, 0.743, 1))
paletteDefinitions:insert("teal500", color(-0.212, 0.733, 0.655, 1))
paletteDefinitions:insert("teal600", color(-0.164, 0.589, 0.537, 1))
paletteDefinitions:insert("teal700", color(-0.094, 0.469, 0.435, 1))
paletteDefinitions:insert("teal800", color(-0.027, 0.373, 0.352, 1))
paletteDefinitions:insert("teal900", color(0.042, 0.308, 0.292, 1))

paletteDefinitions:insert("cyan200", color(0.637, 0.955, 0.992, 1))
paletteDefinitions:insert("cyan300", color(0.327, 0.917, 0.991, 1))
paletteDefinitions:insert("cyan400", color(-0.259, 0.827, 0.951, 1))
paletteDefinitions:insert("cyan500", color(-0.230, 0.722, 0.857, 1))
paletteDefinitions:insert("cyan600", color(-0.171, 0.574, 0.723, 1))
paletteDefinitions:insert("cyan700", color(-0.103, 0.459, 0.583, 1))
paletteDefinitions:insert("cyan800", color(-0.003, 0.371, 0.471, 1))
paletteDefinitions:insert("cyan900", color(0.064, 0.307, 0.394, 1))

paletteDefinitions:insert("sky200", color(0.722, 0.903, 0.997, 1))
paletteDefinitions:insert("sky300", color(0.453, 0.832, 1.008, 1))
paletteDefinitions:insert("sky400", color(-0.131, 0.736, 1.004, 1))
paletteDefinitions:insert("sky500", color(-0.203, 0.650, 0.957, 1))
paletteDefinitions:insert("sky600", color(-0.162, 0.518, 0.820, 1))
paletteDefinitions:insert("sky700", color(-0.111, 0.412, 0.660, 1))
paletteDefinitions:insert("sky800", color(-0.062, 0.349, 0.540, 1))
paletteDefinitions:insert("sky900", color(0.007, 0.290, 0.441, 1))

paletteDefinitions:insert("blue200", color(0.745, 0.859, 1.001, 1))
paletteDefinitions:insert("blue300", color(0.557, 0.773, 1.015, 1))
paletteDefinitions:insert("blue400", color(0.316, 0.636, 1.021, 1))
paletteDefinitions:insert("blue500", color(0.169, 0.498, 1.023, 1))
paletteDefinitions:insert("blue600", color(0.084, 0.364, 0.986, 1))
paletteDefinitions:insert("blue700", color(0.078, 0.279, 0.902, 1))
paletteDefinitions:insert("blue800", color(0.100, 0.234, 0.723, 1))
paletteDefinitions:insert("blue900", color(0.109, 0.222, 0.558, 1))

paletteDefinitions:insert("indigo200", color(0.778, 0.823, 1.003, 1))
paletteDefinitions:insert("indigo300", color(0.639, 0.702, 1.014, 1))
paletteDefinitions:insert("indigo400", color(0.488, 0.527, 1.017, 1))
paletteDefinitions:insert("indigo500", color(0.382, 0.372, 1.008, 1))
paletteDefinitions:insert("indigo600", color(0.311, 0.224, 0.966, 1))
paletteDefinitions:insert("indigo700", color(0.264, 0.177, 0.845, 1))
paletteDefinitions:insert("indigo800", color(0.215, 0.163, 0.674, 1))
paletteDefinitions:insert("indigo900", color(0.192, 0.173, 0.523, 1))

paletteDefinitions:insert("violet200", color(0.867, 0.838, 1.001, 1))
paletteDefinitions:insert("violet300", color(0.770, 0.704, 1.014, 1))
paletteDefinitions:insert("violet400", color(0.653, 0.517, 1.021, 1))
paletteDefinitions:insert("violet500", color(0.556, 0.318, 1.028, 1))
paletteDefinitions:insert("violet600", color(0.500, 0.134, 0.996, 1))
paletteDefinitions:insert("violet700", color(0.440, 0.031, 0.906, 1))
paletteDefinitions:insert("violet800", color(0.365, 0.056, 0.753, 1))
paletteDefinitions:insert("violet900", color(0.302, 0.089, 0.604, 1))

paletteDefinitions:insert("purple200", color(0.915, 0.833, 1.005, 1))
paletteDefinitions:insert("purple300", color(0.854, 0.698, 1.017, 1))
paletteDefinitions:insert("purple400", color(0.760, 0.480, 1.026, 1))
paletteDefinitions:insert("purple500", color(0.678, 0.276, 1.027, 1))
paletteDefinitions:insert("purple600", color(0.597, 0.062, 0.981, 1))
paletteDefinitions:insert("purple700", color(0.510, -0.026, 0.857, 1))
paletteDefinitions:insert("purple800", color(0.430, 0.067, 0.691, 1))
paletteDefinitions:insert("purple900", color(0.351, 0.087, 0.545, 1))

paletteDefinitions:insert("fuchsia200", color(0.964, 0.813, 1.001, 1))
paletteDefinitions:insert("fuchsia300", color(0.955, 0.657, 1.007, 1))
paletteDefinitions:insert("fuchsia400", color(0.930, 0.418, 1.008, 1))
paletteDefinitions:insert("fuchsia500", color(0.884, 0.166, 0.985, 1))
paletteDefinitions:insert("fuchsia600", color(0.784, -0.111, 0.872, 1))
paletteDefinitions:insert("fuchsia700", color(0.658, -0.073, 0.718, 1))
paletteDefinitions:insert("fuchsia800", color(0.541, 0.005, 0.582, 1))
paletteDefinitions:insert("fuchsia900", color(0.448, 0.075, 0.470, 1))

paletteDefinitions:insert("pink200", color(0.988, 0.809, 0.911, 1))
paletteDefinitions:insert("pink300", color(0.994, 0.646, 0.837, 1))
paletteDefinitions:insert("pink400", color(0.986, 0.392, 0.714, 1))
paletteDefinitions:insert("pink500", color(0.966, 0.198, 0.604, 1))
paletteDefinitions:insert("pink600", color(0.901, -0.092, 0.463, 1))
paletteDefinitions:insert("pink700", color(0.778, -0.093, 0.359, 1))
paletteDefinitions:insert("pink800", color(0.639, -0.017, 0.298, 1))
paletteDefinitions:insert("pink900", color(0.525, 0.063, 0.261, 1))

paletteDefinitions:insert("rose200", color(1.000, 0.801, 0.826, 1))
paletteDefinitions:insert("rose300", color(1.014, 0.630, 0.680, 1))
paletteDefinitions:insert("rose400", color(1.016, 0.389, 0.494, 1))
paletteDefinitions:insert("rose500", color(1.003, 0.125, 0.339, 1))
paletteDefinitions:insert("rose600", color(0.927, -0.144, 0.249, 1))
paletteDefinitions:insert("rose700", color(0.779, -0.115, 0.211, 1))
paletteDefinitions:insert("rose800", color(0.647, -0.047, 0.212, 1))
paletteDefinitions:insert("rose900", color(0.545, 0.030, 0.211, 1))

paletteDefinitions:insert("slate200", color(0.886, 0.910, 0.943, 1))
paletteDefinitions:insert("slate300", color(0.792, 0.836, 0.888, 1))
paletteDefinitions:insert("slate400", color(0.565, 0.632, 0.725, 1))
paletteDefinitions:insert("slate500", color(0.384, 0.455, 0.557, 1))
paletteDefinitions:insert("slate600", color(0.271, 0.334, 0.424, 1))
paletteDefinitions:insert("slate700", color(0.194, 0.255, 0.343, 1))
paletteDefinitions:insert("slate800", color(0.112, 0.160, 0.239, 1))
paletteDefinitions:insert("slate900", color(0.057, 0.090, 0.169, 1))

paletteDefinitions:insert("gray200", color(0.898, 0.906, 0.923, 1))
paletteDefinitions:insert("gray300", color(0.819, 0.836, 0.861, 1))
paletteDefinitions:insert("gray400", color(0.600, 0.631, 0.685, 1))
paletteDefinitions:insert("gray500", color(0.415, 0.447, 0.510, 1))
paletteDefinitions:insert("gray600", color(0.289, 0.334, 0.396, 1))
paletteDefinitions:insert("gray700", color(0.212, 0.255, 0.325, 1))
paletteDefinitions:insert("gray800", color(0.117, 0.161, 0.222, 1))
paletteDefinitions:insert("gray900", color(0.065, 0.094, 0.157, 1))

paletteDefinitions:insert("zinc200", color(0.894, 0.894, 0.906, 1))
paletteDefinitions:insert("zinc300", color(0.831, 0.831, 0.848, 1))
paletteDefinitions:insert("zinc400", color(0.623, 0.623, 0.663, 1))
paletteDefinitions:insert("zinc500", color(0.443, 0.443, 0.484, 1))
paletteDefinitions:insert("zinc600", color(0.321, 0.321, 0.362, 1))
paletteDefinitions:insert("zinc700", color(0.246, 0.246, 0.276, 1))
paletteDefinitions:insert("zinc800", color(0.153, 0.153, 0.166, 1))
paletteDefinitions:insert("zinc900", color(0.094, 0.094, 0.106, 1))

paletteDefinitions:insert("neutral200", color(0.898, 0.898, 0.898, 1))
paletteDefinitions:insert("neutral300", color(0.831, 0.831, 0.831, 1))
paletteDefinitions:insert("neutral400", color(0.630, 0.630, 0.630, 1))
paletteDefinitions:insert("neutral500", color(0.452, 0.452, 0.452, 1))
paletteDefinitions:insert("neutral600", color(0.322, 0.322, 0.322, 1))
paletteDefinitions:insert("neutral700", color(0.250, 0.250, 0.250, 1))
paletteDefinitions:insert("neutral800", color(0.149, 0.149, 0.149, 1))
paletteDefinitions:insert("neutral900", color(0.091, 0.091, 0.091, 1))

paletteDefinitions:insert("stone200", color(0.907, 0.898, 0.893, 1))
paletteDefinitions:insert("stone300", color(0.841, 0.828, 0.818, 1))
paletteDefinitions:insert("stone400", color(0.652, 0.626, 0.609, 1))
paletteDefinitions:insert("stone500", color(0.473, 0.442, 0.420, 1))
paletteDefinitions:insert("stone600", color(0.343, 0.325, 0.302, 1))
paletteDefinitions:insert("stone700", color(0.268, 0.250, 0.232, 1))
paletteDefinitions:insert("stone800", color(0.162, 0.144, 0.140, 1))
paletteDefinitions:insert("stone900", color(0.110, 0.098, 0.090, 1))

-- Store colors in their respective tables
for key, value in uiDefinitions:pairs() do
	colors.ui[key] = value
end
for key, value in paletteDefinitions:pairs() do
	colors.palette[key] = value
end

-- Store color keys in their defined order
colors.ui._ordered_keys = uiDefinitions:keys()
colors.palette._ordered_keys = paletteDefinitions:keys()

-- Helper function to convert a decimal number to a 2-digit hex string
local function decToHex(dec)
	local value = math.floor(math.max(0, math.min(255, dec * 255)))
	return string.format("%02X", value)
end

-- Convert RGB values to hex color code
function colors.toHex(colorKey, colorSet)
	colorSet = colorSet or "palette" -- Default to palette if not specified
	local colorValues = colors[colorSet][colorKey]

	if not colorValues then
		-- Try the other color set if not found in the specified one
		local otherSet = colorSet == "palette" and "ui" or "palette"
		colorValues = colors[otherSet][colorKey]

		if not colorValues then
			return nil
		end
	end

	local r = decToHex(colorValues[1])
	local g = decToHex(colorValues[2])
	local b = decToHex(colorValues[3])

	return "#" .. r .. g .. b
end

-- Function to get a color by key from either set
function colors.get(key)
	if colors.palette[key] then
		return colors.palette[key]
	elseif colors.ui[key] then
		return colors.ui[key]
	end
	return nil
end

-- Metatable to allow direct access to colors from either set
setmetatable(colors, {
	__index = function(t, key)
		return t.get(key)
	end,
})

-- Custom color storage for different color types
colors._custom_colors = {
	background = nil,
	foreground = nil,
}

-- Function to store custom color
-- Colors are stored in the user table to display them across the UI
colors.addCustomColor = function(self, r, g, b)
	-- Get the current color type from state
	local colorType = require("state").lastSelectedColorButton

	local colorKey = "custom_" .. colorType
	self.user[colorKey] = { r, g, b, 1 }
	return colorKey
end

return colors
