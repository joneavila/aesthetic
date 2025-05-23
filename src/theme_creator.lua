--- Theme creation functionality
local state = require("state")
local system = require("utils.system")
local errorHandler = require("error_handler")
local commands = require("utils.commands")
local rgb = require("utils.rgb")
local paths = require("paths")
local fonts = require("ui.fonts")
local imageGenerator = require("utils.image_generator")
local themeSettings = require("utils.theme_settings")
local logger = require("utils.logger")
local love = require("love")

-- Module table to export public functions
local themeCreator = {}

-- Helper function to reset graphics state between image generation calls
local function resetGraphicsState()
	-- Reset blend mode to default
	love.graphics.setBlendMode("alpha")
	-- Clear any active canvas
	love.graphics.setCanvas()
	-- Reset color to default
	love.graphics.setColor(1, 1, 1, 1)
end

-- Function to create `name.txt` containing the theme's name
local function createNameFile()
	-- Use application name as theme name
	return system.createTextFile(paths.THEME_NAME_PATH, state.applicationName)
end

-- Function to create boot logo image shown during boot
local function createBootImage()
	if not system.fileExists(paths.THEME_BOOTLOGO_SOURCE_PATH) then
		return false
	end

	-- Ensure resolution image directory exists before creating the boot image
	local resolutionImageDir = paths.getThemeResolutionImageDir()
	if not system.ensurePath(resolutionImageDir) then
		logger.error("Failed to create resolution image directory: " .. resolutionImageDir)
		return false
	end

	local options = {
		width = state.screenWidth,
		height = state.screenHeight,
		iconPath = paths.THEME_BOOTLOGO_SOURCE_PATH,
		iconSize = 180,
		outputPath = paths.getThemeBootlogoImagePath(),
		saveAsBmp = true,
	}

	local result = imageGenerator.createIconImage(options)
	resetGraphicsState()
	if result == false then
		errorHandler.setError("Failed to create boot logo image")
		return false
	end

	return true
end

-- Function to create reboot image shown during reboot
local function createRebootImage()
	local options = {
		width = state.screenWidth,
		height = state.screenHeight,
		iconPath = "assets/icons/lucide/ui/rotate-ccw.svg",
		iconSize = 100,
		text = "Rebooting...",
		outputPath = paths.THEME_REBOOT_IMAGE_PATH,
		saveAsBmp = false,
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
		iconPath = "assets/icons/lucide/ui/power.svg",
		iconSize = 100,
		text = "Shutting down...",
		outputPath = paths.THEME_SHUTDOWN_IMAGE_PATH,
		saveAsBmp = false,
	}

	local result = imageGenerator.createIconImage(options)
	resetGraphicsState()
	if result == false then
		errorHandler.setError("Failed to create shutdown image")
		return false
	end

	return true
end

-- Function to create preview image displayed in muOS theme selection menu
local function createPreviewImage()
	local result = imageGenerator.createPreviewImage(paths.getThemePreviewImagePath(), state.fonts)
	resetGraphicsState()
	return result
end

-- Function to create `credits.txt` file containing the theme's credits
local function createCreditsFile()
	local content = "Created using Aesthetic for muOS: https://github.com/joneavila/aesthetic"
	return system.createTextFile(paths.THEME_CREDITS_PATH, content)
end

-- Function to create `version.txt` file containing the compatible muOS version
local function createVersionFile()
	-- Read the content from the source file
	local content = system.readFile(paths.MUOS_VERSION_PATH)
	local versionNumber = system.getEnvironmentVariable("MUOS_VERSION")

	if content then
		-- Extract just the version number using pattern matching
		-- Pattern matches: digits with zero or more periods followed by underscore
		local parsedVersion = content:match("(%d[%d%.]+)_")

		if parsedVersion then
			versionNumber = parsedVersion
		else
			logger.debug("Could not parse version number from muOS version file, using default")
		end
	else
		logger.debug("Could not read muOS version file, using default version")
	end

	return system.createTextFile(paths.THEME_VERSION_PATH, versionNumber)
end

-- Function to find and copy the selected font file to theme directory based on screen height
local function copySelectedFont()
	-- Find and copy the selected font file
	local selectedFontFile
	for _, font in ipairs(fonts.choices) do
		if fonts.isSelected(font.name, state.selectedFont) then
			selectedFontFile = font.file
			break
		end
	end
	if not selectedFontFile then
		errorHandler.setError("Selected font not found: " .. tostring(state.selectedFont))
		return false
	end

	-- Default font size directory is 24pt
	local fontSizeDir = fonts.getFontSizeDir(state.fontSize)

	-- Copy the selected font file as default.bin
	local fontSourcePath = "assets/fonts/"
		.. selectedFontFile:gsub("%.bin$", "")
		.. "/"
		.. selectedFontFile:gsub("%.bin$", "")
		.. "_"
		.. fontSizeDir
		.. ".bin"
	if not system.copyFile(fontSourcePath, paths.THEME_DEFAULT_FONT_PATH) then
		logger.error("Failed to copy font file: " .. selectedFontFile .. " (size " .. fontSizeDir .. ")")
		return false
	end

	return true
end

-- Function to copy sound files to the theme
local function copySoundFiles()
	-- Get list of sound files
	local soundFiles = { "back.wav", "confirm.wav", "error.wav", "navigate.wav", "reboot.wav", "shutdown.wav" }

	-- Copy each sound file
	for _, filename in ipairs(soundFiles) do
		local sourcePath = paths.THEME_SOUND_SOURCE_DIR .. "/" .. filename
		local destPath = paths.THEME_SOUND_PATH .. "/" .. filename

		if not system.copyFile(sourcePath, destPath) then
			return false
		end
	end

	return true
end

-- Main function to create theme
function themeCreator.createTheme()
	local status, err = xpcall(function()
		-- Log screen dimensions for debugging
		logger.debug("Screen dimensions when creating theme: " .. state.screenWidth .. "x" .. state.screenHeight)

		-- Clean up and prepare working directory
		logger.debug("Cleaning working directory")
		system.removeDir(paths.WORKING_THEME_DIR)
		system.ensurePath(paths.WORKING_THEME_DIR)

		-- Copy glyph directory and contents
		logger.debug("Copying glyph directory and contents")
		if not system.copyDir(paths.THEME_GLYPH_SOURCE_PATH, paths.THEME_GLYPH_PATH) then
			return false
		end

		-- Copy scheme directory and contents
		logger.debug(
			"Copying scheme directory and contents, source: "
				.. paths.THEME_SCHEME_SOURCE_DIR
				.. ", destination: "
				.. paths.THEME_SCHEME_DIR
		)
		if not system.copyDir(paths.THEME_SCHEME_SOURCE_DIR, paths.THEME_SCHEME_DIR) then
			return false
		end

		-- Create theme's boot image
		logger.debug("Creating boot image")
		if not createBootImage() then
			logger.error("Failed to create boot image")
			return false
		end

		-- Create theme's shutdown image
		logger.debug("Creating shutdown image")
		if not createShutdownImage() then
			return false
		end

		-- Reset graphics state before creating reboot image
		resetGraphicsState()

		-- Create theme's reboot image
		logger.debug("Creating reboot image")
		if not createRebootImage() then
			return false
		end

		-- Reset graphics state after all image generation
		resetGraphicsState()

		-- Create theme's preview image
		logger.debug("Creating preview image")
		-- Ensure resolution directory exists before creating preview image
		local resolutionDir = paths.getThemeResolutionDir()
		logger.debug("Ensuring resolution directory exists: " .. resolutionDir)
		if not system.ensurePath(resolutionDir) then
			logger.error("Failed to create resolution directory: " .. resolutionDir)
			return false
		end
		-- Ensure resolution image directory exists
		local resolutionImageDir = paths.getThemeResolutionImageDir()
		logger.debug("Ensuring resolution image directory exists: " .. resolutionImageDir)
		if not system.ensurePath(resolutionImageDir) then
			logger.error("Failed to create resolution image directory: " .. resolutionImageDir)
			return false
		end
		if not createPreviewImage() then
			return false
		end

		-- Get hex colors from state (remove # prefix)
		local colorReplacements = {
			background = state.getColorValue("background"):gsub("^#", ""),
			foreground = state.getColorValue("foreground"):gsub("^#", ""),
		}

		-- Replace colors and apply glyph settings to theme files
		logger.debug("Replacing colors and applying glyph settings to theme files")
		if not system.replaceColor(paths.THEME_SCHEME_GLOBAL_PATH, colorReplacements) then
			return false
		end

		-- Set theme's glyph settings
		logger.debug("Setting theme's glyph settings")
		if not themeSettings.applyGlyphSettings(paths.THEME_SCHEME_GLOBAL_PATH) then
			return false
		end

		-- Set theme's screen width settings
		logger.debug("Setting theme's screen width settings")
		if not themeSettings.applyScreenWidthSettings(paths.THEME_SCHEME_GLOBAL_PATH, state.screenWidth) then
			return false
		end

		-- Set theme's content height settings
		logger.debug("Setting theme's content height settings")
		if not themeSettings.applyContentHeightSettings(paths.THEME_SCHEME_GLOBAL_PATH, state.screenHeight) then
			return false
		end

		-- Set theme's content width settings for `muxplore.ini`
		logger.debug("Setting theme's content width settings for `muxplore.ini`")
		if not themeSettings.applyContentWidth(paths.THEME_SCHEME_MUXPLORE_PATH) then
			return false
		end

		-- Set theme's antialiasing settings
		logger.debug("Setting theme's antialiasing settings")
		if not themeSettings.applyAntialiasingSettings(paths.THEME_SCHEME_GLOBAL_PATH) then
			return false
		end

		-- Set theme's navigation alignment settings
		logger.debug("Setting theme's navigation alignment settings")
		if not themeSettings.applyNavigationAlignmentSettings(paths.THEME_SCHEME_GLOBAL_PATH) then
			return false
		end

		-- Copy the selected font file
		logger.debug("Copying selected font file")
		if not copySelectedFont() then
			return false
		end

		-- Create theme's `credits.txt` file
		logger.debug("Creating theme's `credits.txt` file")
		if not createCreditsFile() then
			return false
		end

		-- Create theme's `version.txt` file
		logger.debug("Creating theme's `version.txt` file")
		if not createVersionFile() then
			return false
		end

		-- Create theme's `name.txt` file
		logger.debug("Creating theme's `name.txt` file")
		if not createNameFile() then
			return false
		end

		-- Create theme's RGB configuration file
		logger.debug("Creating theme's RGB configuration file")
		if not rgb.createConfigFile(paths.THEME_RGB_DIR, paths.THEME_RGB_CONF_PATH) then
			return false
		end

		-- Copy sound files to the theme
		logger.debug("Copying sound files to the theme")
		if not copySoundFiles() then
			return false
		end

		-- Create the ZIP archive
		logger.debug("Creating archive")
		local outputThemePath = system.createArchive(paths.WORKING_THEME_DIR, paths.THEME_OUTPUT_PATH)
		if not outputThemePath then
			return false
		end

		-- Call sync to make the theme available
		commands.executeCommand("sync")

		-- Final cleanup of graphics state
		resetGraphicsState()

		return outputThemePath
	end, debug.traceback)

	if not status then
		-- Always reset graphics state, even on error
		resetGraphicsState()
		logger.error("Error: " .. tostring(err))
		errorHandler.setError(tostring(err))
		return false
	end

	-- Return the path from the successful execution
	return err
end

-- Function to install the theme to muOS active theme directory
function themeCreator.installTheme(themeName)
	logger.debug("Installing theme: " .. themeName)
	local status, err = xpcall(function()
		-- Check if we're in development environment
		if state.isDevelopment then
			logger.info("Skipping theme installation: Running in development environment")
			return true -- Return success but don't actually install
		end

		-- Script path for production environment
		local scriptPath = "/opt/muos/script/package/theme.sh"

		-- Additional safety check - verify script exists
		if not system.fileExists(scriptPath) then
			logger.warning("Theme installation script not found at: " .. scriptPath)
			return true -- Return success but don't actually install
		end

		-- If script exists, proceed with installation
		local cmd = string.format('%s install "%s"', scriptPath, themeName)
		logger.debug("Executing install command: " .. cmd)
		local result = commands.executeCommand(cmd)
		logger.debug("Install theme result: " .. tostring(result))
		return result == 0
	end, debug.traceback)

	if not status then
		logger.error("Error during installation: " .. tostring(err))
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

return themeCreator
