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
local themePackager = require("utils.theme_packager")
local fail = require("utils.fail")

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
-- Executes the function for each supported resolution, passing width and height to the callback
local function executeForAllResolutions(func)
	for _, resolution in ipairs(SUPPORTED_RESOLUTIONS) do
		local width, height = resolution:match("(%d+)x(%d+)")
		width, height = tonumber(width), tonumber(height)
		local success, err = func(width, height)
		if not success then
			return false, err
		end
	end
	return true
end

-- Helper function to copy resolution-specific template files
-- Copies all resolution directories from templates
local function copyAllResolutionTemplates()
	for _, resolution in ipairs(SUPPORTED_RESOLUTIONS) do
		local sourcePath = paths.TEMPLATE_DIR .. "/" .. resolution .. "/"
		local destPath = paths.WORKING_THEME_DIR .. "/" .. resolution
		local success, err = system.copy(sourcePath, destPath)
		if not success then
			return false, err or ("Failed to copy directory: " .. tostring(sourcePath))
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

-- Helper function to execute boot image creation for all supported resolutions
local function executeBootImageForAllResolutions()
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	for _, resolution in ipairs(SUPPORTED_RESOLUTIONS) do
		local width, height = resolution:match("(%d+)x(%d+)")
		width, height = tonumber(width), tonumber(height)

		if not system.fileExists(paths.THEME_BOOTLOGO_SOURCE) then
			return fail("Bootlogo source file does not exist: " .. tostring(paths.THEME_BOOTLOGO_SOURCE))
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
			return fail(err or "Failed to create bootlogo PNG image.")
		end

		local convertCmd = string.format('magick convert "%s" "%s"', pngOutputPath, bmpOutputPath)
		local cmdResult = commands.executeCommand(convertCmd)
		if cmdResult ~= 0 then
			return fail("ImageMagick convert command failed: " .. convertCmd)
		end
	end

	return true
end

-- Helper to copy either a file or directory
local function copyItem(sourcePath, destPath)
	if system.isDir(sourcePath) then
		local success, err = system.copyDir(sourcePath, destPath)
		if not success then
			return false, err or ("Failed to copy directory: " .. tostring(sourcePath))
		end
	elseif system.isFile(sourcePath) then
		local success, err = system.copyFile(sourcePath, destPath)
		if not success then
			return false, err or ("Failed to copy file: " .. tostring(sourcePath))
		end
	else
		return false, "Source path does not exist: " .. sourcePath
	end
	return true
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
			local templateItems = system.listDir(paths.TEMPLATE_DIR)
			if not templateItems then
				return false, "Failed to list template directory: " .. tostring(paths.TEMPLATE_DIR)
			end
			for _, item in ipairs(templateItems) do
				local sourcePath = paths.TEMPLATE_DIR .. "/" .. item
				local destPath = paths.WORKING_THEME_DIR .. "/" .. item

				local isResolutionDir = false
				for _, resolution in ipairs(SUPPORTED_RESOLUTIONS) do
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
			local success, err = copyAllResolutionTemplates()
			if not success then
				return false, err
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
				local success, err = system.copy(sourcePath, destPath)
				if not success then
					return false, err
				end
			end

			coroutine.yield("Configuring grid settings...")
			local gridSuccess, gridErr = executeForAllResolutions(function(width, height)
				local muxlaunchIniPath = paths.getThemeResolutionMuxlaunchIniPath(width, height)
				return schemeConfigurator.applyGridSettings(muxlaunchIniPath)
			end)
			if not gridSuccess then
				return false, gridErr
			end

			coroutine.yield("Copying glyphs...")
			local glyphSourceDir = paths.SOURCE_DIR .. "/assets/icons/glyph"
			local glyphDestDir = paths.THEME_GLYPH_DIR
			if system.isDir(glyphSourceDir) then
				glyphSourceDir = glyphSourceDir .. "/"
			end
			local glyphSuccess, glyphErr = system.copy(glyphSourceDir, glyphDestDir)
			if not glyphSuccess then
				return false, glyphErr or ("Failed to copy glyphs from: " .. glyphSourceDir)
			end
			local muxlaunchGridSource = paths.SOURCE_DIR .. "/assets/image/grid/muxlaunch"
			local muxlaunchGridDest = paths.WORKING_THEME_DIR .. "/image/grid/muxlaunch"
			if system.isDir(muxlaunchGridSource) then
				muxlaunchGridSource = muxlaunchGridSource .. "/"
			end
			local gridCopySuccess, gridCopyErr = system.copy(muxlaunchGridSource, muxlaunchGridDest)
			if not gridCopySuccess then
				return false, gridCopyErr or "Failed to copy muxlaunch grid icons."
			end
			local muxlaunchGrid1024Source = paths.SOURCE_DIR .. "/assets/1024x768/image/grid/muxlaunch"
			local muxlaunchGrid1024Dest = paths.WORKING_THEME_DIR .. "/1024x768/image/grid/muxlaunch"
			if system.isDir(muxlaunchGrid1024Source) then
				muxlaunchGrid1024Source = muxlaunchGrid1024Source .. "/"
			end
			local grid1024Success, grid1024Err = system.copy(muxlaunchGrid1024Source, muxlaunchGrid1024Dest)
			if not grid1024Success then
				return false, grid1024Err or "Failed to copy 1024x768 muxlaunch grid icons."
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
			local previewSuccess, previewErr = executeForAllResolutions(function(width, height)
				return createPreviewImage(width, height)
			end)
			if not previewSuccess then
				return false, previewErr
			end

			coroutine.yield("Applying color settings...")
			local colorSuccess, colorErr = schemeConfigurator.applyColorSettings(paths.THEME_SCHEME_GLOBAL)
			if not colorSuccess then
				return false, colorErr
			end

			coroutine.yield("Applying battery settings...")
			local batterySuccess, batteryErr = schemeConfigurator.applyBatterySettings(paths.THEME_SCHEME_GLOBAL)
			if not batterySuccess then
				return false, batteryErr
			end

			local glyphSetSuccess, glyphSetErr = schemeConfigurator.applyGlyphSettings(paths.THEME_SCHEME_GLOBAL)
			if not glyphSetSuccess then
				return false, glyphSetErr
			end

			coroutine.yield("Applying font padding settings...")
			local fontPadSuccess, fontPadErr =
				schemeConfigurator.applyFontListPaddingSettings(paths.THEME_SCHEME_GLOBAL)
			if not fontPadSuccess then
				return false, fontPadErr
			end

			coroutine.yield("Applying content padding left settings...")
			local contentPadSuccess, contentPadErr =
				schemeConfigurator.applyContentPaddingLeftSettings(paths.THEME_SCHEME_GLOBAL, state.screenWidth)
			if not contentPadSuccess then
				return false, contentPadErr
			end

			coroutine.yield("Applying content width settings...")
			local contentWidthSuccess, contentWidthErr =
				schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_GLOBAL, state.screenWidth)
			if not contentWidthSuccess then
				return false, contentWidthErr
			end
			local muxploreWidthSuccess, muxploreWidthErr =
				schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_MUXPLORE, state.screenWidth)
			if not muxploreWidthSuccess then
				return false, muxploreWidthErr
			end
			local muxhistoryWidthSuccess, muxhistoryWidthErr =
				schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_MUXHISTORY, state.screenWidth)
			if not muxhistoryWidthSuccess then
				return false, muxhistoryWidthErr
			end
			local muxcollectWidthSuccess, muxcollectWidthErr =
				schemeConfigurator.applyContentWidthSettings(paths.THEME_SCHEME_MUXCOLLECT, state.screenWidth)
			if not muxcollectWidthSuccess then
				return false, muxcollectWidthErr
			end

			coroutine.yield("Applying alignment settings...")
			local navAlignSuccess, navAlignErr =
				schemeConfigurator.applyNavigationAlignmentSettings(paths.THEME_SCHEME_GLOBAL)
			if not navAlignSuccess then
				return false, navAlignErr
			end
			local statusAlignSuccess, statusAlignErr =
				schemeConfigurator.applyStatusAlignmentSettings(paths.THEME_SCHEME_GLOBAL)
			if not statusAlignSuccess then
				return false, statusAlignErr
			end
			local headerAlignSuccess, headerAlignErr =
				schemeConfigurator.applyHeaderAlignmentSettings(paths.THEME_SCHEME_GLOBAL)
			if not headerAlignSuccess then
				return false, headerAlignErr
			end
			local datetimeSuccess, datetimeErr = schemeConfigurator.applyDatetimeSettings(paths.THEME_SCHEME_GLOBAL)
			if not datetimeSuccess then
				return false, datetimeErr
			end

			coroutine.yield("Applying alpha settings...")
			local headerOpacitySuccess, headerOpacityErr =
				schemeConfigurator.applyHeaderOpacity(paths.THEME_SCHEME_GLOBAL)
			if not headerOpacitySuccess then
				return false, headerOpacityErr
			end
			local navAlphaSuccess, navAlphaErr =
				schemeConfigurator.applyNavigationAlphaSettings(paths.THEME_SCHEME_GLOBAL)
			if not navAlphaSuccess then
				return false, navAlphaErr
			end

			coroutine.yield("Copying font files...")
			local fontSuccess, fontErr = copySelectedFont()
			if not fontSuccess then
				return false, fontErr
			end

			coroutine.yield("Creating text files...")
			local creditsSuccess, creditsErr = createCreditsFile()
			if not creditsSuccess then
				return false, creditsErr
			end
			local versionSuccess, versionErr = createVersionFile()
			if not versionSuccess then
				return false, versionErr
			end

			if state.hasRGBSupport then
				coroutine.yield("Setting up RGB configuration...")
				local rgbSuccess, rgbErr = rgb.createConfigFile(paths.THEME_RGB_DIR, paths.THEME_RGB_CONF)
				if not rgbSuccess then
					return false, rgbErr
				end
			end

			coroutine.yield("Copying sound files...")
			local soundSuccess, soundErr = copySoundFiles()
			if not soundSuccess then
				return false, soundErr
			end

			coroutine.yield("Creating theme archive...")
			local outputThemePath = system.createArchive(paths.WORKING_THEME_DIR, paths.getThemeOutputPath())
			if not outputThemePath then
				return false, "Failed to create theme archive."
			end

			if not themePackager.createNameFile(outputThemePath, paths.THEME_NAME) then
				return false, "Failed to create name.txt for theme archive."
			end

			coroutine.yield("Cleaning up...")
			themePackager.cleanupWorkingDir(paths.WORKING_THEME_DIR)

			coroutine.yield("Syncing filesystem...")
			commands.executeCommand("sync")

			resetGraphicsState()

			return outputThemePath
		end, debug.traceback)

		if not status then
			resetGraphicsState()
			logger.error("Coroutine error: " .. tostring(result))
			return false, tostring(result)
		end

		return true, result
	end)
end

-- Coroutine-based theme installation that yields control for animations
function themeCreator.installThemeCoroutine(themeName)
	return coroutine.create(function()
		logger.debug("Starting coroutine-based theme installation")

		local status, result = xpcall(function()
			coroutine.yield("Preparing installation...")

			if not system.fileExists(paths.THEME_INSTALL_SCRIPT) then
				coroutine.yield("Install script not found - skipping...")
				return true
			end

			local systemVersion = system.getSystemVersion()
			logger.debug("System version: " .. tostring(systemVersion))
			if not systemVersion then
				return false, "Failed to get system version."
			end

			local cmd
			if systemVersion == "GOOSE" then
				cmd = string.format('sh ./install_theme_goose.sh "%s"', themeName)
			else
				cmd = string.format('%s install "%s"', paths.THEME_INSTALL_SCRIPT, themeName)
			end

			coroutine.yield("Installing theme files...")
			local installResult = commands.executeCommand(cmd)

			if installResult ~= 0 then
				return false, "Theme installation command failed."
			end

			return true
		end, debug.traceback)

		if not status then
			return false, "Installation failed: " .. tostring(result)
		end

		return status, result
	end)
end

return themeCreator
