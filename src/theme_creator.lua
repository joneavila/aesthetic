--- Theme creation functionality
local state = require("state")
local system = require("utils.system")
local errorHandler = require("error_handler")
local commands = require("utils.commands")
local rgb = require("utils.rgb")
local paths = require("paths")
local fontDefs = require("ui.font_defs")
local imageGenerator = require("utils.image_generator")
local themeSettings = require("utils.theme_settings")

-- Module table to export public functions
local themeCreator = {}

-- Function to create `name.txt` containing the theme's name
local function createNameFile()
	local content = state.applicationName -- Use application name as theme name
	return system.createTextFile(
		paths.THEME_NAME_PATH,
		content,
		"Failed to create `name.txt` file: " .. paths.THEME_NAME_PATH
	)
end

-- Function to create boot logo image shown during boot
local function createBootImage()
	print("[DEBUG:themeCreator:createBootImage] In createBootImage")
	print("[DEBUG:themeCreator:createBootImage] Icon path: " .. paths.THEME_BOOTLOGO_SOURCE_PATH)

	-- If the file does not exist, return false
	if not system.fileExists(paths.THEME_BOOTLOGO_SOURCE_PATH) then
		print("[DEBUG:themeCreator:createBootImage] File does not exist")
		errorHandler.setError("Boot logo image file does not exist: " .. paths.THEME_BOOTLOGO_SOURCE_PATH)
		return false
	end

	-- Create boot logo with muOS logo
	local options = {
		width = state.screenWidth,
		height = state.screenHeight,
		iconPath = paths.THEME_BOOTLOGO_SOURCE_PATH,
		iconSize = 180,
		outputPath = paths.THEME_BOOTLOGO_IMAGE_PATH,
		saveAsBmp = true,
	}

	print("[DEBUG:themeCreator:createBootImage] Calling createIconImage")
	local result = imageGenerator.createIconImage(options)
	if result == false then
		return false
	end

	return true
end

-- Function to create reboot image shown during reboot
local function createRebootImage()
	-- Create reboot image with icon and text
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
	if result == false then
		errorHandler.setError("Failed to create reboot image")
		return false
	end

	return true
end

-- Function to create shutdown image shown during shutdown
local function createShutdownImage()
	-- Create shutdown image with icon and text
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
	if result == false then
		errorHandler.setError("Failed to create shutdown image")
		return false
	end

	return true
end

-- Function to create preview image displayed in muOS theme selection menu
local function createPreviewImage()
	return imageGenerator.createPreviewImage(paths.THEME_PREVIEW_IMAGE_PATH)
end

-- Function to create `credits.txt` file containing the theme's credits
local function createCreditsFile()
	local creditsText = "Created using Aesthetic for muOS: https://github.com/joneavila/aesthetic"
	return system.createTextFile(
		paths.THEME_CREDITS_PATH,
		creditsText,
		"Failed to create `credits.txt` file: " .. paths.THEME_CREDITS_PATH
	)
end

-- Function to create `version.txt` file containing the compatible muOS version
local function createVersionFile()
	-- Read the content from the source file
	local content = system.readFile(paths.MUOS_VERSION_PATH)
	if not content then
		return false -- Error already set by system.readFile
	end

	-- Extract just the version number using pattern matching
	-- Pattern matches: digits with zero or more periods followed by underscore
	local versionNumber = content:match("(%d[%d%.]+)_")

	if not versionNumber then
		errorHandler.setError("Could not parse version number from muOS version file")
		return false
	end

	-- Write to the theme version file
	return system.createTextFile(
		paths.THEME_VERSION_PATH,
		versionNumber,
		"Failed to create `version.txt` file: " .. paths.THEME_VERSION_PATH
	)
end

-- Function to find and copy the selected font file to theme directory based on screen height
local function copySelectedFont()
	-- Find and copy the selected font file
	local selectedFontFile
	for _, font in ipairs(fontDefs.FONTS) do
		if font.name == state.selectedFont then
			selectedFontFile = font.file
			break
		end
	end
	if not selectedFontFile then
		print("[DEBUG:themeCreator:copySelectedFont] Selected font not found: " .. tostring(state.selectedFont))
		errorHandler.setError("Selected font not found: " .. tostring(state.selectedFont))
		return false
	end

	-- Get font size directory based on user setting
	local fontSizeDir = fontDefs.getFontSizeDir(state.fontSize)

	-- Copy the selected font file as default.bin
	local fontSourcePath = "assets/fonts/"
		.. selectedFontFile:gsub("%.bin$", "")
		.. "/"
		.. selectedFontFile:gsub("%.bin$", "")
		.. "_"
		.. fontSizeDir
		.. ".bin"
	if
		not system.copyFile(
			fontSourcePath,
			paths.THEME_DEFAULT_FONT_PATH,
			"Failed to copy font file: " .. selectedFontFile .. " (size " .. fontSizeDir .. ")"
		)
	then
		print(
			"[DEBUG:themeCreator:copySelectedFont] Failed to copy font file: "
				.. selectedFontFile
				.. " (size "
				.. fontSizeDir
				.. ")"
		)
		return false
	end

	print(
		"[DEBUG:themeCreator:copySelectedFont] Copied font file: "
			.. selectedFontFile
			.. " (size "
			.. fontSizeDir
			.. ")"
			.. "\nSource: "
			.. fontSourcePath
			.. "\nDestination: "
			.. paths.THEME_DEFAULT_FONT_PATH
	)
	return true
end

-- Function to create `rgb/rgbconf.sh` file containing the RGB lighting configuration
local function createRgbConfFile()
	-- Create RGB configuration file in the working theme directory
	return rgb.createConfigFile(paths.THEME_RGB_DIR, paths.THEME_RGB_CONF_PATH)
end

-- Function to copy sound files to the theme
local function copySoundFiles()
	-- Create sound directory if it doesn't exist
	if not system.ensurePath(paths.THEME_SOUND_PATH) then
		errorHandler.setError("Failed to create sound directory: " .. paths.THEME_SOUND_PATH)
		return false
	end

	-- Get list of sound files
	local soundFiles = { "back.wav", "confirm.wav", "error.wav", "navigate.wav", "reboot.wav", "shutdown.wav" }

	-- Copy each sound file
	for _, filename in ipairs(soundFiles) do
		local sourcePath = paths.THEME_SOUND_SOURCE_DIR .. "/" .. filename
		local destPath = paths.THEME_SOUND_PATH .. "/" .. filename

		if not system.copyFile(sourcePath, destPath, "Failed to copy sound file: " .. filename) then
			return false
		end
	end

	print("[DEBUG:themeCreator:copySoundFiles] Copied sound files to: " .. paths.THEME_SOUND_PATH)
	return true
end

-- Main function to create theme
function themeCreator.createTheme()
	print("[DEBUG:themeCreator:createTheme] Starting theme creation")
	local status, err = xpcall(function()
		-- Clean up and prepare working directory
		print("[DEBUG:themeCreator:createTheme] Removing working directory")
		system.removeDir(paths.WORKING_THEME_DIR)
		print("[DEBUG:themeCreator:createTheme] Creating working directory")
		system.ensurePath(paths.WORKING_THEME_DIR)

		-- Copy glyph directory and contents
		print("[DEBUG:themeCreator:createTheme] Copying glyph directory and contents")
		if not system.copyDir(paths.THEME_GLYPH_SOURCE_PATH, paths.THEME_GLYPH_PATH) then
			errorHandler.setError("Failed to copy glyph directory and contents")
			return false
		end

		-- Copy scheme directory and contents
		print("[DEBUG:themeCreator:createTheme] Copying scheme directory and contents")
		print("[DEBUG:themeCreator:createTheme] Source directory: " .. paths.THEME_SCHEME_SOURCE_DIR)
		print("[DEBUG:themeCreator:createTheme] Destination directory: " .. paths.THEME_SCHEME_DIR)
		if not system.copyDir(paths.THEME_SCHEME_SOURCE_DIR, paths.THEME_SCHEME_DIR) then
			print("[DEBUG:themeCreator:createTheme] Failed to copy scheme directory and contents")
			return false
		end

		-- Create theme's boot image
		print("[DEBUG:themeCreator:createTheme] Creating boot image")
		if not createBootImage() then
			print("[DEBUG:themeCreator:createTheme] Failed to create boot image")
			return false
		end

		-- Create theme's reboot image
		print("[DEBUG:themeCreator:createTheme] Creating reboot image")
		if not createRebootImage() then
			return false
		end

		-- Create theme's shutdown image
		print("[DEBUG:themeCreator:createTheme] Creating shutdown image")
		if not createShutdownImage() then
			return false
		end

		-- Create theme's preview image
		print("[DEBUG:themeCreator:createTheme] Creating preview image")
		if not createPreviewImage() then
			return false
		end

		-- Get hex colors from state (remove # prefix)
		local colorReplacementts = {
			background = state.getColorValue("background"):gsub("^#", ""),
			foreground = state.getColorValue("foreground"):gsub("^#", ""),
		}

		-- Replace colors and apply glyph settings to theme files
		print("[DEBUG:themeCreator:createTheme] Replacing colors and applying glyph settings to theme files")
		if not system.replaceColor(paths.THEME_SCHEME_GLOBAL_PATH, colorReplacementts) then
			return false
		end

		-- Set theme's glyph settings
		print("[DEBUG:themeCreator:createTheme] Setting theme's glyph settings")
		if not themeSettings.applyGlyphSettings(paths.THEME_SCHEME_GLOBAL_PATH) then
			return false
		end

		-- Set theme's screen width settings
		print("[DEBUG:themeCreator:createTheme] Setting theme's screen width settings")
		if not themeSettings.applyScreenWidthSettings(paths.THEME_SCHEME_GLOBAL_PATH, state.screenWidth) then
			return false
		end

		-- Set theme's content height settings
		print("[DEBUG:themeCreator:createTheme] Setting theme's content height settings")
		if not themeSettings.applyContentHeightSettings(paths.THEME_SCHEME_GLOBAL_PATH, state.screenHeight) then
			return false
		end

		-- Set theme's content width settings for `muxplore.ini`
		print("[DEBUG:themeCreator:createTheme] Setting theme's content width settings for `muxplore.ini`")
		if not themeSettings.applyContentWidth(paths.THEME_SCHEME_MUXPLORE_PATH) then
			return false
		end

		-- Copy the selected font file
		print("[DEBUG:themeCreator:createTheme] Copying selected font file")
		if not copySelectedFont() then
			return false
		end

		-- Create theme's `credits.txt` file
		print("[DEBUG:themeCreator:createTheme] Creating theme's `credits.txt` file")
		if not createCreditsFile() then
			return false
		end

		-- Create theme's `version.txt` file
		print("[DEBUG:themeCreator:createTheme] Creating theme's `version.txt` file")
		if not createVersionFile() then
			return false
		end

		-- Create theme's `name.txt` file
		print("[DEBUG:themeCreator:createTheme] Creating theme's `name.txt` file")
		if not createNameFile() then
			return false
		end

		-- Create theme's RGB configuration file
		print("[DEBUG:themeCreator:createTheme] Creating theme's RGB configuration file")
		if not createRgbConfFile() then
			return false
		end

		-- Copy sound files to the theme
		print("[DEBUG:themeCreator:createTheme] Copying sound files to the theme")
		if not copySoundFiles() then
			return false
		end

		-- Debug: Print the

		-- Create the ZIP archive
		print("[DEBUG:themeCreator:createTheme] Creating the ZIP archive")
		local outputThemePath = system.createArchive(paths.WORKING_THEME_DIR, paths.THEME_OUTPUT_PATH)
		if not outputThemePath then
			return false
		end

		-- Call sync to make the theme available
		print("[DEBUG:themeCreator:createTheme] Calling sync to make the theme available")
		commands.executeCommand("sync")

		return outputThemePath
	end, debug.traceback)

	if not status then
		print("[DEBUG:themeCreator:createTheme] Error: " .. tostring(err))
		errorHandler.setError(tostring(err))
		return false
	end

	-- Return the path from the successful execution
	return err
end

-- Function to install the theme to muOS active theme directory
function themeCreator.installTheme(themeName)
	print("[DEBUG:themeCreator:installTheme] Starting theme installation with theme name: " .. tostring(themeName))

	local status, err = xpcall(function()
		local cmd = string.format('/opt/muos/script/package/theme.sh install "%s"', themeName)
		print("[DEBUG:themeCreator:installTheme] Executing command: " .. cmd)
		local result = commands.executeCommand(cmd)
		print("[DEBUG:themeCreator:installTheme] Command execution result: " .. tostring(result))
		return result == 0
	end, debug.traceback)

	if not status then
		print("[DEBUG:themeCreator:installTheme] Error during installation: " .. tostring(err))
	end

	print("[DEBUG:themeCreator:installTheme] Installation completed with status: " .. tostring(status))
	return status
end

-- Clean up working directory
function themeCreator.cleanup()
	system.removeDir(paths.WORKING_THEME_DIR)
end

return themeCreator
