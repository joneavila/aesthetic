--- Glyph generation utilities
--
-- This module dynamically converts SVG icons to PNG format based on the mapping in glyph_map.txt
-- It replaces the static pre-generated PNGs with dynamically sized ones appropriate for the screen resolution
--
local love = require("love")
local system = require("utils.system")
local paths = require("paths")
local svg = require("utils.svg")
local colorUtils = require("utils.color")
local state = require("state")
local logger = require("utils.logger")
local errorHandler = require("error_handler")

local glyphs = {}

-- Reference glyph height for 640x480
local BASE_GLYPH_HEIGHT = 24
local BASE_SCREEN_WIDTH = 640
local BASE_SCREEN_HEIGHT = 480
local MIN_GLYPH_HEIGHT = 24
local MAX_GLYPH_HEIGHT = 24
-- Always use 2px for stroke width
local FIXED_STROKE_WIDTH = 2

-- Set the base stroke width (before scaling)
function glyphs.setBaseStrokeWidth(width)
	logger.warning("setBaseStrokeWidth is deprecated: stroke width is now always 2px.")
	return false
end

-- Read the glyph mapping file and return parsed mapping data
function glyphs.readGlyphMap()
	local mapPath = paths.ROOT_DIR .. "/utils/glyph_map.txt"
	local mapContent = system.readFile(mapPath)

	if not mapContent then
		errorHandler.setError("Failed to read glyph map file: " .. mapPath)
		return nil
	end

	local glyphMap = {}

	-- Parse each line
	for line in mapContent:gmatch("[^\r\n]+") do
		-- Skip comments and empty lines
		if not line:match("^%s*#") and not line:match("^%s*$") then
			local outputPath, inputFilename = line:match("([^,]+),%s*(.+)")
			if outputPath and inputFilename then
				-- Trim whitespace
				outputPath = outputPath:match("^%s*(.-)%s*$")
				inputFilename = inputFilename:match("^%s*(.-)%s*$")

				table.insert(glyphMap, {
					outputPath = outputPath,
					inputFilename = inputFilename,
				})
			end
		end
	end

	return glyphMap
end

-- Calculate the appropriate glyph height based on screen dimensions (diagonal scaling, like fonts.lua)
function glyphs.calculateGlyphHeight(width, height)
	-- For 640x480, use 24px. For other resolutions, scale proportionally by diagonal, clamp to [24, 36].
	local baseDiagonal = math.sqrt(BASE_SCREEN_WIDTH ^ 2 + BASE_SCREEN_HEIGHT ^ 2)
	local currentDiagonal = math.sqrt(width ^ 2 + height ^ 2)
	local scalingFactor = currentDiagonal / baseDiagonal
	local scaledHeight = BASE_GLYPH_HEIGHT * scalingFactor
	local clampedHeight = math.max(MIN_GLYPH_HEIGHT, math.min(math.floor(scaledHeight + 0.5), MAX_GLYPH_HEIGHT))
	return clampedHeight
end

-- Utility to override stroke-width in SVG XML string
local function overrideStrokeWidth(svgContent, strokeWidth)
	-- Replace any stroke-width attribute (with or without units)
	-- Handles: stroke-width="2.5", stroke-width='2.5', stroke-width="2.5px", etc.
	svgContent = svgContent:gsub('stroke%-width%s*=%s*"[^"]*"', 'stroke-width="' .. strokeWidth .. '"')
	svgContent = svgContent:gsub("stroke%-width%s*=%s*'[^']*'", "stroke-width='" .. strokeWidth .. "'")
	return svgContent
end

-- Convert a single SVG icon to PNG with fixed stroke width, using TÖVE's prescale for sharpness
function glyphs.convertSvgToPng(svgPath, pngPath, glyphHeight, fgColor)
	-- Ensure parent directory exists
	if not system.ensurePath(pngPath) then
		logger.error("Failed to create directory for glyph: " .. pngPath)
		return false
	end

	-- Read SVG content
	local svgContent = system.readFile(svgPath)
	if not svgContent then
		logger.error("Failed to read SVG file: " .. svgPath)
		return false
	end

	-- Override stroke-width in SVG XML
	svgContent = overrideStrokeWidth(svgContent, FIXED_STROKE_WIDTH)

	-- Add padding for stroke width to prevent clipping
	local pad = FIXED_STROKE_WIDTH
	local canvasSize = glyphHeight + pad

	-- Use TÖVE's prescale parameter to rasterize at the target size
	local tove = require("tove")
	local graphics = tove.newGraphics(svgContent, glyphHeight)
	graphics:setLineWidth(FIXED_STROKE_WIDTH)

	-- Create a canvas for drawing at the correct size (with padding)
	local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
	local prevCanvas = love.graphics.getCanvas()

	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)

	love.graphics.push()
	love.graphics.setColor(fgColor)
	love.graphics.setBlendMode("alpha")
	-- Draw the SVG centered, accounting for padding
	love.graphics.translate(pad / 2, pad / 2)
	graphics:draw(glyphHeight / 2, glyphHeight / 2)
	love.graphics.pop()

	love.graphics.setCanvas(prevCanvas)

	-- Get image data and encode as PNG
	local imageData = canvas:newImageData()
	local pngData = imageData:encode("png")

	if not system.writeBinaryFile(pngPath, pngData:getString()) then
		logger.error("Failed to write PNG file: " .. pngPath)
		return false
	end

	return true
end

-- Generate all glyphs based on glyph map
function glyphs.generateGlyphs(targetDir)
	local glyphMap = glyphs.readGlyphMap()
	if not glyphMap then
		return false
	end

	local svgBaseDir = paths.ROOT_DIR .. "/assets/icons/lucide/glyph"
	local baseOutputDir = targetDir

	-- Calculate glyph height based on current screen dimensions
	local glyphHeight = glyphs.calculateGlyphHeight(state.screenWidth, state.screenHeight)

	-- Get foreground color for icons
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	logger.debug(
		"Generating glyphs with height: " .. glyphHeight .. "px and stroke width: " .. FIXED_STROKE_WIDTH .. "px"
	)

	for _, entry in ipairs(glyphMap) do
		local svgPath = svgBaseDir .. "/" .. entry.inputFilename .. ".svg"
		local pngPath = baseOutputDir .. "/" .. entry.outputPath .. ".png"

		if not glyphs.convertSvgToPng(svgPath, pngPath, glyphHeight, fgColor) then
			logger.warning("Failed to convert glyph: " .. entry.inputFilename)
		end
	end

	return true
end

return glyphs
