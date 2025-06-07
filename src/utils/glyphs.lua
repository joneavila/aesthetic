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

local GLYPH_HEIGHT = 22 -- Most glyphs are 20x20 in the default theme, 32x32 for the 1024x768 theme
local GLYPH_HEIGHT_TESTER = 128 -- 256x256 for the default theme, 192x192 for the 1024x768 theme
local DEFAULT_PADDING = 4

local STROKE_WIDTH = 1.5
local STROKE_PATTERN = "stroke%-width%s*=%s*[\"'][^\"']*[\"']"
local STROKE_REPLACEMENT = 'stroke-width="' .. STROKE_WIDTH .. '"'

local function replaceStrokeWidthSingle(svgContent)
	if not svgContent:find("stroke%-width") then
		return svgContent
	end
	return svgContent:gsub(STROKE_PATTERN, STROKE_REPLACEMENT)
end

-- Convert a single SVG icon to PNG with fixed stroke width
-- Optionally accepts a padding value to use instead of the fixed stroke width for canvas size.
-- The glyphHeight parameter should be the size the glyph itself is rendered at *before* padding.
-- Canvas parameter should be pre-created and appropriately sized.
function glyphs.convertSvgToPng(svgPath, pngPath, glyphRenderHeight, canvas, padding)
	local lg = love.graphics
	local tv = tove

	local svgContent = system.readFile(svgPath)
	if not svgContent then
		return false
	end

	svgContent = replaceStrokeWidthSingle(svgContent)

	local effectivePad = padding or DEFAULT_PADDING
	local graphics = tv.newGraphics(svgContent, glyphRenderHeight)

	local prevCanvas = lg.getCanvas()
	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)
	lg.push()

	lg.setColor(1, 1, 1, 1)
	lg.setBlendMode("alpha")
	lg.translate(effectivePad / 2, effectivePad / 2)
	graphics:draw(glyphRenderHeight / 2, glyphRenderHeight / 2)

	lg.pop()
	lg.setCanvas(prevCanvas)

	local imageData = canvas:newImageData()
	local pngData = imageData:encode("png")

	if not system.writeFile(pngPath, pngData:getString()) then
		return false
	end

	return true
end

-- Generate all primary glyphs (header, footer, etc.; not muxlaunch or muxtester) based on glyph map
function glyphs.generatePrimaryGlyphs(targetDir, primaryGlyphMap)
	-- Generate standard glyphs (height 22)
	local canvasSize = GLYPH_HEIGHT + DEFAULT_PADDING
	local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
	for _, entry in ipairs(primaryGlyphMap) do
		local svgPath = paths.SOURCE_DIR .. "/assets/icons/" .. entry.inputFilename .. ".svg"
		local pngPath = targetDir .. "/" .. entry.outputPath .. ".png"
		glyphs.convertSvgToPng(svgPath, pngPath, GLYPH_HEIGHT, canvas, DEFAULT_PADDING)
	end

	-- Generate additional set for 1024x768 (height 25, padding 7)
	local GLYPH_HEIGHT_1024x768 = 34
	local DEFAULT_PADDING_1024x768 = 7
	local canvasSize1024x768 = GLYPH_HEIGHT_1024x768 + DEFAULT_PADDING_1024x768
	local canvas1024x768 = love.graphics.newCanvas(canvasSize1024x768, canvasSize1024x768)
	for _, entry in ipairs(primaryGlyphMap) do
		local svgPath = paths.SOURCE_DIR .. "/assets/icons/" .. entry.inputFilename .. ".svg"
		local pngPath = paths.THEME_GLYPH_DIR_1024x768 .. "/" .. entry.outputPath .. ".png"
		glyphs.convertSvgToPng(svgPath, pngPath, GLYPH_HEIGHT_1024x768, canvas1024x768, DEFAULT_PADDING_1024x768)
	end
	return true
end

function glyphs.generateMuxLaunchGlyphs(muxLaunchGlyphMap)
	local baseOutputDir = paths.THEME_GRID_MUXLAUNCH
	local targetCanvasSize = 120 -- Grid glyphs are 120x120 for the default theme, 192x192 for the 1024x768 theme
	local muxLaunchPadding = 45 -- So increase padding for 1024x768 to 72 (x1.6)
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

	-- Generate additional set for 1024x768 (canvas size 192, padding 72)
	local baseOutputDir1024x768 = paths.THEME_GRID_MUXLAUNCH_1024x768
	local targetCanvasSize1024x768 = 192
	local muxLaunchPadding1024x768 = 72
	local glyphRenderHeight1024x768 = targetCanvasSize1024x768 - muxLaunchPadding1024x768
	local canvas1024x768 = love.graphics.newCanvas(targetCanvasSize1024x768, targetCanvasSize1024x768)
	logger.debug(
		string.format(
			"Generating %d muxlaunch glyphs for 1024x768 theme (canvas size: %dpx, render height: %dpx, padding: %dpx)",
			#muxLaunchGlyphMap,
			targetCanvasSize1024x768,
			glyphRenderHeight1024x768,
			muxLaunchPadding1024x768
		)
	)
	for _, entry in ipairs(muxLaunchGlyphMap) do
		local svgPath = paths.SOURCE_DIR .. "/assets/icons/" .. entry.inputFilename .. ".svg"
		local cleanOutputPath = entry.outputPath:gsub("^muxlaunch/", "")
		local pngPath = baseOutputDir1024x768 .. "/" .. cleanOutputPath .. ".png"
		if
			not glyphs.convertSvgToPng(
				svgPath,
				pngPath,
				glyphRenderHeight1024x768,
				canvas1024x768,
				muxLaunchPadding1024x768
			)
		then
			logger.warning("Failed to convert muxlaunch glyph for 1024x768: " .. entry.inputFilename)
		else
			successCount = successCount + 1
		end
	end

	return successCount > 0
end

-- Generate tester glyphs (muxtester/) at a larger height
function glyphs.generateTesterGlyphs(targetDir, testerGlyphMap)
	local canvasSize = GLYPH_HEIGHT_TESTER + DEFAULT_PADDING
	local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
	for _, entry in ipairs(testerGlyphMap) do
		local svgPath = paths.SOURCE_DIR .. "/assets/icons/" .. entry.inputFilename .. ".svg"
		local pngPath = targetDir .. "/" .. entry.outputPath .. ".png"
		glyphs.convertSvgToPng(svgPath, pngPath, GLYPH_HEIGHT_TESTER, canvas, DEFAULT_PADDING)
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

	-- Split glyph map into primary, muxlaunch, and tester glyphs
	local primaryGlyphMap, muxLaunchGlyphMap, testerGlyphMap = {}, {}, {}
	for _, entry in ipairs(glyphMap) do
		if entry.outputPath:match("^muxlaunch/") then
			table.insert(muxLaunchGlyphMap, entry)
		elseif entry.outputPath:match("^muxtester/") then
			table.insert(testerGlyphMap, entry)
		else
			table.insert(primaryGlyphMap, entry)
		end
	end
	local ok1 = glyphs.generatePrimaryGlyphs(targetDir, primaryGlyphMap)
	local ok2 = glyphs.generateMuxLaunchGlyphs(muxLaunchGlyphMap)
	local ok3 = glyphs.generateTesterGlyphs(targetDir, testerGlyphMap)
	return ok1 and ok2 and ok3
end

return glyphs
