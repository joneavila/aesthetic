-- Color utility module
local color = {}

-- Utility function to clamp a value between a minimum and maximum
local function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

local Color = {}
Color.__index = Color

-- Create a new Color instance
-- Parameters are the RGBA components (0-1)
function Color.new(r, g, b, a)
	return setmetatable({ r = r, g = g, b = b, a = a or 1 }, Color)
end

-- Convert color to HSL
-- Returns Hue (0-360), Saturation (0-100), and Lightness (0-100)
function Color:toHSL()
	local max = math.max(self.r, self.g, self.b)
	local min = math.min(self.r, self.g, self.b)
	local h, s, l

	-- Calculate lightness
	l = (max + min) / 2

	-- If max equals min, it is a shade of gray
	if max == min then
		h = 0
		s = 0
	else
		local d = max - min

		-- Calculate saturation
		s = l > 0.5 and d / (2 - max - min) or d / (max + min)

		-- Calculate hue
		if max == self.r then
			h = (self.g - self.b) / d + (self.g < self.b and 6 or 0)
		elseif max == self.g then
			h = (self.b - self.r) / d + 2
		else
			h = (self.r - self.g) / d + 4
		end
		h = h / 6
	end

	-- Convert to standard ranges
	return h * 360, s * 100, l * 100
end

-- Create a new Color from HSL values
-- Parameters are Hue (0-360), Saturation (0-100), and Lightness (0-100)
function Color.fromHSL(h, s, l)
	-- Normalize HSL values
	h = h / 360
	s = s / 100
	l = l / 100

	local function hue2rgb(p, q, t)
		if t < 0 then
			t = t + 1
		end
		if t > 1 then
			t = t - 1
		end
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		end
		if t < 1 / 2 then
			return q
		end
		if t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end

	local r, g, b

	if s == 0 then
		-- If saturation is 0, color is a shade of gray
		r, g, b = l, l, l
	else
		local q = l < 0.5 and l * (1 + s) or l + s - l * s
		local p = 2 * l - q

		r = hue2rgb(p, q, h + 1 / 3)
		g = hue2rgb(p, q, h)
		b = hue2rgb(p, q, h - 1 / 3)
	end

	return Color.new(r, g, b)
end

-- Calculate border color using Relative Luminance Border Algorithm
function Color:getBorderColor()
	local h, s, l = self:toHSL()

	-- Adjust saturation based on input color, reduce saturation but keep some color
	local newS = clamp(s * 0.8, 20, 80)

	-- Adjust lightness in opposite direction of input color
	local lightnessOffset = 30 -- Adjust this value to control contrast
	local newL = l > 50 and clamp(l - lightnessOffset, 20, 80) or clamp(l + lightnessOffset, 20, 80)

	-- Create new color from adjusted HSL values
	return Color.fromHSL(h, newS, newL)
end

-- Calculate a contrasting color using Hue Rotation with Lightness Adjustment
function Color:getContrastingColor()
	local h, s, l = self:toHSL()

	-- Rotate hue by 180 degrees (opposite on color wheel)
	local newH = (h + 180) % 360

	-- Adjust lightness for readability
	local newL
	if l > 50 then
		-- For light backgrounds, darken the foreground
		newL = clamp(l - 50, 10, 40)
	else
		-- For dark backgrounds, lighten the foreground
		newL = clamp(l + 50, 60, 90)
	end

	return Color.fromHSL(newH, s, newL)
end

-- Convert color to hex string
function Color:toHex()
	local r = math.floor(self.r * 255 + 0.5)
	local g = math.floor(self.g * 255 + 0.5)
	local b = math.floor(self.b * 255 + 0.5)
	return string.format("#%02X%02X%02X", r, g, b)
end

-- Create a new Color from hex string
function Color.fromHex(hex)
	-- Remove # if present
	hex = hex:gsub("^#", "")

	-- Convert hex to RGB
	local r = tonumber(hex:sub(1, 2), 16) / 255
	local g = tonumber(hex:sub(3, 4), 16) / 255
	local b = tonumber(hex:sub(5, 6), 16) / 255

	return Color.new(r, g, b)
end

-- Convert color to LÖVE-compatible array
function Color:toLove()
	return { self.r, self.g, self.b, self.a }
end

function color.rgbToHsl(r, g, b)
	local col = Color.new(r, g, b)
	return col:toHSL()
end

function color.hslToRgb(h, s, l)
	local col = Color.fromHSL(h, s, l)
	return col.r, col.g, col.b
end

function color.calculateBorderColor(r, g, b)
	local col = Color.new(r, g, b)
	local border = col:getBorderColor()
	return border.r, border.g, border.b
end

function color.calculateContrastingColor(r, g, b)
	local col = Color.new(r, g, b)
	local contrast = col:getContrastingColor()
	return contrast.r, contrast.g, contrast.b
end

-- Convert hex string to RGB values (0-1 range)
function color.hexToRgb(hexString)
	-- Remove # if present
	hexString = hexString:gsub("^#", "")

	-- Ensure we have a valid 6-character hex string
	if #hexString ~= 6 then
		return 1, 1, 1 -- Return white as fallback
	end

	-- Convert hex to RGB (0-1 range)
	local r = tonumber(hexString:sub(1, 2), 16) / 255
	local g = tonumber(hexString:sub(3, 4), 16) / 255
	local b = tonumber(hexString:sub(5, 6), 16) / 255

	return r, g, b
end

-- Convert HSV to RGB values (0-1 range)
-- h: 0-360, s: 0-1, v: 0-1
function color.hsvToRgb(h, s, v)
	h = h / 360
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)

	i = i % 6

	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	else
		return v, p, q
	end
end

-- Convert RGB to hex string
function color.rgbToHex(r, g, b)
	local hexR = string.format("%02X", math.floor(r * 255 + 0.5))
	local hexG = string.format("%02X", math.floor(g * 255 + 0.5))
	local hexB = string.format("%02X", math.floor(b * 255 + 0.5))
	return "#" .. hexR .. hexG .. hexB
end

-- Convert hex string directly to LÖVE-compatible color array
function color.hexToLove(hexString, alpha)
	local r, g, b = color.hexToRgb(hexString)
	return { r, g, b, alpha or 1 }
end

-- Convert RGB to HSV values (0-1 range for all)
function color.rgbToHsv(r, g, b)
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local h, s, v

	v = max

	local delta = max - min

	if max ~= 0 then
		s = delta / max
	else
		-- r = g = b = 0, s = 0, v = 0
		s = 0
		h = 0 -- undefined, but set to 0
		return h, s, v
	end

	if delta == 0 then
		h = 0 -- gray
	else
		if r == max then
			h = (g - b) / delta -- between yellow & magenta
		elseif g == max then
			h = 2 + (b - r) / delta -- between cyan & yellow
		else
			h = 4 + (r - g) / delta -- between magenta & cyan
		end

		h = h / 6

		if h < 0 then
			h = h + 1
		end
	end

	return h, s, v
end

return color
