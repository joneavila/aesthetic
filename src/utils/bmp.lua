--- BMP image encoding utilities
local errorHandler = require("error_handler")
local system = require("utils.system")
local logger = require("utils.logger")
local bmp = {}

-- Maximum image dimensions to prevent memory issues
local MAX_WIDTH = 16384
local MAX_HEIGHT = 16384
-- Maximum total pixels to process (as another safeguard)
local MAX_PIXELS = 50000000 -- 50 million pixels

-- Cache for string.char to avoid repeated function calls
local string_char = string.char
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local table_concat = table.concat

-- Pre-calculate byte conversion table for 0-255 range
local byteTable = {}
for i = 0, 255 do
	byteTable[i] = string_char(i)
end

-- Encode image data as a 24-bit BMP file
-- Currently LÖVE does not support encoding BMP
function bmp.encode(imageData)
	-- Safety check for imageData
	if not imageData then
		logger.error("No image data provided")
		return nil
	end

	local width, height = imageData:getWidth(), imageData:getHeight()

	-- Validate dimensions
	if width <= 0 or height <= 0 then
		logger.error("Invalid image dimensions: " .. width .. "x" .. height)
		return nil
	end

	-- Check for excessively large images that could cause memory issues
	if width > MAX_WIDTH or height > MAX_HEIGHT then
		logger.error(
			"Image dimensions too large: "
				.. width
				.. "x"
				.. height
				.. ", maximum allowed: "
				.. MAX_WIDTH
				.. "x"
				.. MAX_HEIGHT
		)
		return nil
	end

	if width * height > MAX_PIXELS then
		logger.error("Too many pixels: " .. (width * height) .. ", maximum allowed: " .. MAX_PIXELS)
		return nil
	end

	-- Calculate row size and padding
	-- BMP rows must be aligned to 4 bytes
	local rowSize = math_floor((24 * width + 31) / 32) * 4
	local padding = rowSize - width * 3

	-- Calculate file size and check memory requirements
	local headerSize = 54 -- 14 bytes file header + 40 bytes info header
	local imageSize = rowSize * height
	local fileSize = headerSize + imageSize

	-- Safety check for reasonable file size to prevent memory issues
	if fileSize > 100 * 1024 * 1024 then -- 100MB limit
		logger.error("Resulting file would be too large: " .. math_floor(fileSize / 1024 / 1024) .. "MB")
		return nil
	end

	-- Create a table to build BMP data (more efficient than string concatenation)
	local bmpChunks = {}
	local chunkIndex = 1

	-- Helper function to write little-endian integers
	local function intToBytes(value, bytes)
		if type(value) ~= "number" then
			logger.error("Invalid value for intToBytes: " .. tostring(value))
			return string.rep("\0", bytes)
		end

		local result = {}
		for i = 1, bytes do
			result[i] = byteTable[value % 256]
			value = math_floor(value / 256)
		end
		return table_concat(result)
	end

	-- Write BMP file header (14 bytes)
	bmpChunks[chunkIndex] = "BM" -- Signature
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(fileSize, 4) -- File size
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(0, 4) -- Reserved
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(headerSize, 4) -- Pixel data offset
	chunkIndex = chunkIndex + 1

	-- Write BMP info header (40 bytes)
	bmpChunks[chunkIndex] = intToBytes(40, 4) -- Info header size
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(width, 4) -- Width
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(height, 4) -- Height (positive for bottom-up)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(1, 2) -- Planes
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(24, 2) -- Bits per pixel
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(0, 4) -- Compression (none)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(imageSize, 4) -- Image size
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(2835, 4) -- X pixels per meter
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(2835, 4) -- Y pixels per meter
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(0, 4) -- Colors in color table
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(0, 4) -- Important color count
	chunkIndex = chunkIndex + 1

	-- Prepare padding bytes
	local padBytes = string.rep("\0", padding)

	-- Process image data row by row (bottom-up for BMP format)
	for y = height - 1, 0, -1 do
		local rowData = {}
		local rowIdx = 1

		-- Process entire row at once for better performance
		for x = 0, width - 1 do
			local r, g, b, a = imageData:getPixel(x, y)

			-- Clamp values to valid range
			r = math_max(0, math_min(1, r))
			g = math_max(0, math_min(1, g))
			b = math_max(0, math_min(1, b))
			a = math_max(0, math_min(1, a))

			-- Un-premultiply alpha if a < 1, this is crucial for proper color brightness
			if a > 0 and a < 1 then
				r = r / a
				g = g / a
				b = b / a
			end

			-- Handle alpha blending with background color (white in this case)
			-- For boot images we want to ensure colors aren't too dark
			if a < 1 then
				local bgr, bgg, bgb = 1, 1, 1 -- White background
				r = r * a + bgr * (1 - a)
				g = g * a + bgg * (1 - a)
				b = b * a + bgb * (1 - a)
			end

			-- Convert from 0-1 to 0-255 range and store BGR format
			local br = math_floor(b * 255)
			local gr = math_floor(g * 255)
			local rr = math_floor(r * 255)

			-- Use pre-calculated byte table for faster conversion
			rowData[rowIdx] = byteTable[br]
			rowData[rowIdx + 1] = byteTable[gr]
			rowData[rowIdx + 2] = byteTable[rr]
			rowIdx = rowIdx + 3
		end

		-- Add row to BMP data
		bmpChunks[chunkIndex] = table_concat(rowData)
		chunkIndex = chunkIndex + 1

		-- Add padding to align rows to 4 bytes
		if padding > 0 then
			bmpChunks[chunkIndex] = padBytes
			chunkIndex = chunkIndex + 1
		end
	end

	-- Concatenate all chunks to create final BMP data
	local bmpData = table_concat(bmpChunks)

	return bmpData
end

-- Save image data as a 24-bit BMP file
function bmp.saveToFile(imageData, outputPath)
	-- Ensure output path parent directory exists
	if not system.ensurePath(outputPath) then
		logger.error("Failed to ensure output path exists: " .. outputPath)
		return false
	end

	local bmpData = bmp.encode(imageData)

	if not bmpData then
		logger.error("Failed to encode BMP data")
		errorHandler.setError("Failed to encode BMP data")
		return false
	end

	-- Write the BMP data to file
	local success = system.writeFile(outputPath, bmpData)
	if not success then
		logger.error("Failed to write BMP file to: " .. outputPath)
		errorHandler.setError("Failed to write BMP file")
		return false
	end

	return true
end

return bmp
