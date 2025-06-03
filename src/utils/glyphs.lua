--- TODO: Address glyph sizing discrepancy between sips and TÖVE/LÖVE rendering at a fixed pixel height.
--- TODO: Re-implement glyph height calculation to ensure consistent visual size across different screen resolutions.

--- Glyph generation utilities
--
-- This module dynamically converts SVG icons to PNG format based on the mapping in glyph_map.txt
-- It replaces the static pre-generated PNGs with dynamically sized ones appropriate for the screen resolution
--
local love = require("love")
local system = require("utils.system")
local paths = require("paths")
local colorUtils = require("utils.color")
local state = require("state")
local logger = require("utils.logger")
local errorHandler = require("error_handler")

local glyphs = {}

local GLYPH_HEIGHT = 22
local FIXED_STROKE_WIDTH = 1.5
local GLYPH_MAPPINGS_DIR = paths.SOURCE_DIR .. "/utils/glyph_mappings"
local BASE_VERSION = "2502.0_PIXIE"

-- Helper function to load and parse a single glyph map file
local function loadMapFile(mapFilePath)
	local mapContent = system.readFile(mapFilePath)

	if not mapContent then
		return nil
	end

	local mapEntries = {}

	-- Parse each line
	for line in mapContent:gmatch("[^\r\n]+") do
		-- Skip comments and empty lines
		if not line:match("^%s*#") and not line:match("^%s*$") then
			-- Check for removal entry (starts with -)
			if line:match("^%s*%-(.+)") then
				local outputPathToRemove = line:match("^%s*%-(.+)")
				table.insert(mapEntries, { type = "remove", outputPath = outputPathToRemove:match("^%s*(.-)%s*$") })
			else
				-- Assume addition or override entry
				local outputPath, inputFilename = line:match("([^,]+),%s*(.+)")
				if outputPath and inputFilename then
					-- Trim whitespace
					table.insert(mapEntries, {
						type = "add_or_override",
						outputPath = outputPath:match("^%s*(.-)%s*$"),
						inputFilename = inputFilename:match("^%s*(.-)%s*$"),
					})
				else
					logger.warning("Skipping malformed line in glyph map: " .. line)
				end
			end
		end
	end

	logger.debug(string.format("Loaded %d entries from glyph map file '%s'", #mapEntries, mapFilePath))

	return mapEntries
end

-- Read the glyph mapping files and return the merged map
function glyphs.readGlyphMap()
	local normalizedSystemVersion = system.getNormalizedSystemVersion()
	local baseMapPath = GLYPH_MAPPINGS_DIR .. "/" .. BASE_VERSION .. ".txt"
	local baseMapEntries = loadMapFile(baseMapPath)

	if not baseMapEntries then
		-- Cannot proceed without the base map
		errorHandler.setError("Failed to read base glyph map file: " .. baseMapPath)
		return nil
	end

	-- Convert base map entries to a dictionary for easier merging
	local mergedMap = {}
	for _, entry in ipairs(baseMapEntries) do
		if entry.type == "add_or_override" then
			mergedMap[entry.outputPath] = entry
		end
		-- Removal entries in the base map should theoretically not exist,
		-- but we'll ignore them just in case.
	end

	if normalizedSystemVersion and normalizedSystemVersion ~= BASE_VERSION then
		logger.debug("Extracted normalized version name: " .. normalizedSystemVersion)
		local versionMapPath = GLYPH_MAPPINGS_DIR .. "/" .. normalizedSystemVersion .. ".txt"
		local versionMapEntries = loadMapFile(versionMapPath)

		if versionMapEntries then
			logger.debug("Merging glyph map for version: " .. normalizedSystemVersion)
			-- Merge version-specific entries
			local additions = 0
			local removals = 0
			local overrides = 0

			for _, entry in ipairs(versionMapEntries) do
				if entry.type == "remove" then
					if mergedMap[entry.outputPath] then
						logger.debug("Removing glyph mapping: " .. entry.outputPath)
						removals = removals + 1
					else
						logger.debug("Attempted to remove non-existent glyph mapping: " .. entry.outputPath)
					end
					mergedMap[entry.outputPath] = nil -- Remove the entry
				elseif entry.type == "add_or_override" then
					if mergedMap[entry.outputPath] then
						logger.debug(
							"Overriding glyph mapping: " .. entry.outputPath .. " with " .. entry.inputFilename
						)
						overrides = overrides + 1
					else
						additions = additions + 1
					end
					mergedMap[entry.outputPath] = entry -- Add or override the entry
				end
			end
			logger.debug(
				string.format("Merge summary: Additions=%d, Removals=%d, Overrides=%d", additions, removals, overrides)
			)
		else
			logger.warning(
				"Version-specific glyph map not found or unreadable for "
					.. normalizedSystemVersion
					.. ", using base map"
			)
		end
	elseif normalizedSystemVersion and normalizedSystemVersion == BASE_VERSION then
		logger.debug("Using base glyph map")
	else
		logger.warning(string.format("systemVersion: '%s', BASE_VERSION: '%s'", normalizedSystemVersion, BASE_VERSION))
		return nil
	end

	-- Convert merged map dictionary back to a list (order doesn't strictly matter for generation)
	local finalGlyphMap = {}
	for _, entry in pairs(mergedMap) do
		table.insert(finalGlyphMap, { outputPath = entry.outputPath, inputFilename = entry.inputFilename })
	end

	logger.debug(string.format("Final merged glyph map contains %d entries", #finalGlyphMap))

	return finalGlyphMap
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
-- Optionally accepts a padding value to use instead of the fixed stroke width for canvas size.
-- The glyphHeight parameter should be the size the glyph itself is rendered at *before* padding.
function glyphs.convertSvgToPng(svgPath, pngPath, glyphRenderHeight, fgColor, padding)
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
	-- Always use the FIXED_STROOKE_WIDTH for the SVG stroke itself
	svgContent = overrideStrokeWidth(svgContent, FIXED_STROKE_WIDTH)

	-- Use provided padding or default to FIXED_STROKE_WIDTH for canvas size
	local effectivePad = padding or FIXED_STROKE_WIDTH
	-- The canvas size is the render height plus padding
	local canvasSize = glyphRenderHeight + effectivePad

	-- Use TÖVE's prescale parameter to rasterize at the target render size
	local tove = require("tove")
	-- tove.newGraphics scales to the provided glyphRenderHeight based on the SVG's viewbox/size
	local graphics = tove.newGraphics(svgContent, glyphRenderHeight)
	-- Keep the line width consistent with the override performed above
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
	love.graphics.translate(effectivePad / 2, effectivePad / 2)
	-- Draw the graphic scaled to fit the glyphRenderHeight within the padded canvas
	graphics:draw(glyphRenderHeight / 2, glyphRenderHeight / 2)
	love.graphics.pop()

	love.graphics.setCanvas(prevCanvas)

	-- Get image data and encode as PNG
	local imageData = canvas:newImageData()
	local pngData = imageData:encode("png")

	if not system.writeFile(pngPath, pngData:getString()) then
		logger.error("Failed to write PNG file: " .. pngPath)
		return false
	end

	return true
end

-- Copy header icons directory
function glyphs.copyHeaderIcons(sourceDir, targetDir)
	logger.debug(string.format("Copying header icons from '%s' to '%s'", sourceDir, targetDir))

	-- Ensure the target directory exists (header directory should be at same level as other category dirs)
	local headerDir = targetDir .. "/header"
	if not system.ensurePath(headerDir) then
		logger.error("Failed to create header directory: " .. headerDir)
		return false
	end

	-- Use system.copyDir for direct directory copy if available
	if system.copyDir then
		local success = system.copyDir(sourceDir, headerDir)
		if success then
			logger.debug("Successfully copied header directory using system.copyDir")
			return true
		else
			logger.warning("Failed to copy header directory using system.copyDir, falling back to file-by-file copy")
		end
	end

	-- Get list of files in the source directory
	local files = system.listFiles(sourceDir, "*")
	if not files or #files == 0 then
		logger.error("Failed to read source directory or no files found: " .. sourceDir)
		return false
	end

	logger.debug("Found " .. #files .. " files to copy from " .. sourceDir)

	-- Copy each file from source to target
	local successCount = 0
	for _, filename in ipairs(files) do
		local sourcePath = sourceDir .. "/" .. filename
		local targetPath = headerDir .. "/" .. filename

		logger.debug("Copying header icon file: " .. filename .. " from " .. sourcePath .. " to " .. targetPath)

		-- Read source file
		local fileData = system.readFile(sourcePath)
		if not fileData then
			logger.warning("Failed to read header icon: " .. sourcePath)
		else
			-- Write to target path
			if not system.writeFile(targetPath, fileData) then
				logger.warning("Failed to write header icon: " .. targetPath)
			else
				successCount = successCount + 1
			end
		end
	end

	logger.debug(
		string.format("Copied %d of %d header icons from %s to %s", successCount, #files, sourceDir, headerDir)
	)
	return successCount > 0
end

-- Generate all glyphs based on glyph map
function glyphs.generateGlyphs(targetDir)
	local glyphMap = glyphs.readGlyphMap()
	if not glyphMap then
		return false
	end

	local svgBaseDir = paths.SOURCE_DIR .. "/assets/icons/lucide/glyph"
	local baseOutputDir = targetDir

	local glyphHeight = GLYPH_HEIGHT

	-- Get foreground color for icons
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	logger.debug(
		string.format("Generating glyphs with height %dpx and stroke width %.2fpx", glyphHeight, FIXED_STROKE_WIDTH)
	)

	for _, entry in ipairs(glyphMap) do
		local svgPath = svgBaseDir .. "/" .. entry.inputFilename .. ".svg"
		local pngPath = baseOutputDir .. "/" .. entry.outputPath .. ".png"

		glyphs.convertSvgToPng(svgPath, pngPath, glyphHeight, fgColor)
	end

	-- Copy header icons directly
	glyphs.copyHeaderIcons(paths.HEADER_GLYPHS_SOURCE_DIR, baseOutputDir)

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
		logger.error("Failed to read glyph map for muxlaunch glyph generation")
		return false
	end

	local muxLaunchGlyphMap = {}
	for _, entry in ipairs(glyphMap) do
		if entry.outputPath:match("^muxlaunch/") then
			table.insert(muxLaunchGlyphMap, entry)
		end
	end

	local svgBaseDir = paths.SOURCE_DIR .. "/assets/icons/lucide/glyph"
	local baseOutputDir = paths.THEME_GRID_MUXLAUNCH

	local targetCanvasSize = 120 -- Desired final image size (with padding)
	local muxLaunchPadding = 45
	-- Calculate the render height needed for the glyph itself
	local glyphRenderHeight = targetCanvasSize - muxLaunchPadding

	-- Get foreground color for icons
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	logger.debug(
		string.format(
			"Generating %d muxlaunch glyphs targeting %dpx canvas size (render height: %dpx, stroke width: %.2fpx, padding: %dpx)",
			#muxLaunchGlyphMap,
			targetCanvasSize,
			glyphRenderHeight,
			FIXED_STROKE_WIDTH,
			muxLaunchPadding
		)
	)

	local successCount = 0
	for _, entry in ipairs(muxLaunchGlyphMap) do
		local svgPath = svgBaseDir .. "/" .. entry.inputFilename .. ".svg"
		-- Remove the "muxlaunch/" prefix from the outputPath before joining
		local cleanOutputPath = entry.outputPath:gsub("^muxlaunch/", "")
		local pngPath = baseOutputDir .. "/" .. cleanOutputPath .. ".png"

		-- Call convertSvgToPng with the calculated render height and specific padding
		if not glyphs.convertSvgToPng(svgPath, pngPath, glyphRenderHeight, fgColor, muxLaunchPadding) then
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

	-- Get foreground color for icons
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	logger.debug(
		string.format("Generating %d footer glyphs from '%s' to '%s'", #footerGlyphMappings, sourceDir, targetDir)
	)

	local successCount = 0
	for _, mapping in ipairs(footerGlyphMappings) do
		local svgPath = sourceDir .. "/" .. mapping.sourceFile
		local pngPath = targetDir .. "/" .. mapping.outputFile

		logger.debug(
			string.format(
				"Converting footer glyph: %s (height: %d) -> %s",
				mapping.sourceFile,
				mapping.height,
				mapping.outputFile
			)
		)

		if not glyphs.convertSvgToPng(svgPath, pngPath, mapping.height, fgColor) then
			logger.warning("Failed to convert footer glyph: " .. mapping.sourceFile)
		else
			successCount = successCount + 1
		end
	end

	logger.debug(string.format("Generated %d of %d footer glyphs.", successCount, #footerGlyphMappings))

	return successCount > 0
end

return glyphs
