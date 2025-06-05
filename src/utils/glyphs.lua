--- Glyph generation utilities
--
-- This module dynamically converts SVG icons to PNG format based on the mapping in glyph_map.txt
-- It replaces the static pre-generated PNGs with dynamically sized ones appropriate for the screen resolution
--
local love = require("love")
local tove = require("tove")

local errorHandler = require("error_handler")
local paths = require("paths")
local state = require("state")

local colorUtils = require("utils.color")
local logger = require("utils.logger")
local system = require("utils.system")

local glyphs = {}

local GLYPH_HEIGHT = 22
local GLYPH_MAPPING_FILE = paths.SOURCE_DIR .. "/utils/glyph_mapping.txt"
local STROKE_WIDTH = 1.5

-- Read the glyph mapping file and return the map
function glyphs.readGlyphMap()
	local mapContent = system.readFile(GLYPH_MAPPING_FILE)
	if not mapContent then
		return nil
	end

	local mapEntries = {}

	-- Parse each line, skipping comments and empty lines
	for line in mapContent:gmatch("[^\r\n]+") do
		if line:match("^%s*#") or line:match("^%s*$") then
			goto continue
		end
		local outputPath, inputFilename = line:match("^%s*(.-)%s*,%s*(.-)%s*$")
		if outputPath and inputFilename then
			table.insert(mapEntries, {
				outputPath = outputPath,
				inputFilename = inputFilename,
			})
		else
			logger.warning("Skipping malformed line in glyph mapping: " .. line)
		end
		::continue::
	end

	logger.debug(string.format("Loaded %d entries from glyph mapping file '%s'", #mapEntries, GLYPH_MAPPING_FILE))
	return mapEntries
end

-- Convert a single SVG icon to PNG with fixed stroke width
-- Optionally accepts a padding value to use instead of the fixed stroke width for canvas size.
-- The glyphHeight parameter should be the size the glyph itself is rendered at *before* padding.
-- Canvas parameter should be pre-created and appropriately sized.
function glyphs.convertSvgToPng(svgPath, pngPath, glyphRenderHeight, canvas, padding)
	-- Read SVG content
	local svgContent = system.readFile(svgPath)
	if not svgContent then
		return false
	end

	-- Override stroke-width in SVG XML
	-- Replace any stroke-width attribute (with or without units)
	-- Handles: stroke-width="2.5", stroke-width='2.5', stroke-width="2.5px", etc.
	svgContent = svgContent:gsub('stroke%-width%s*=%s*"[^"]*"', 'stroke-width="' .. STROKE_WIDTH .. '"')
	svgContent = svgContent:gsub("stroke%-width%s*=%s*'[^']*'", "stroke-width='" .. STROKE_WIDTH .. "'")

	-- Use provided padding or default to STROKE_WIDTH for canvas size
	local effectivePad = padding or STROKE_WIDTH

	-- Use TÖVE's prescale parameter to rasterize at the target render size
	-- tove.newGraphics scales to the provided glyphRenderHeight based on the SVG's viewbox/size
	local graphics = tove.newGraphics(svgContent, glyphRenderHeight)
	graphics:setLineWidth(STROKE_WIDTH)

	-- Clear and use the provided canvas
	local prevCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.push()

	-- Use black for glyphs (glyphs are recolored by muOS)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setBlendMode("alpha")

	-- Draw the SVG centered, accounting for padding
	love.graphics.translate(effectivePad / 2, effectivePad / 2)

	-- Draw the graphic scaled to fit the glyphRenderHeight within the padded canvas
	graphics:draw(glyphRenderHeight / 2, glyphRenderHeight / 2)

	love.graphics.pop()
	love.graphics.setCanvas(prevCanvas)

	-- Get image data and encode as PNG
	local imageData = canvas:newImageData()
	local pngData = imageData:encode("png")

	if not system.writeFile(pngPath, pngData:getString()) then
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

	local canvasSize = GLYPH_HEIGHT + STROKE_WIDTH

	-- Create canvas once and reuse it
	local canvas = love.graphics.newCanvas(canvasSize, canvasSize)

	for _, entry in ipairs(glyphMap) do
		local svgPath = paths.THEME_GLYPH_SOURCE_DIR .. "/" .. entry.inputFilename .. ".svg"
		local pngPath = targetDir .. "/" .. entry.outputPath .. ".png"
		glyphs.convertSvgToPng(svgPath, pngPath, GLYPH_HEIGHT, canvas)
	end

	-- Copy header icons directly
	local headerDir = targetDir .. "/header"
	logger.debug(string.format("Copying header icons from '%s' to '%s'", paths.HEADER_GLYPHS_SOURCE_DIR, headerDir))
	if not system.copyDir(paths.HEADER_GLYPHS_SOURCE_DIR, headerDir) then
		return false
	end

	return true
end

--- Generates PNG files for icons specifically used in the muxlaunch grid view.
--- It reads the full glyph map but filters for entries with an outputPath that starts with `muxlaunch/`.
--- These filtered icons are then converted from their SVG source to PNG format.
--- The generated PNGs are saved to the directory specified by `paths.THEME_GRID_MUXLAUNCH`.
--- Icons are rendered at a specific height such that when 8px padding is added, the final image is 120x120px.
function glyphs.generateMuxLaunchGlyphs()
	local glyphMap = glyphs.readGlyphMap()
	if not glyphMap then
		return false
	end

	local muxLaunchGlyphMap = {}
	for _, entry in ipairs(glyphMap) do
		if entry.outputPath:match("^muxlaunch/") then
			table.insert(muxLaunchGlyphMap, entry)
		end
	end

	local baseOutputDir = paths.THEME_GRID_MUXLAUNCH

	local targetCanvasSize = 120 -- Desired final image size (with padding)
	local muxLaunchPadding = 45
	-- Calculate the render height needed for the glyph itself
	local glyphRenderHeight = targetCanvasSize - muxLaunchPadding

	-- Create canvas once and reuse it
	local canvas = love.graphics.newCanvas(targetCanvasSize, targetCanvasSize)

	logger.debug(
		string.format(
			"Generating %d muxlaunch glyphs targeting %dpx canvas size (render height: %dpx, padding: %dpx)",
			#muxLaunchGlyphMap,
			targetCanvasSize,
			glyphRenderHeight,
			muxLaunchPadding
		)
	)

	local successCount = 0
	for _, entry in ipairs(muxLaunchGlyphMap) do
		local svgPath = paths.THEME_GLYPH_SOURCE_DIR .. "/" .. entry.inputFilename .. ".svg"
		-- Remove the "muxlaunch/" prefix from the outputPath before joining
		local cleanOutputPath = entry.outputPath:gsub("^muxlaunch/", "")
		local pngPath = baseOutputDir .. "/" .. cleanOutputPath .. ".png"

		-- Call convertSvgToPng with the calculated render height and specific padding
		if not glyphs.convertSvgToPng(svgPath, pngPath, glyphRenderHeight, canvas, muxLaunchPadding) then
			logger.warning("Failed to convert muxlaunch glyph: " .. entry.inputFilename)
		else
			successCount = successCount + 1
		end
	end

	logger.debug(string.format("Generated %d of %d muxlaunch glyphs.", successCount, #muxLaunchGlyphMap))

	-- Muxlaunch icons don't have a separate header category to copy directly

	return successCount > 0
end

--- Generates PNG files for footer glyphs from hardcoded mappings.
--- Converts specific SVG files from the footer glyphs source directory to PNG format
--- and saves them to the footer glyphs target directory with predefined filenames and heights.
function glyphs.generateFooterGlyphs()
	-- Hardcoded mappings: source filename, height, output filename
	-- TODO: Refactor if all glyphs use the same height
	local height = 23
	local footerGlyphMappings = {
		{ sourceFile = "playstation_dpad_horizontal_outline.svg", height = height, outputFile = "lr.png" },
		{ sourceFile = "steam_button_a.svg", height = height, outputFile = "a.png" },
		{ sourceFile = "steam_button_b.svg", height = height, outputFile = "b.png" },
		{ sourceFile = "steam_button_c_custom.svg", height = height, outputFile = "c.png" },
		{ sourceFile = "steam_button_x.svg", height = height, outputFile = "x.png" },
		{ sourceFile = "steam_button_y.svg", height = height, outputFile = "y.png" },
		{ sourceFile = "steam_button_z_custom.svg", height = height, outputFile = "z.png" },
		{ sourceFile = "steamdeck_button_quickaccess.svg", height = height, outputFile = "menu.png" },
	}

	local sourceDir = paths.FOOTER_GLYPHS_SOURCE_DIR
	local targetDir = paths.FOOTER_GLYPHS_TARGET_DIR

	local canvasSize = height + STROKE_WIDTH

	-- Create canvas once and reuse it
	local canvas = love.graphics.newCanvas(canvasSize, canvasSize)

	-- Get foreground color for icons
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	logger.debug(
		string.format("Generating %d footer glyphs from '%s' to '%s'", #footerGlyphMappings, sourceDir, targetDir)
	)

	local successCount = 0
	for _, mapping in ipairs(footerGlyphMappings) do
		local svgPath = sourceDir .. "/" .. mapping.sourceFile
		local pngPath = targetDir .. "/" .. mapping.outputFile

		if not glyphs.convertSvgToPng(svgPath, pngPath, mapping.height, canvas) then
			logger.warning("Failed to convert footer glyph: " .. mapping.sourceFile)
		else
			successCount = successCount + 1
		end
	end

	logger.debug(string.format("Generated %d of %d footer glyphs.", successCount, #footerGlyphMappings))

	return successCount > 0
end

return glyphs
