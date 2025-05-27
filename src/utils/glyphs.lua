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

local GLYPH_HEIGHT = 24
local FIXED_STROKE_WIDTH = 1.5
local GLYPH_MAPPINGS_DIR = paths.ROOT_DIR .. "/utils/glyph_mappings"
local BASE_VERSION = "PIXIE"

-- Helper function to load and parse a single glyph map file
local function loadMapFile(mapFilePath)
	logger.debug("Attempting to load glyph map file: " .. mapFilePath)

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

	logger.debug(string.format("Loaded %d entries from %s", #mapEntries, mapFilePath))

	return mapEntries
end

-- Read the glyph mapping files and return the merged map
function glyphs.readGlyphMap()
	logger.debug("Starting glyph map reading process.")

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

	logger.debug(string.format("Base map (%s) loaded with %d entries.", BASE_VERSION, #baseMapEntries))

	local systemVersion = system.getSystemVersion()
	logger.debug("Detected system version string: " .. tostring(systemVersion))
	local versionName = ""

	-- Extract version name from system version string (part after the last underscore)
	local _, _, name = string.find(systemVersion, "_([^_]+)$")

	if name then
		-- Trim trailing whitespace and remove anything after a newline
		name = name:match("^%s*(.-)%s*$") -- Trim whitespace
		name = name:match("([^\n]+)") or name -- Remove part after newline if present
	end

	if name and name ~= BASE_VERSION then
		logger.debug("Extracted version name: " .. name)
		versionName = name
		local versionMapPath = GLYPH_MAPPINGS_DIR .. "/" .. versionName .. ".txt"
		local versionMapEntries = loadMapFile(versionMapPath)

		if versionMapEntries then
			logger.debug("Merging glyph map for version: " .. versionName)
			local initialMergedCount = #baseMapEntries -- Approximate count before merge
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
						logger.debug("Adding new glyph mapping: " .. entry.outputPath .. " -> " .. entry.inputFilename)
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
				"Version-specific glyph map not found or unreadable for " .. versionName .. ", using base map."
			)
		end
	else
		logger.warning(
			"Could not extract version name from system version string: "
				.. tostring(systemVersion)
				.. ", using base map."
		)
	end

	-- Convert merged map dictionary back to a list (order doesn't strictly matter for generation)
	local finalGlyphMap = {}
	for _, entry in pairs(mergedMap) do
		table.insert(finalGlyphMap, { outputPath = entry.outputPath, inputFilename = entry.inputFilename })
	end

	logger.debug(string.format("Final merged glyph map contains %d entries.", #finalGlyphMap))

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
	logger.debug(string.format("Attempting to convert SVG %s to PNG %s", svgPath, pngPath))

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
	logger.debug("Starting header icon copy from: " .. sourceDir .. " to target dir: " .. targetDir)

	-- Ensure the target directory exists (header directory should be at same level as other category dirs)
	local headerDir = targetDir .. "/header"
	if not system.ensurePath(headerDir) then
		logger.error("Failed to create header directory: " .. headerDir)
		return false
	end

	logger.debug("Created header directory: " .. headerDir)

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

	local svgBaseDir = paths.ROOT_DIR .. "/assets/icons/lucide/glyph"
	local baseOutputDir = targetDir

	local glyphHeight = GLYPH_HEIGHT

	-- Get foreground color for icons
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	logger.debug(
		"Generating glyphs with height: " .. glyphHeight .. "px and stroke width: " .. FIXED_STROKE_WIDTH .. "px"
	)

	for _, entry in ipairs(glyphMap) do
		local svgPath = svgBaseDir .. "/" .. entry.inputFilename .. ".svg"
		local pngPath = baseOutputDir .. "/" .. entry.outputPath .. ".png"

		-- Call convertSvgToPng, letting it default padding to FIXED_STROKE_WIDTH.
		-- The render height is the target height.
		if not glyphs.convertSvgToPng(svgPath, pngPath, glyphHeight, fgColor) then
			logger.warning("Failed to convert glyph: " .. entry.inputFilename)
		end
	end

	-- Copy header icons directly
	local headerSourceDir = paths.ROOT_DIR .. "/assets/icons/glyph/header"
	logger.debug("Copying header icons from: " .. headerSourceDir)
	glyphs.copyHeaderIcons(headerSourceDir, baseOutputDir)

	return true
end

--- Generates PNG files for icons specifically used in the muxlaunch grid view.
--- It reads the full glyph map but filters for entries with an outputPath that starts with `muxlaunch/`.
--- These filtered icons are then converted from their SVG source to PNG format.
--- The generated PNGs are saved to the directory specified by `paths.THEME_GRID_MUXLAUNCH`.
--- Icons are rendered at a specific height such that when 8px padding is added, the final image is 120x120px.
function glyphs.generateMuxLaunchGlyphs()
	logger.debug("Starting muxlaunch glyph generation process.")

	local glyphMap = glyphs.readGlyphMap()
	if not glyphMap then
		logger.error("Failed to read glyph map for muxlaunch glyph generation.")
		return false
	end

	local muxLaunchGlyphMap = {}
	for _, entry in ipairs(glyphMap) do
		if entry.outputPath:match("^muxlaunch/") then
			table.insert(muxLaunchGlyphMap, entry)
		end
	end

	local svgBaseDir = paths.ROOT_DIR .. "/assets/icons/lucide/glyph"
	local baseOutputDir = paths.THEME_GRID_MUXLAUNCH

	local targetCanvasSize = 120 -- Desired final image size (with padding)
	local muxLaunchPadding = 8 -- Specific padding requested for muxlaunch glyphs
	-- Calculate the render height needed for the glyph itself
	local glyphRenderHeight = targetCanvasSize - muxLaunchPadding

	-- Get foreground color for icons
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	logger.debug(
		string.format(
			"Generating %d muxlaunch glyphs targeting %dpx canvas size (render height: %dpx, stroke width: %fpx, padding: %dpx)",
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

return glyphs
