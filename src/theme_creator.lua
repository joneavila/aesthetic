--- Theme creation functionality
local love = require("love")

local colorUtils = require("utils.color")
local errorHandler = require("error_handler")
local paths = require("paths")
local state = require("state")

local fonts = require("ui.fonts")

local commands = require("utils.commands")
local imageGenerator = require("utils.image_generator")
local logger = require("utils.logger")
local rgb = require("utils.rgb")
local schemeConfigurator = require("utils.scheme_configurator")
local system = require("utils.system")

-- Module table to export public functions
local themeCreator = {}

-- Supported resolutions for theme generation
local SUPPORTED_RESOLUTIONS = {
	"640x480",
	"720x480",
	"720x576",
	"720x720",
	"1024x768",
	"1280x720",
}

-- Helper function to execute a function for all supported resolutions
-- Executes the function for each supported resolution, temporarily setting screen dimensions
-- The function receives no parameters and should use state.screenWidth/screenHeight
local function executeForAllResolutions(func)
	-- Store original dimensions
	local originalWidth, originalHeight = state.screenWidth, state.screenHeight

	-- Execute for all supported resolutions
	for _, resolution in ipairs(SUPPORTED_RESOLUTIONS) do
		local width, height = resolution:match("(%d+)x(%d+)")
		width, height = tonumber(width), tonumber(height)

		-- Set screen dimensions for this resolution
		state.screenWidth, state.screenHeight = width, height

		-- Execute the function
		local success = func()
		if not success then
			-- Restore original dimensions before returning
			state.screenWidth, state.screenHeight = originalWidth, originalHeight
			return false
		end
	end

	-- Restore original dimensions
	state.screenWidth, state.screenHeight = originalWidth, originalHeight
	return true
end

-- Helper function to copy resolution-specific template files
-- Copies all resolution directories from templates
local function copyAllResolutionTemplates()
	-- Copy all resolution directories
	for _, resolution in ipairs(SUPPORTED_RESOLUTIONS) do
		local sourcePath = paths.TEMPLATE_DIR .. "/" .. resolution
		local destPath = paths.WORKING_THEME_DIR .. "/" .. resolution

		if system.isDir(sourcePath) then
			if not system.copyDir(sourcePath, destPath) then
				return false
			end
		end
	end
	return true
end

-- Helper function to reset graphics state between image generation calls
-- Sets blend mode to default, clears any active canvas, and sets color to default
local function resetGraphicsState()
	love.graphics.setBlendMode("alpha")
	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1, 1)
end

-- Function to create `name.txt` containing the theme's name
local function createNameFile()
	-- Use the theme name from state
	local name = state.themeName
	logger.debug("Using theme name: " .. name)
	return system.createTextFile(paths.THEME_NAME, name)
end

-- Helper function to execute boot image creation for all supported resolutions with color caching
-- This optimized version caches color conversions outside the resolution loop since colors are resolution-independent
local function executeBootImageForAllResolutions()
	-- Store original dimensions
	local originalWidth, originalHeight = state.screenWidth, state.screenHeight

	-- Cache color conversions once since they don't change between resolutions
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	-- Execute for all supported resolutions
	for _, resolution in ipairs(SUPPORTED_RESOLUTIONS) do
		local width, height = resolution:match("(%d+)x(%d+)")
		width, height = tonumber(width), tonumber(height)

		-- Set screen dimensions for this resolution
		state.screenWidth, state.screenHeight = width, height

		-- Create boot image with cached colors
		if not system.fileExists(paths.THEME_BOOTLOGO_SOURCE) then
			-- Restore original dimensions before returning
			state.screenWidth, state.screenHeight = originalWidth, originalHeight
			return false
		end

		local options = {
			width = state.screenWidth,
			height = state.screenHeight,
			iconPath = paths.THEME_BOOTLOGO_SOURCE,
			iconSize = 180,
			outputPath = paths.getThemeBootlogoImagePath(),
			saveAsBmp = true,
			bgColor = bgColor,
			fgColor = fgColor,
		}

		local result = imageGenerator.createIconImage(options)
		resetGraphicsState()
		if result == false then
			errorHandler.setError("Failed to create boot logo image")
			-- Restore original dimensions before returning
			state.screenWidth, state.screenHeight = originalWidth, originalHeight
			return false
		end
	end

	-- Restore original dimensions
	state.screenWidth, state.screenHeight = originalWidth, originalHeight
	return true
end

-- Function to create reboot image shown during reboot
local function createRebootImage()
	local options = {
		width = state.screenWidth,
		height = state.screenHeight,
		iconPath = paths.THEME_REBOOT_ICON_SOURCE,
		iconSize = 50,
		backgroundLogoPath = paths.THEME_LOGO_OUTLINE_SOURCE,
		backgroundLogoSize = 180,
		text = "Rebooting",
		outputPath = paths.THEME_REBOOT_IMAGE,
		saveAsBmp = false,
		bgColor = colorUtils.hexToLove(state.getColorValue("background")),
		fgColor = colorUtils.hexToLove(state.getColorValue("foreground")),
	}

	local result = imageGenerator.createIconImage(options)
	resetGraphicsState()
	if result == false then
		errorHandler.setError("Failed to create reboot image")
		return false
	end

	return true
end

-- Function to create shutdown image shown during shutdown
local function createShutdownImage()
	local options = {
		width = state.screenWidth,
		height = state.screenHeight,
		iconPath = paths.THEME_SHUTDOWN_ICON_SOURCE,
		iconSize = 50,
		backgroundLogoPath = paths.THEME_LOGO_OUTLINE_SOURCE,
		backgroundLogoSize = 180,
		text = "Shutting down",
		outputPath = paths.THEME_SHUTDOWN_IMAGE,
		saveAsBmp = false,
		bgColor = colorUtils.hexToLove(state.getColorValue("background")),
		fgColor = colorUtils.hexToLove(state.getColorValue("foreground")),
	}

	local result = imageGenerator.createIconImage(options)
	resetGraphicsState()
	if result == false then
		errorHandler.setError("Failed to create shutdown image")
		return false
	end

	return true
end

-- Function to create charge image shown during charging
local function createChargeImage()
	local options = {
		width = state.screenWidth,
		height = state.screenHeight,
		iconPath = paths.THEME_CHARGE_ICON_SOURCE,
		iconSize = 50,
		backgroundLogoPath = paths.THEME_LOGO_OUTLINE_SOURCE,
		backgroundLogoSize = 180,
		text = "Charging",
		outputPath = paths.THEME_CHARGE_IMAGE,
		saveAsBmp = false,
		bgColor = colorUtils.hexToLove(state.getColorValue("background")),
		fgColor = colorUtils.hexToLove(state.getColorValue("foreground")),
	}

	local result = imageGenerator.createIconImage(options)
	resetGraphicsState()
	if result == false then
		errorHandler.setError("Failed to create charge image")
		return false
	end

	return true
end

-- Function to create preview image displayed in muOS theme selection menu
local function createPreviewImage()
	local result = imageGenerator.createPreviewImage(paths.getThemePreviewImagePath())
	resetGraphicsState()
	return result
end

-- Function to create `credits.txt` file containing the theme's credits
local function createCreditsFile()
	local content = "Created using Aesthetic for muOS: https://github.com/joneavila/aesthetic"
	return system.createTextFile(paths.THEME_CREDITS, content)
end

-- Function to create `version.txt` file containing the compatible muOS version
-- This function ensures that the theme is always read as compatible by muOS
local function createVersionFile()
	-- Try primary version file
	local content
	if system.fileExists(paths.MUOS_VERSION_PIXIE) then
		content = system.readFile(paths.MUOS_VERSION_PIXIE)
	elseif system.fileExists(paths.MUOS_VERSION_GOOSE) then
		content = system.readFile(paths.MUOS_VERSION_GOOSE)
	else
		errorHandler.setError("muOS version file not found in any known location")
		return false
	end

	-- Extract just the version number using pattern matching (digits with zero or more periods followed by underscore)
	local parsedVersion = content and content:match("(%d[%d%.]+)_")
	if not parsedVersion then
		errorHandler.setError("muOS version could not be parsed from version file")
		return false
	end

	return system.createTextFile(paths.THEME_VERSION, parsedVersion)
end

-- Function to find and copy the selected font file to theme directory
local function copySelectedFont()
	-- TEMPORARILY SIMPLIFIED: Using single .bin file per font while making font size feature more robust
	-- Find the selected font definition
	local fontFamilyDefinition
	for _, font in ipairs(fonts.themeDefinitions) do
		if font.name == state.fontFamily then
			fontFamilyDefinition = font
			break
		end
	end
	if not fontFamilyDefinition then
		errorHandler.setError("Selected font not found: " .. tostring(state.fontFamily))
		return false
	end

	-- Extract the directory from the TTF path and combine with the .bin filename
	local fontDirectory = fontFamilyDefinition.path:match("^(.+)/[^/]+$")
	local fontSourcePath = fontDirectory .. "/" .. fontFamilyDefinition.file
	logger.debug("Copying font file: " .. fontSourcePath)
	if not system.copyFile(fontSourcePath, paths.THEME_DEFAULT_FONT) then
		return false
	end

	return true

	--[[ ORIGINAL CODE: Commented out while making font size feature more robust
	-- Find and copy the selected font file
	local fontFamilyFile
	for _, font in ipairs(fonts.themeDefinitions) do
		if font.name == fonts.getSelectedFont() then
			fontFamilyFile = font.file
			break
		end
	end
	if not fontFamilyFile then
		errorHandler.setError("Selected font not found: " .. tostring(fonts.getSelectedFont()))
		return false
	end

	-- Get the font size directory
	local fontSizeDir
	local existingFontSize, result = pcall(function()
		return fonts.themeFontSizeOptions[fonts.getFontSize()]
	end)
	if not existingFontSize or not result then
		errorHandler.setError("Failed to get font size: " .. tostring(fonts.getFontSize()))
		return false
	end
	fontSizeDir = result

	-- Copy the selected font file as default.bin
	local fontSourcePath = "assets/fonts/"
		.. fontFamilyFile:gsub("%.bin$", "")
		.. "/"
		.. fontFamilyFile:gsub("%.bin$", "")
		.. "_"
		.. fontSizeDir
		.. ".bin"
	logger.debug("Copying font file: " .. fontSourcePath .. " for font size option: " .. tostring(fonts.getFontSize()))
	if not system.copyFile(fontSourcePath, paths.THEME_DEFAULT_FONT) then
		return false
	end

	return true
	--]]
end

-- Function to copy sound files to the theme
local function copySoundFiles()
	return system.copyDir(paths.THEME_SOUND_SOURCE_DIR, paths.THEME_SOUND_DIR)
end

-- Function to install the theme to muOS active theme directory
function themeCreator.installTheme(themeName)
	logger.debug("Installing theme: " .. themeName)
	local status, err = xpcall(function()
		if state.isDevelopment then
			logger.info("Skipping theme installation: Running in development environment")
			return true -- Return success but don't actually install
		end

		if not system.fileExists(paths.THEME_INSTALL_SCRIPT) then
			return true -- Return success but don't actually install
		end

		-- If script exists, proceed with installation
		local cmd = string.format('%s install "%s"', paths.THEME_INSTALL_SCRIPT, themeName)
		local result = commands.executeCommand(cmd)
		return result == 0
	end, debug.traceback)

	if not status then
		errorHandler.setError("Error during installation: " .. tostring(err))
		return false
	end

	return status
end

-- Clean up working directory
function themeCreator.cleanup()
	system.removeDir(paths.WORKING_THEME_DIR)
	resetGraphicsState()
end

-- Coroutine-based theme creation that yields control for animations
function themeCreator.createThemeCoroutine()
	return coroutine.create(function()
		local status, result = xpcall(function()
			logger.debug("Starting coroutine-based theme creation")

			coroutine.yield("Copying scheme template files...")
			-- Copy template directory contents to working directory
			local templateItems = system.listDir(paths.TEMPLATE_DIR)
			if not templateItems then
				return false
			end
			for _, item in ipairs(templateItems) do
				local sourcePath = paths.TEMPLATE_DIR .. "/" .. item
				local destPath = paths.WORKING_THEME_DIR .. "/" .. item

				-- Skip resolution directories (they will be handled by copyResolutionTemplates)
				-- and scheme directory (handled separately below)
				local isResolutionDir = false
				for _, resolution in ipairs(SUPPORTED_RESOLUTIONS) do
					if item == resolution then
						isResolutionDir = true
						break
					end
				end

				if item ~= "scheme" and not isResolutionDir then
					if system.isDir(sourcePath) then
						if not system.copyDir(sourcePath, destPath) then
							return false
						end
					elseif system.isFile(sourcePath) then
						if not system.copyFile(sourcePath, destPath) then
							return false
						end
					else
						errorHandler.setError("Source path does not exist: " .. sourcePath)
						return false
					end
				end
			end

			-- Copy resolution-specific template files
			coroutine.yield("Copying resolution templates...")
			if not copyAllResolutionTemplates() then
				return false
			end

			-- Now handle the contents of the scheme directory, copying them to the working theme directory
			coroutine.yield("Setting up theme structure...")
			local schemeItems = system.listDir(paths.THEME_SCHEME_SOURCE_DIR)
			if not schemeItems then
				return false
			end
			for _, item in ipairs(schemeItems) do
				local sourcePath = paths.THEME_SCHEME_SOURCE_DIR .. "/" .. item
				local destPath = paths.THEME_SCHEME_DIR .. "/" .. item
				if system.isDir(sourcePath) then
					if not system.copyDir(sourcePath, destPath) then
						return false
					end
				elseif system.isFile(sourcePath) then
					if not system.copyFile(sourcePath, destPath) then
						return false
					end
				else
					errorHandler.setError("Source path does not exist: " .. sourcePath)
					return false
				end
			end

			-- Apply grid settings to muxlaunch.ini in the resolution-specific directory
			coroutine.yield("Configuring grid settings...")
			if
				not executeForAllResolutions(function()
					local muxlaunchIniPath = paths.getThemeResolutionMuxlaunchIniPath()
					return schemeConfigurator.applyGridSettings(muxlaunchIniPath)
				end)
			then
				return false
			end

			local glyphs = require("utils.glyphs")

			coroutine.yield("Generating primary glyphs...")
			if not glyphs.generateGlyphs(paths.THEME_GLYPH_DIR) then
				return false
			end

			coroutine.yield("Generating home screen grid glyphs...")
			if not glyphs.generateMuxLaunchGlyphs() then
				return false
			end

			coroutine.yield("Generating footer glyphs...")
			if not glyphs.generateFooterGlyphs() then
				return false
			end

			coroutine.yield("Creating boot images...")
			if not executeBootImageForAllResolutions() then
				return false
			end

			coroutine.yield("Creating shutdown image...")
			if not createShutdownImage() then
				return false
			end

			coroutine.yield("Creating charge image...")
			if not createChargeImage() then
				return false
			end

			-- Reset graphics state before creating reboot image
			coroutine.yield("Creating reboot image...")
			resetGraphicsState()
			if not createRebootImage() then
				return false
			end
			resetGraphicsState()

			coroutine.yield("Creating preview images...")
			if not executeForAllResolutions(createPreviewImage) then
				return false
			end

			coroutine.yield("Applying color settings...")
			if not schemeConfigurator.applyColorSettings(paths.THEME_SCHEME_GLOBAL) then
				return false
			end

			if not schemeConfigurator.applyGlyphSettings(paths.THEME_SCHEME_GLOBAL) then
				return false
			end

			coroutine.yield("Applying font padding settings...")
			if not schemeConfigurator.applyFontListPaddingSettings(paths.THEME_SCHEME_GLOBAL) then
				return false
			end

			coroutine.yield("Applying content padding left settings...")
			if not schemeConfigurator.applyContentPaddingLeftSettings(paths.THEME_SCHEME_GLOBAL, state.screenWidth) then
				return false
			end

			coroutine.yield("Applying content width settings...")
			if not schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_GLOBAL, state.screenWidth) then
				return false
			end
			if not schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_MUXPLORE, state.screenWidth) then
				return false
			end
			if not schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_MUXHISTORY, state.screenWidth) then
				return false
			end
			if not schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_MUXCOLLECT, state.screenWidth) then
				return false
			end

			coroutine.yield("Applying alignment settings...")
			if not schemeConfigurator.applyNavigationAlignmentSettings(paths.THEME_SCHEME_GLOBAL) then
				return false
			end
			if not schemeConfigurator.applyStatusAlignmentSettings(paths.THEME_SCHEME_GLOBAL) then
				return false
			end
			if not schemeConfigurator.applyHeaderAlignmentSettings(paths.THEME_SCHEME_GLOBAL) then
				return false
			end
			if not schemeConfigurator.applyDatetimeSettings(paths.THEME_SCHEME_GLOBAL) then
				return false
			end

			coroutine.yield("Applying alpha settings...")
			if not schemeConfigurator.applyHeaderOpacity(paths.THEME_SCHEME_GLOBAL) then
				return false
			end
			if not schemeConfigurator.applyNavigationAlphaSettings(paths.THEME_SCHEME_GLOBAL) then
				return false
			end

			coroutine.yield("Copying font files...")
			if not copySelectedFont() then
				return false
			end

			coroutine.yield("Creating text files...")
			if not createCreditsFile() then
				return false
			end
			if not createVersionFile() then
				return false
			end
			if not createNameFile() then
				return false
			end

			if state.hasRGBSupport then
				coroutine.yield("Setting up RGB configuration...")
				if not rgb.createConfigFile(paths.THEME_RGB_DIR, paths.THEME_RGB_CONF) then
					return false
				end
			end

			coroutine.yield("Copying sound files...")
			if not copySoundFiles() then
				return false
			end

			coroutine.yield("Creating theme archive...")
			local outputThemePath = system.createArchive(paths.WORKING_THEME_DIR, paths.getThemeOutputPath())
			if not outputThemePath then
				return false
			end

			coroutine.yield("Cleaning up...")
			system.removeDir(paths.WORKING_THEME_DIR)

			coroutine.yield("Syncing filesystem...")
			commands.executeCommand("sync")

			resetGraphicsState()

			return outputThemePath
		end, debug.traceback)

		if not status then
			-- Always reset graphics state, even on error
			resetGraphicsState()
			logger.error("Coroutine error: " .. tostring(result))
			errorHandler.setError(tostring(result))
			return false, "Error: " .. tostring(result)
		end

		-- Return the path from the successful execution
		return true, result
	end)
end

-- Coroutine-based theme installation that yields control for animations
function themeCreator.installThemeCoroutine(themeName)
	return coroutine.create(function()
		logger.debug("Starting coroutine-based theme installation")

		local status, result = xpcall(function()
			coroutine.yield("Preparing installation...")

			if state.isDevelopment then
				logger.info("Skipping theme installation: Running in development environment")
				coroutine.yield("Development mode - skipping...")
				return true
			end

			if not system.fileExists(paths.THEME_INSTALL_SCRIPT) then
				coroutine.yield("Install script not found - skipping...")
				return true
			end

			coroutine.yield("Installing theme files...")

			-- If script exists, proceed with installation
			local cmd = string.format('%s install "%s"', paths.THEME_INSTALL_SCRIPT, themeName)
			local installResult = commands.executeCommand(cmd)

			coroutine.yield("Finalizing installation...")

			return installResult == 0
		end, debug.traceback)

		if not status then
			errorHandler.setError("Error during installation: " .. tostring(result))
			return false, "Installation failed: " .. tostring(result)
		end

		return status, result
	end)
end

return themeCreator
