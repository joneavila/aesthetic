--- Theme creation functionality
local love = require("love")

local colorUtils = require("utils.color")
local paths = require("paths")
local state = require("state")

local fonts = require("ui.fonts")

local commands = require("utils.commands")
local imageGenerator = require("utils.image_generator")
local logger = require("utils.logger")
local rgb = require("utils.rgb")
local schemeConfigurator = require("utils.scheme_configurator")
local system = require("utils.system")
local themePackager = require("utils.theme_packager")
local fail = require("utils.fail")

-- Module table to export public functions
local themeCreator = {}

-- Helper function to copy resolution-specific template files
-- Copies all resolution directories from templates
local function copyAllResolutionTemplates()
	return paths.forEachResolution(function(width, height)
		local sourcePath = paths.SCHEME_TEMPLATE_DIR .. "/" .. width .. "x" .. height .. "/"
		local destPath = paths.WORKING_THEME_DIR .. "/" .. width .. "x" .. height
		local success, err = system.copy(sourcePath, destPath)
		if not success then
			return false, err or ("Failed to copy directory: " .. tostring(sourcePath))
		end
		return true
	end)
end

-- Helper function to reset graphics state between image generation calls
-- Sets blend mode to default, clears any active canvas, and sets color to default
local function resetGraphicsState()
	love.graphics.setBlendMode("alpha")
	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1, 1)
end

-- Helper function to execute boot image creation for all supported resolutions
local function executeBootImageForAllResolutions()
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	return paths.forEachResolution(function(width, height)
		if not system.fileExists(paths.THEME_BOOTLOGO_SOURCE) then
			return false, "Bootlogo source file does not exist: " .. tostring(paths.THEME_BOOTLOGO_SOURCE)
		end

		local pngOutputPath = string.format("%s/%dx%d/image/bootlogo.png", paths.WORKING_THEME_DIR, width, height)
		local bmpOutputPath = string.format("%s/%dx%d/image/bootlogo.bmp", paths.WORKING_THEME_DIR, width, height)

		local options = {
			width = width,
			height = height,
			iconPath = paths.THEME_BOOTLOGO_SOURCE,
			iconSize = 180,
			outputPath = pngOutputPath,
			bgColor = bgColor,
			fgColor = fgColor,
		}

		resetGraphicsState()
		local success, err = imageGenerator.createIconImage(options)
		if not success then
			return false, err or "Failed to create bootlogo PNG image."
		end

		local convertCmd = string.format('magick convert "%s" "%s"', pngOutputPath, bmpOutputPath)
		local cmdResult = commands.executeCommand(convertCmd)
		if cmdResult ~= 0 then
			return false, "ImageMagick convert command failed: " .. convertCmd
		end
		return true
	end)
end

-- Helper to create status images (reboot, shutdown, charge)
local function createStatusImage(opts)
	local options = {
		width = state.screenWidth,
		height = state.screenHeight,
		iconPath = opts.iconPath,
		iconSize = 50,
		backgroundLogoPath = paths.THEME_LOGO_OUTLINE_SOURCE,
		backgroundLogoSize = 180,
		text = opts.text,
		outputPath = opts.outputPath,
		bgColor = colorUtils.hexToLove(state.getColorValue("background")),
		fgColor = colorUtils.hexToLove(state.getColorValue("foreground")),
	}
	local success, err = imageGenerator.createIconImage(options)
	resetGraphicsState()
	if not success then
		return fail("Failed to create " .. opts.text:lower() .. " image: " .. tostring(err))
	end
	return true
end

-- Function to create reboot image shown during reboot
local function createRebootImage()
	return createStatusImage({
		iconPath = paths.THEME_REBOOT_ICON_SOURCE,
		text = "Rebooting",
		outputPath = paths.THEME_REBOOT_IMAGE,
	})
end

-- Function to create shutdown image shown during shutdown
local function createShutdownImage()
	return createStatusImage({
		iconPath = paths.THEME_SHUTDOWN_ICON_SOURCE,
		text = "Shutting down",
		outputPath = paths.THEME_SHUTDOWN_IMAGE,
	})
end

-- Function to create charge image shown during charging
local function createChargeImage()
	return createStatusImage({
		iconPath = paths.THEME_CHARGE_ICON_SOURCE,
		text = "Charging",
		outputPath = paths.THEME_CHARGE_IMAGE,
	})
end

-- Function to create preview image displayed in muOS theme selection menu
local function createPreviewImage(width, height)
	local outputPath = paths.getThemePreviewImagePath(width, height)
	local success, err = imageGenerator.createPreviewImage(outputPath)
	resetGraphicsState()
	if not success then
		return fail("Failed to create preview image: " .. tostring(err))
	end
	return true
end

-- Function to create `credits.txt` file containing the theme's credits
local function createCreditsFile()
	local content = "Created using Aesthetic for muOS: https://github.com/joneavila/aesthetic"
	local success, err = system.createTextFile(paths.THEME_CREDITS, content)
	if not success then
		return fail("Failed to create credits file: " .. tostring(err))
	end
	return true
end

-- Function to create `version.txt` file containing the compatible muOS version
-- This function ensures that the theme is always read as compatible by muOS
local function createVersionFile()
	logger.debug("Creating version file: " .. tostring(paths.MUOS_VERSION_FILE))
	local content = system.readFile(paths.MUOS_VERSION_FILE)
	if not content then
		return fail("muOS version file could not be read")
	end
	local parsedVersion = content and content:match("(%d[%d%.]+)_")
	if not parsedVersion then
		return fail("muOS version could not be parsed from version file")
	end

	local success, err = system.createTextFile(paths.THEME_VERSION, parsedVersion)
	if not success then
		return fail("Failed to create version file: " .. tostring(err))
	end
	return true
end

-- Function to find and copy the selected font file to theme directory
local function copySelectedFont()
	local fontFamilyDefinition
	for _, font in ipairs(fonts.themeDefinitions) do
		if font.name == state.fontFamily then
			fontFamilyDefinition = font
			break
		end
	end
	if not fontFamilyDefinition then
		return fail("Selected font not found: " .. tostring(state.fontFamily))
	end

	local fontDirectory = fontFamilyDefinition.ttf:match("^(.+)/[^/]+$")
	local binFile
	if tostring(state.screenWidth) == "1024" and tostring(state.screenHeight) == "768" then
		binFile = fontFamilyDefinition.bin1024x768
	else
		binFile = fontFamilyDefinition.binDefault
	end
	local fontSourcePath = fontDirectory .. "/" .. binFile
	logger.debug("Copying font file: " .. fontSourcePath)
	local success, err = system.copy(fontSourcePath, paths.THEME_DEFAULT_FONT)
	if not success then
		return fail(err or ("Failed to copy font file: " .. tostring(fontSourcePath)))
	end

	return true
end

-- Function to copy sound files to the theme
local function copySoundFiles()
	local soundSource = paths.THEME_SOUND_SOURCE_DIR
	if system.isDir(soundSource) then
		soundSource = soundSource .. "/"
	end
	local success, err = system.copy(soundSource, paths.THEME_SOUND_DIR)
	if not success then
		return false, err or "Failed to copy sound files."
	end
	return true
end

-- Coroutine-based theme creation that yields control for animations
function themeCreator.createThemeCoroutine()
	return coroutine.create(function()
		local status, result = xpcall(function()
			logger.debug("Starting coroutine-based theme creation")

			coroutine.yield("Copying scheme template files...")
			local templateItems = system.listDir(paths.SCHEME_TEMPLATE_DIR)
			if not templateItems then
				return false, "Failed to list template directory: " .. tostring(paths.SCHEME_TEMPLATE_DIR)
			end
			for _, item in ipairs(templateItems) do
				local sourcePath = paths.SCHEME_TEMPLATE_DIR .. "/" .. item
				local destPath = paths.WORKING_THEME_DIR .. "/" .. item

				local isResolutionDir = false
				for _, resolution in ipairs(paths.SUPPORTED_THEME_RESOLUTIONS) do
					if item == resolution then
						isResolutionDir = true
						break
					end
				end

				if item ~= "scheme" and not isResolutionDir then
					if system.isDir(sourcePath) then
						sourcePath = sourcePath .. "/" -- Add trailing slash to copy contents only
					end
					local success, err = system.copy(sourcePath, destPath)
					if not success then
						return false, err
					end
				end
			end

			coroutine.yield("Copying resolution templates...")
			local copyAllResolutionTemplatesSuccess, copyAllResolutionTemplatesError = copyAllResolutionTemplates()
			if not copyAllResolutionTemplatesSuccess then
				return false, copyAllResolutionTemplatesError
			end

			coroutine.yield("Setting up theme structure...")
			local schemeItems = system.listDir(paths.THEME_SCHEME_SOURCE_DIR)
			if not schemeItems then
				return false, "Failed to list scheme source directory: " .. tostring(paths.THEME_SCHEME_SOURCE_DIR)
			end
			for _, item in ipairs(schemeItems) do
				local sourcePath = paths.THEME_SCHEME_SOURCE_DIR .. "/" .. item
				local destPath = paths.THEME_SCHEME_DIR .. "/" .. item
				if system.isDir(sourcePath) then
					sourcePath = sourcePath .. "/"
				end
				local copySchemeSuccess, copySchemeError = system.copy(sourcePath, destPath)
				if not copySchemeSuccess then
					return false, copySchemeError
				end
			end

			coroutine.yield("Configuring grid settings...")
			local gridSuccess, gridErr = paths.forEachResolution(function(width, height)
				local muxlaunchIniPath = paths.getThemeMuxlaunchSchemePath(width, height)
				return schemeConfigurator.applyGridSettings(muxlaunchIniPath)
			end)
			if not gridSuccess then
				return false, gridErr
			end

			coroutine.yield("Copying icons...")
			local sourceDir = paths.GLYPHS_SOURCE_DIR
			local destDir = paths.THEME_GLYPH_DIR
			if system.isDir(sourceDir) then
				sourceDir = sourceDir .. "/"
			end
			local copyIconsSuccess, copyIconsError = system.copy(sourceDir, destDir)
			if not copyIconsSuccess then
				return false, copyIconsError or ("Failed to copy icons from: " .. sourceDir)
			end

			coroutine.yield("Copying icons (1024x768)...")
			local sourceDirGlyphs1024x768 = paths.GLYPHS_SOURCE_DIR_1024x768
			local destDirGlyphs1024x768 = paths.THEME_GLYPH_DIR_1024x768
			if system.isDir(sourceDirGlyphs1024x768) then
				sourceDirGlyphs1024x768 = sourceDirGlyphs1024x768 .. "/"
			end
			local copyIcons1024x768Success, copyIcons1024x768Error =
				system.copy(sourceDirGlyphs1024x768, destDirGlyphs1024x768)
			if not copyIcons1024x768Success then
				return false, copyIcons1024x768Error or ("Failed to copy icons from: " .. sourceDirGlyphs1024x768)
			end

			coroutine.yield("Copying home screen grid layout icons...")
			local muxlaunchGridSource = paths.SOURCE_DIR .. "/assets/image/grid/muxlaunch"
			local muxlaunchGridDest = paths.WORKING_THEME_DIR .. "/image/grid/muxlaunch"
			if system.isDir(muxlaunchGridSource) then
				muxlaunchGridSource = muxlaunchGridSource .. "/"
			end
			local copyMuxlaunchGridSuccess, copyMuxlaunchGridError = system.copy(muxlaunchGridSource, muxlaunchGridDest)
			if not copyMuxlaunchGridSuccess then
				return false, copyMuxlaunchGridError or "Failed to copy muxlaunch grid icons."
			end

			coroutine.yield("Copying home screen grid layout icons (1024x768)...")
			local muxlaunchGrid1024Source = paths.SOURCE_DIR .. "/assets/1024x768/image/grid/muxlaunch"
			local muxlaunchGrid1024Dest = paths.WORKING_THEME_DIR .. "/1024x768/image/grid/muxlaunch"

			if system.isDir(muxlaunchGrid1024Source) then
				muxlaunchGrid1024Source = muxlaunchGrid1024Source .. "/"
			end
			local success, err = system.copy(muxlaunchGrid1024Source, muxlaunchGrid1024Dest)
			if not success then
				return false, err or "Failed to copy 1024x768 muxlaunch grid icons."
			end

			coroutine.yield("Creating boot images...")
			local bootSuccess, bootErr = executeBootImageForAllResolutions()
			if not bootSuccess then
				return false, bootErr
			end

			coroutine.yield("Creating shutdown image...")
			local shutdownSuccess, shutdownErr = createShutdownImage()
			if not shutdownSuccess then
				return false, shutdownErr
			end

			coroutine.yield("Creating charge image...")
			local chargeSuccess, chargeErr = createChargeImage()
			if not chargeSuccess then
				return false, chargeErr
			end

			coroutine.yield("Creating reboot image...")
			resetGraphicsState()
			local rebootSuccess, rebootErr = createRebootImage()
			if not rebootSuccess then
				return false, rebootErr
			end
			resetGraphicsState()

			coroutine.yield("Creating preview images...")
			local previewSuccess, previewErr = paths.forEachResolution(function(width, height)
				return createPreviewImage(width, height)
			end)
			if not previewSuccess then
				return false, previewErr
			end

			coroutine.yield("Applying color settings...")
			local applyColorSettingsSuccess, applyColorSettingsError =
				schemeConfigurator.applyColorSettings(paths.THEME_SCHEME_GLOBAL)
			if not applyColorSettingsSuccess then
				return false, applyColorSettingsError
			end

			coroutine.yield("Applying battery settings...")
			local applyBatterySettingsSuccess, applyBatterySettingsError =
				schemeConfigurator.applyBatterySettings(paths.THEME_SCHEME_GLOBAL)
			if not applyBatterySettingsSuccess then
				return false, applyBatterySettingsError
			end

			coroutine.yield("Applying glyph settings...")
			local applyGlyphSettingsSuccess, applyGlyphSettingsError =
				schemeConfigurator.applyGlyphSettings(paths.THEME_SCHEME_GLOBAL)
			if not applyGlyphSettingsSuccess then
				return false, applyGlyphSettingsError
			end

			coroutine.yield("Applying font padding settings...")
			local applyFontListPaddingSettingsSuccess, applyFontListPaddingSettingsError =
				schemeConfigurator.applyFontListPaddingSettings(paths.THEME_SCHEME_GLOBAL)
			if not applyFontListPaddingSettingsSuccess then
				return false, applyFontListPaddingSettingsError
			end

			coroutine.yield("Applying content padding left settings...")
			local applyContentPaddingLeftSettingsSuccess, applyContentPaddingLeftSettingsError =
				schemeConfigurator.applyContentPaddingLeftSettings(paths.THEME_SCHEME_GLOBAL, state.screenWidth)
			if not applyContentPaddingLeftSettingsSuccess then
				return false, applyContentPaddingLeftSettingsError
			end

			coroutine.yield("Applying content width settings...")
			local applyContentWidthSettingsSuccess, applyContentWidthSettingsError =
				schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_GLOBAL, state.screenWidth)
			if not applyContentWidthSettingsSuccess then
				return false, applyContentWidthSettingsError
			end
			local applyContentWidthSettingsMuxploreSuccess, applyContentWidthSettingsMuxploreError =
				schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_MUXPLORE, state.screenWidth)
			if not applyContentWidthSettingsMuxploreSuccess then
				return false, applyContentWidthSettingsMuxploreError
			end
			local applyContentWidthSettingsMuxhistorySuccess, applyContentWidthSettingsMuxhistoryError =
				schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_MUXHISTORY, state.screenWidth)
			if not applyContentWidthSettingsMuxhistorySuccess then
				return false, applyContentWidthSettingsMuxhistoryError
			end
			local applyContentWidthSettingsMuxcollectSuccess, applyContentWidthSettingsMuxcollectError =
				schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_MUXCOLLECT, state.screenWidth)
			if not applyContentWidthSettingsMuxcollectSuccess then
				return false, applyContentWidthSettingsMuxcollectError
			end

			coroutine.yield("Applying alignment settings...")
			local applyNavigationAlignmentSettingsSuccess, applyNavigationAlignmentSettingsError =
				schemeConfigurator.applyNavigationAlignmentSettings(paths.THEME_SCHEME_GLOBAL)
			if not applyNavigationAlignmentSettingsSuccess then
				return false, applyNavigationAlignmentSettingsError
			end
			local applyStatusAlignmentSettingsSuccess, applyStatusAlignmentSettingsError =
				schemeConfigurator.applyStatusAlignmentSettings(paths.THEME_SCHEME_GLOBAL)
			if not applyStatusAlignmentSettingsSuccess then
				return false, applyStatusAlignmentSettingsError
			end
			local applyHeaderAlignmentSettingsSuccess, applyHeaderAlignmentSettingsError =
				schemeConfigurator.applyHeaderAlignmentSettings(paths.THEME_SCHEME_GLOBAL)
			if not applyHeaderAlignmentSettingsSuccess then
				return false, applyHeaderAlignmentSettingsError
			end
			local applyDatetimeSettingsSuccess, applyDatetimeSettingsError =
				schemeConfigurator.applyDatetimeSettings(paths.THEME_SCHEME_GLOBAL)
			if not applyDatetimeSettingsSuccess then
				return false, applyDatetimeSettingsError
			end

			coroutine.yield("Applying header opacity settings...")
			local applyHeaderOpacitySuccess, applyHeaderOpacityError =
				schemeConfigurator.applyHeaderOpacity(paths.THEME_SCHEME_GLOBAL)
			if not applyHeaderOpacitySuccess then
				return false, applyHeaderOpacityError
			end

			coroutine.yield("Applying navigation opacity settings...")
			local applyNavigationAlphaSettingsSuccess, applyNavigationAlphaSettingsError =
				schemeConfigurator.applyNavigationAlphaSettings(paths.THEME_SCHEME_GLOBAL)
			if not applyNavigationAlphaSettingsSuccess then
				return false, applyNavigationAlphaSettingsError
			end

			coroutine.yield("Copying font file...")
			local copySelectedFontSuccess, copySelectedFontError = copySelectedFont()
			if not copySelectedFontSuccess then
				return false, copySelectedFontError
			end

			coroutine.yield("Creating credits file...")
			local createCreditsFileSuccess, createCreditsFileError = createCreditsFile()
			if not createCreditsFileSuccess then
				return false, createCreditsFileError
			end

			coroutine.yield("Creating version file...")
			local createVersionFileSuccess, createVersionFileError = createVersionFile()
			if not createVersionFileSuccess then
				return false, createVersionFileError
			end

			if state.hasRGBSupport then
				coroutine.yield("Setting up RGB configuration...")
				local createConfigFileSuccess, createConfigFileError = rgb.createConfigFile(paths.THEME_RGB_CONF)
				if not createConfigFileSuccess then
					return false, createConfigFileError
				end
			end

			coroutine.yield("Copying sound files...")
			local copySoundFilesSuccess, copySoundFilesError = copySoundFiles()
			if not copySoundFilesSuccess then
				return false, copySoundFilesError
			end

			coroutine.yield("Creating theme archive...")
			local candidateOutputPath = paths.MUOS_THEMES_DIR .. "/" .. state.themeName .. ".muxthm"
			local finalOutputPath = system.createArchive(paths.WORKING_THEME_DIR, candidateOutputPath)
			if not finalOutputPath then
				return false, "Failed to create theme archive."
			end
			if not themePackager.createNameFile(finalOutputPath, paths.THEME_NAME) then
				return false, "Failed to create name.txt for theme archive."
			end

			coroutine.yield("Cleaning up...")
			themePackager.cleanupWorkingDir(paths.WORKING_THEME_DIR)

			-- coroutine.yield("Syncing filesystem...")
			-- commands.executeCommand("sync")

			resetGraphicsState()

			return finalOutputPath
		end, debug.traceback)

		if not status then
			resetGraphicsState()
			logger.error("Coroutine error: " .. tostring(result))
			return false, tostring(result)
		end

		return true, result
	end)
end

-- Coroutine-based theme activation that yields control for animations
function themeCreator.installThemeCoroutine(themeName)
	return coroutine.create(function()
		local status, result = xpcall(function()
			coroutine.yield("Preparing activation...")

			local muosCodename = system.getMuosCodename()
			if not muosCodename then
				return false, "Failed to get muOS codename."
			end

			local cmd = string.format('%s install "%s"', paths.MUOS_THEME_SCRIPT, themeName)
			if muosCodename == "GOOSE" then
				cmd = string.format('sh ./install_theme_goose.sh "%s"', themeName) -- Use custom script for Goose
			end

			coroutine.yield("Activating theme (this may take a while)...")
			if commands.executeCommand(cmd) ~= 0 then
				return false, "Theme activation command failed."
			end

			return true
		end, debug.traceback)

		if not status then
			return false, "Activation failed: " .. tostring(result)
		end

		return status, result
	end)
end

return themeCreator
