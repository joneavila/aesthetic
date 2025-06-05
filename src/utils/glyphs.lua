--- Glyph generation utilities
--
-- This module dynamically converts SVG icons to PNG format based on the mapping in glyph_mapping.txt
-- It replaces the static pre-generated PNGs with dynamically sized ones appropriate for the screen resolution
local love = require("love")
local tove = require("tove")

local paths = require("paths")

local logger = require("utils.logger")
local system = require("utils.system")

local glyphs = {}

local GLYPH_HEIGHT = 22
local GLYPH_HEIGHT_TESTER = 128
local STROKE_WIDTH = 1.5

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

-- Generate all primary glyphs (not muxlaunch or footer) based on glyph map
function glyphs.generatePrimaryGlyphs(targetDir, primaryGlyphMap)
	local canvasSize = GLYPH_HEIGHT + STROKE_WIDTH
	local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
	for _, entry in ipairs(primaryGlyphMap) do
		local svgPath = paths.SOURCE_DIR .. "/assets/icons/" .. entry.inputFilename .. ".svg"
		local pngPath = targetDir .. "/" .. entry.outputPath .. ".png"
		glyphs.convertSvgToPng(svgPath, pngPath, GLYPH_HEIGHT, canvas)
	end

	-- Copy header icons which are not in SVG
	local headerDir = targetDir .. "/header"
	logger.debug(string.format("Copying header icons from '%s' to '%s'", paths.HEADER_GLYPHS_SOURCE_DIR, headerDir))
	if not system.copyDir(paths.HEADER_GLYPHS_SOURCE_DIR, headerDir) then
		return false
	end
	return true
end

function glyphs.generateMuxLaunchGlyphs(muxLaunchGlyphMap)
	local baseOutputDir = paths.THEME_GRID_MUXLAUNCH
	local targetCanvasSize = 120
	local muxLaunchPadding = 45
	local glyphRenderHeight = targetCanvasSize - muxLaunchPadding
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
		local svgPath = paths.SOURCE_DIR .. "/assets/icons/" .. entry.inputFilename .. ".svg"
		local cleanOutputPath = entry.outputPath:gsub("^muxlaunch/", "")
		local pngPath = baseOutputDir .. "/" .. cleanOutputPath .. ".png"
		if not glyphs.convertSvgToPng(svgPath, pngPath, glyphRenderHeight, canvas, muxLaunchPadding) then
			logger.warning("Failed to convert muxlaunch glyph: " .. entry.inputFilename)
		else
			successCount = successCount + 1
		end
	end
	return successCount > 0
end

function glyphs.generateFooterGlyphs(footerGlyphMap)
	local height = 23
	local sourceDir = paths.FOOTER_GLYPHS_SOURCE_DIR
	local targetDir = paths.FOOTER_GLYPHS_TARGET_DIR
	local canvasSize = height + STROKE_WIDTH
	local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
	logger.debug(string.format("Generating %d footer glyphs from '%s' to '%s'", #footerGlyphMap, sourceDir, targetDir))
	local successCount = 0
	for _, entry in ipairs(footerGlyphMap) do
		local svgPath = sourceDir .. "/" .. entry.sourceFile
		local pngPath = targetDir .. "/" .. entry.outputFile
		if not glyphs.convertSvgToPng(svgPath, pngPath, height, canvas) then
			logger.warning("Failed to convert footer glyph: " .. entry.sourceFile)
		else
			successCount = successCount + 1
		end
	end
	return successCount > 0
end

-- Generate tester glyphs (muxtester/) at a larger height
function glyphs.generateTesterGlyphs(targetDir, testerGlyphMap)
	local canvasSize = GLYPH_HEIGHT_TESTER + STROKE_WIDTH
	local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
	for _, entry in ipairs(testerGlyphMap) do
		local svgPath = paths.SOURCE_DIR .. "/assets/icons/" .. entry.inputFilename .. ".svg"
		local pngPath = targetDir .. "/" .. entry.outputPath .. ".png"
		glyphs.convertSvgToPng(svgPath, pngPath, GLYPH_HEIGHT_TESTER, canvas)
	end
	return true
end

-- New generateGlyphs function
function glyphs.generateGlyphs(targetDir)
	-- Read glyph mapping file
	local mapContent = system.readFile(paths.GLYPH_MAPPING_FILE)
	if not mapContent then
		return nil
	end
	local glyphMap = {}
	for line in mapContent:gmatch("[^\r\n]+") do
		if line:match("^%s*#") or line:match("^%s*$") then
			-- Skip comments and empty lines
			goto continue
		end
		local outputPath, inputFilename = line:match("^%s*(.-)%s*,%s*(.-)%s*$")
		if outputPath and inputFilename then
			table.insert(glyphMap, {
				outputPath = outputPath,
				inputFilename = inputFilename,
			})
		else
			logger.warning("Skipping malformed line in glyph mapping: " .. line)
		end
		::continue::
	end
	logger.debug(string.format("Loaded %d entries from glyph mapping file '%s'", #glyphMap, paths.GLYPH_MAPPING_FILE))
	if not glyphMap then
		return false
	end

	-- Split glyph map into primary, muxlaunch, footer, and tester glyphs
	local primaryGlyphMap, muxLaunchGlyphMap, footerGlyphMap, testerGlyphMap = {}, {}, {}, {}
	for _, entry in ipairs(glyphMap) do
		if entry.outputPath:match("^muxlaunch/") then
			table.insert(muxLaunchGlyphMap, entry)
		elseif entry.outputPath:match("^footer/") then
			table.insert(footerGlyphMap, {
				sourceFile = entry.inputFilename .. ".svg",
				outputFile = entry.outputPath:gsub("^footer/", "") .. ".png",
			})
		elseif entry.outputPath:match("^muxtester/") then
			table.insert(testerGlyphMap, entry)
		else
			table.insert(primaryGlyphMap, entry)
		end
	end
	local ok1 = glyphs.generatePrimaryGlyphs(targetDir, primaryGlyphMap)
	local ok2 = glyphs.generateMuxLaunchGlyphs(muxLaunchGlyphMap)
	local ok3 = glyphs.generateFooterGlyphs(footerGlyphMap)
	local ok4 = glyphs.generateTesterGlyphs(targetDir, testerGlyphMap)
	return ok1 and ok2 and ok3 and ok4
end

return glyphs
