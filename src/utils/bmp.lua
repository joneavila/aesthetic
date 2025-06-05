-- BMP image encoding utilities
local bmp = {}

local string_char = string.char
local math_floor = math.floor
local table_concat = table.concat

-- Pre-calculate byte conversion table for 0-255 range
local byteTable = {}
for i = 0, 255 do
	byteTable[i] = string_char(i)
end

-- Encode image data as a 24-bit True Colour bitmap BMP file
function bmp.encode(imageData)
	local width, height = imageData:getWidth(), imageData:getHeight()

	-- BMP rows must be aligned to 4 bytes
	local rowSize = math_floor((24 * width + 31) / 32) * 4
	local padding = rowSize - width * 3
	local headerSize = 54 -- 14 bytes file header + 40 bytes info header
	local imageSize = rowSize * height
	local fileSize = headerSize + imageSize

	-- Use a table to efficiently build the BMP binary data
	local bmpChunks = {}
	local chunkIndex = 1

	-- Helper to write little-endian integers
	local function intToBytes(value, bytes)
		local result = {}
		for i = 1, bytes do
			result[i] = byteTable[value % 256]
			value = math_floor(value / 256)
		end
		return table_concat(result)
	end

	-- BMP file header (14 bytes)
	bmpChunks[chunkIndex] = "BM"
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(fileSize, 4)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(0, 4)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(headerSize, 4)
	chunkIndex = chunkIndex + 1

	-- BMP info header (40 bytes)
	bmpChunks[chunkIndex] = intToBytes(40, 4)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(width, 4)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(height, 4)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(1, 2)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(24, 2)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(0, 4)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(imageSize, 4)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(2835, 4) -- X pixels per meter (72 DPI)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(2835, 4) -- Y pixels per meter (72 DPI)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(0, 4)
	chunkIndex = chunkIndex + 1
	bmpChunks[chunkIndex] = intToBytes(0, 4)
	chunkIndex = chunkIndex + 1

	-- Precompute row padding bytes
	local padBytes = string.rep("\0", padding)

	-- Write pixel data (bottom-up, BGR format)
	for y = height - 1, 0, -1 do
		local rowData = {}
		local rowIdx = 1
		for x = 0, width - 1 do
			local r, g, b = imageData:getPixel(x, y)
			-- Convert to 0-255 and store as BGR
			local br = math_floor(b * 255)
			local gr = math_floor(g * 255)
			local rr = math_floor(r * 255)
			rowData[rowIdx] = byteTable[br]
			rowData[rowIdx + 1] = byteTable[gr]
			rowData[rowIdx + 2] = byteTable[rr]
			rowIdx = rowIdx + 3
		end
		-- Add row data and padding
		bmpChunks[chunkIndex] = table_concat(rowData)
		chunkIndex = chunkIndex + 1
		if padding > 0 then
			bmpChunks[chunkIndex] = padBytes
			chunkIndex = chunkIndex + 1
		end
	end

	-- Concatenate all chunks to produce the BMP binary
	local bmpData = table_concat(bmpChunks)
	return bmpData
end

-- Save image data as a 24-bit BMP file
function bmp.saveToFile(imageData, outputPath)
	local bmpData = bmp.encode(imageData)
	local file = io.open(outputPath, "wb")
	if not file then
		return false
	end
	file:write(bmpData)
	file:close()
	return true
end

return bmp
