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

-- Encode image data as a 24-bit BMP file
-- Currently LÖVE does not support encoding BMP
function bmp.encode(imageData)
	-- Safety check for imageData
	if not imageData then
		logger.error("No image data provided")
		return nil
	end

	local width, height

	-- Safe access to width and height
	local status, err = pcall(function()
		width = imageData:getWidth()
		height = imageData:getHeight()
	end)

	if not status then
		logger.error("Failed to get image dimensions: " .. tostring(err))
		return nil
	end

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
	local rowSize = math.floor((24 * width + 31) / 32) * 4
	local padding = rowSize - width * 3

	-- Calculate file size and check memory requirements
	local headerSize = 54 -- 14 bytes file header + 40 bytes info header
	local imageSize = rowSize * height
	local fileSize = headerSize + imageSize

	-- Safety check for reasonable file size to prevent memory issues
	if fileSize > 100 * 1024 * 1024 then -- 100MB limit
		logger.error("Resulting file would be too large: " .. math.floor(fileSize / 1024 / 1024) .. "MB")
		return nil
	end

	-- Create a table to build BMP data (more efficient than string concatenation)
	local bmpChunks = {}
	local chunkIndex = 1

	-- Helper function to add chunk to the table
	local function appendChunk(chunk)
		bmpChunks[chunkIndex] = chunk
		chunkIndex = chunkIndex + 1
	end

	-- Helper function to write little-endian integers
	local function intToBytes(value, bytes)
		if type(value) ~= "number" then
			logger.error("Invalid value for intToBytes: " .. tostring(value))
			return string.rep("\0", bytes)
		end

		local result = ""
		for _ = 1, bytes do
			result = result .. string.char(value % 256)
			value = math.floor(value / 256)
		end
		return result
	end

	-- Write BMP file header (14 bytes)
	appendChunk("BM") -- Signature
	appendChunk(intToBytes(fileSize, 4)) -- File size
	appendChunk(intToBytes(0, 4)) -- Reserved
	appendChunk(intToBytes(headerSize, 4)) -- Pixel data offset

	-- Write BMP info header (40 bytes)
	appendChunk(intToBytes(40, 4)) -- Info header size
	appendChunk(intToBytes(width, 4)) -- Width
	appendChunk(intToBytes(height, 4)) -- Height (positive for bottom-up)
	appendChunk(intToBytes(1, 2)) -- Planes
	appendChunk(intToBytes(24, 2)) -- Bits per pixel
	appendChunk(intToBytes(0, 4)) -- Compression (none)
	appendChunk(intToBytes(imageSize, 4)) -- Image size
	appendChunk(intToBytes(2835, 4)) -- X pixels per meter
	appendChunk(intToBytes(2835, 4)) -- Y pixels per meter
	appendChunk(intToBytes(0, 4)) -- Colors in color table
	appendChunk(intToBytes(0, 4)) -- Important color count

	-- Prepare padding bytes
	local padBytes = string.rep("\0", padding)

	-- Process image in chunks to avoid memory issues
	local ROW_CHUNK_SIZE = 100 -- Process this many rows at a time

	-- Safely process pixel data in chunks
	for startY = height - 1, 0, -ROW_CHUNK_SIZE do
		-- Calculate the end row for this chunk
		local endY = math.max(0, startY - ROW_CHUNK_SIZE + 1)

		local chunkStatus, chunkErr = pcall(function()
			for y = startY, endY, -1 do
				local rowData = {}
				local rowIdx = 1

				for x = 0, width - 1 do
					-- Safely get pixel with pcall to catch any errors
					local pixelStatus, pixelResult = pcall(function()
						return { imageData:getPixel(x, y) }
					end)

					local r, g, b, a = 0, 0, 0, 1
					if pixelStatus and type(pixelResult) == "table" then
						r = type(pixelResult[1]) == "number" and pixelResult[1] or 0
						g = type(pixelResult[2]) == "number" and pixelResult[2] or 0
						b = type(pixelResult[3]) == "number" and pixelResult[3] or 0
						a = type(pixelResult[4]) == "number" and pixelResult[4] or 1
					else
						-- If pixel access failed, use black
						logger.warning("Failed to get pixel at " .. x .. "," .. y .. ", using black instead")
					end

					-- Clamp values to valid range
					r = math.max(0, math.min(1, r))
					g = math.max(0, math.min(1, g))
					b = math.max(0, math.min(1, b))
					a = math.max(0, math.min(1, a))

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

					-- Convert from 0-1 to 0-255 range and store BGR in row data
					local br = math.floor(b * 255)
					local gr = math.floor(g * 255)
					local rr = math.floor(r * 255)

					-- Safe character generation with pcall
					local charStatus, charResult = pcall(function()
						return string.char(br, gr, rr)
					end)

					if charStatus then
						rowData[rowIdx] = charResult
					else
						-- Use safe fallback if string.char fails
						rowData[rowIdx] = string.char(0, 0, 0)
					end
					rowIdx = rowIdx + 1
				end

				-- Add row to BMP data
				appendChunk(table.concat(rowData))

				-- Add padding to align rows to 4 bytes
				if padding > 0 then
					appendChunk(padBytes)
				end
			end
		end)

		if not chunkStatus then
			logger.error("Failed to process chunk of pixel data: " .. tostring(chunkErr))
			return nil
		end

		-- Process system events periodically to prevent application freezing
		if system.yield and type(system.yield) == "function" then
			pcall(system.yield)
		end

		-- Check if we're running out of memory
		if collectgarbage("count") > 1000000 then -- If using more than ~1GB
			logger.warning("Memory usage high, attempting garbage collection")
			collectgarbage("collect")
		end
	end

	-- Safely concatenate all chunks
	local finalStatus, finalResult = pcall(function()
		return table.concat(bmpChunks)
	end)

	if not finalStatus then
		logger.error("Failed to concatenate BMP data: " .. tostring(finalResult))
		return nil
	end

	return finalResult
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

	-- Write the BMP data to file with safety check
	local writeStatus, writeResult = pcall(function()
		return system.writeBinaryFile(outputPath, bmpData)
	end)

	if not writeStatus then
		logger.error("Failed to write file: " .. tostring(writeResult))
		errorHandler.setError("Failed to write BMP file: " .. tostring(writeResult))
		return false
	end

	return writeResult
end

return bmp
