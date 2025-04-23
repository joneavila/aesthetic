--- BMP image encoding utilities
local errorHandler = require("error_handler")
local system = require("utils.system")

local bmp = {}

-- Encode image data as a 24-bit BMP file
-- Currently LÖVE does not support encoding BMP
function bmp.encode(imageData)
	local width = imageData:getWidth()
	local height = imageData:getHeight()

	-- Calculate row size and padding
	-- BMP rows must be aligned to 4 bytes
	local rowSize = math.floor((24 * width + 31) / 32) * 4
	local padding = rowSize - width * 3

	-- Calculate file size
	local headerSize = 54 -- 14 bytes file header + 40 bytes info header
	local imageSize = rowSize * height
	local fileSize = headerSize + imageSize

	-- Create a string to hold the BMP data
	local bmpData = ""

	-- Helper function to write little-endian integers to a string
	local function appendInt(value, bytes)
		local result = ""
		for _ = 1, bytes do
			result = result .. string.char(value % 256)
			value = math.floor(value / 256)
		end
		return result
	end

	-- Write BMP file header (14 bytes)
	bmpData = bmpData .. "BM" -- Signature
	bmpData = bmpData .. appendInt(fileSize, 4) -- File size
	bmpData = bmpData .. appendInt(0, 4) -- Reserved
	bmpData = bmpData .. appendInt(headerSize, 4) -- Pixel data offset

	-- Write BMP info header (40 bytes)
	bmpData = bmpData .. appendInt(40, 4) -- Info header size
	bmpData = bmpData .. appendInt(width, 4) -- Width
	bmpData = bmpData .. appendInt(height, 4) -- Height (positive for bottom-up)
	bmpData = bmpData .. appendInt(1, 2) -- Planes
	bmpData = bmpData .. appendInt(24, 2) -- Bits per pixel
	bmpData = bmpData .. appendInt(0, 4) -- Compression (none)
	bmpData = bmpData .. appendInt(imageSize, 4) -- Image size
	bmpData = bmpData .. appendInt(2835, 4) -- X pixels per meter
	bmpData = bmpData .. appendInt(2835, 4) -- Y pixels per meter
	bmpData = bmpData .. appendInt(0, 4) -- Colors in color table
	bmpData = bmpData .. appendInt(0, 4) -- Important color count

	-- Write pixel data (bottom-up, BGR format)
	local padBytes = string.rep("\0", padding)
	for y = height - 1, 0, -1 do
		for x = 0, width - 1 do
			local r, g, b, _ = imageData:getPixel(x, y)
			-- Convert from 0-1 to 0-255 range and write BGR
			bmpData = bmpData .. string.char(math.floor(b * 255), math.floor(g * 255), math.floor(r * 255))
		end
		-- Add padding to align rows to 4 bytes
		if padding > 0 then
			bmpData = bmpData .. padBytes
		end
	end

	return bmpData
end

-- Save image data as a 24-bit BMP file
function bmp.saveToFile(imageData, filepath)
	local bmpData = bmp.encode(imageData)

	if not bmpData then
		errorHandler.setError("Failed to encode BMP data")
		return false
	end

	-- Write the BMP data to file
	return system.writeBinaryFile(filepath, bmpData)
end

return bmp
