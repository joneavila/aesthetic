--- Settings management module
--- Manages persistent application-wide settings that are automatically saved and loaded between sessions in a single
--- configuration file. Includes migration support for upgrading from v1.5.1 to any current version.
local errorHandler = require("error_handler")
local state = require("state")
local paths = require("paths")
local fail = require("utils.fail")

local system = require("utils.system")

local settings = {}

-- Preset source type (built-in vs user-created)
settings.SOURCE_BUILTIN = "built-in"
settings.SOURCE_USER = "user"

-- Function to save the current settings to a file
function settings.saveToFile()
	local filePath = paths.SETTINGS_FILE
	if not filePath then
		return fail("No settings file path provided.")
	end

	local file, err = io.open(filePath, "w")
	if not file then
		return fail("Failed to create settings file: " .. (err or "unknown error"))
	end

	-- Serialize the settings as Lua code
	file:write("-- Aesthetic settings file\n")
	file:write("return {\n")

	-- Background color
	file:write("  background = {\n")
	file:write('    value = "' .. state.getColorValue("background") .. '",\n')
	file:write('    type = "' .. state.backgroundType .. '",\n')
	file:write("  },\n")

	-- Background gradient color
	file:write("  backgroundGradient = {\n")
	file:write('    value = "' .. state.getColorValue("backgroundGradient") .. '",\n')
	file:write('    direction = "' .. (state.backgroundGradientDirection or "Vertical") .. '",\n')
	file:write("  },\n")

	-- Foreground
	file:write("  foreground = {\n")
	file:write('    value = "' .. state.getColorValue("foreground") .. '",\n')
	file:write("  },\n")

	-- Battery active
	file:write('  batteryActive = "' .. state.getColorValue("batteryActive") .. '",\n')

	-- Battery low
	file:write('  batteryLow = "' .. state.getColorValue("batteryLow") .. '",\n')

	-- RGB lighting
	file:write("  rgb = {\n")
	file:write('    value = "' .. state.getColorValue("rgb") .. '",\n')
	file:write('    mode = "' .. state.rgbMode .. '",\n')
	file:write("    brightness = " .. state.rgbBrightness .. ",\n")
	file:write("    speed = " .. state.rgbSpeed .. ",\n")
	file:write("  },\n")

	-- Box art width
	file:write("  boxArtWidth = " .. state.boxArtWidth .. ",\n")

	-- Font family
	file:write('  font = "' .. state.fontFamily .. '",\n')

	-- TEMPORARILY DISABLED: Font size saving
	-- file:write('  fontSize = "' .. fonts.getFontSize() .. '",\n')

	-- Navigation alignment
	file:write('  navigationAlignment = "' .. state.navigationAlignment .. '",\n')

	-- Navigation alpha
	file:write("  navigationOpacity = " .. state.navigationOpacity .. ",\n")

	-- Status alignment
	file:write('  statusAlignment = "' .. state.statusAlignment .. '",\n')

	-- Time alignment
	file:write('  timeAlignment = "' .. state.timeAlignment .. '",\n')

	-- Datetime opacity
	file:write("  datetimeOpacity = " .. state.datetimeOpacity .. ",\n")

	-- Battery opacity
	file:write("  batteryOpacity = " .. state.batteryOpacity .. ",\n")

	-- Header text alignment
	file:write("  headerAlignment = " .. state.headerAlignment .. ",\n")

	-- Glyphs
	file:write("  glyphsEnabled = " .. tostring(state.glyphsEnabled) .. ",\n")

	-- Theme name
	file:write('  themeName = "' .. state.themeName .. '",\n')

	-- Header text alpha
	file:write("  headerOpacity = " .. tostring(state.headerOpacity) .. ",\n")

	-- Source (user-created by default when saving)
	file:write('  source = "' .. settings.SOURCE_USER .. '",\n')

	-- Home screen layout
	file:write('  homeScreenLayout = "' .. state.homeScreenLayout .. '",\n')

	file:write("}\n")

	file:close()
	return true
end

-- Function to migrate v1.5.1 settings to current version format
local function migrateSettings(loadedSettings)
	-- Start with the loaded settings and only make necessary changes
	local migratedSettings = {}

	-- Copy all existing settings first
	for key, value in pairs(loadedSettings) do
		migratedSettings[key] = value
	end

	-- Handle key renames: glyphs_enabled -> glyphsEnabled
	if migratedSettings.glyphs_enabled ~= nil then
		migratedSettings.glyphsEnabled = migratedSettings.glyphs_enabled
		migratedSettings.glyphs_enabled = nil -- Remove the old key
	end

	-- Handle boxArtWidth conversion from string to number
	if migratedSettings.boxArtWidth and type(migratedSettings.boxArtWidth) == "string" then
		if migratedSettings.boxArtWidth == "Disabled" then
			migratedSettings.boxArtWidth = 0
		else
			migratedSettings.boxArtWidth = tonumber(migratedSettings.boxArtWidth) or 0
		end
	end

	-- Add missing keys with default values from state.lua
	if not migratedSettings.background or not migratedSettings.background.type then
		if not migratedSettings.background then
			migratedSettings.background = {}
		end
		migratedSettings.background.type = state.backgroundType
	end

	if not migratedSettings.backgroundGradient then
		migratedSettings.backgroundGradient = {
			value = state.getColorValue("backgroundGradient"),
			direction = state.backgroundGradientDirection,
		}
	end

	if not migratedSettings.navigationAlignment then
		migratedSettings.navigationAlignment = state.navigationAlignment
	end

	if not migratedSettings.navigationOpacity then
		migratedSettings.navigationOpacity = state.navigationOpacity
	end

	if not migratedSettings.statusAlignment then
		migratedSettings.statusAlignment = state.statusAlignment
	end

	if not migratedSettings.timeAlignment then
		migratedSettings.timeAlignment = state.timeAlignment
	end

	if not migratedSettings.datetimeOpacity then
		migratedSettings.datetimeOpacity = state.datetimeOpacity
	end

	if not migratedSettings.headerAlignment then
		migratedSettings.headerAlignment = state.headerAlignment
	end

	if not migratedSettings.headerOpacity then
		migratedSettings.headerOpacity = state.headerOpacity
	end

	if not migratedSettings.source then
		migratedSettings.source = state.source
	end

	if not migratedSettings.homeScreenLayout then
		migratedSettings.homeScreenLayout = state.homeScreenLayout
	end

	return migratedSettings
end

-- Function to load settings from file
function settings.loadFromFile()
	-- Get file path
	local filePath = paths.SETTINGS_FILE
	if not filePath then
		return false
	end

	-- Check if the file exists
	if not system.fileExists(filePath) then
		-- No settings file found, this is normal on first run
		return false
	end

	-- Try to load the settings file
	local success, loadedSettings = pcall(function()
		local chunk, err = loadfile(filePath)
		if not chunk then
			error("Failed to load settings file: " .. (err or "unknown error"))
		end
		return chunk()
	end)

	if not success or type(loadedSettings) ~= "table" then
		errorHandler.setError("Failed to parse settings file: " .. tostring(loadedSettings))
		return false
	end

	-- Check if this is a v1.5.1 settings file and migrate if needed
	local needsMigration = false

	-- Detect v1.5.1 format by checking for old keys or missing new keys
	-- This handles migration from v1.5.1 to any current version
	if
		loadedSettings.glyphs_enabled ~= nil -- Old key name
		or not loadedSettings.backgroundGradient -- Missing new key (added in v1.6.0)
		or not loadedSettings.navigationAlignment -- Missing new key (added in v1.6.0)
		or (loadedSettings.boxArtWidth and type(loadedSettings.boxArtWidth) == "string")
	then -- Old string format
		needsMigration = true
	end

	if needsMigration then
		loadedSettings = migrateSettings(loadedSettings)
		-- Save the migrated settings back to file immediately
		settings.saveToFile()
	end

	-- Apply the loaded (and possibly migrated) settings to the state
	if loadedSettings.background then
		if loadedSettings.background.value then
			state.setColorValue("background", loadedSettings.background.value)
		end

		if loadedSettings.background.type then
			state.backgroundType = loadedSettings.background.type
		end
	end

	-- Background gradient color
	if loadedSettings.backgroundGradient and loadedSettings.backgroundGradient.value then
		state.setColorValue("backgroundGradient", loadedSettings.backgroundGradient.value)
	end
	if loadedSettings.backgroundGradient and loadedSettings.backgroundGradient.direction then
		state.backgroundGradientDirection = loadedSettings.backgroundGradient.direction
	end

	-- Foreground
	if loadedSettings.foreground and loadedSettings.foreground.value then
		state.setColorValue("foreground", loadedSettings.foreground.value)
	end

	-- Battery active
	if loadedSettings.batteryActive then
		state.setColorValue("batteryActive", loadedSettings.batteryActive)
	end

	-- Battery low
	if loadedSettings.batteryLow then
		state.setColorValue("batteryLow", loadedSettings.batteryLow)
	end

	-- RGB settings
	if loadedSettings.rgb then
		if loadedSettings.rgb.value then
			state.setColorValue("rgb", loadedSettings.rgb.value)
		end

		if loadedSettings.rgb.mode then
			state.rgbMode = loadedSettings.rgb.mode
		end

		if loadedSettings.rgb.brightness then
			state.rgbBrightness = loadedSettings.rgb.brightness
		end

		if loadedSettings.rgb.speed then
			state.rgbSpeed = loadedSettings.rgb.speed
		end
	end

	-- Box art width (already converted to number in migration)
	if loadedSettings.boxArtWidth then
		state.boxArtWidth = loadedSettings.boxArtWidth
	end

	-- Font
	if loadedSettings.font then
		state.fontFamily = loadedSettings.font
	end

	-- TEMPORARILY DISABLED: Font size loading
	if loadedSettings.fontSize then
		-- Show warning but don't apply the value
		print(
			"WARNING: Font size setting found in settings file but is temporarily disabled: "
				.. tostring(loadedSettings.fontSize)
		)
	end

	-- Navigation alignment
	if loadedSettings.navigationAlignment then
		state.navigationAlignment = loadedSettings.navigationAlignment
	end

	-- Navigation alpha
	if loadedSettings.navigationOpacity then
		state.navigationOpacity = loadedSettings.navigationOpacity
	end

	-- Status alignment
	if loadedSettings.statusAlignment then
		state.statusAlignment = loadedSettings.statusAlignment
	end

	-- Time alignment
	if loadedSettings.timeAlignment then
		state.timeAlignment = loadedSettings.timeAlignment
	end

	-- Datetime opacity
	if loadedSettings.datetimeOpacity then
		state.datetimeOpacity = loadedSettings.datetimeOpacity
	end

	-- Battery opacity
	if loadedSettings.batteryOpacity then
		state.batteryOpacity = loadedSettings.batteryOpacity
	end

	-- Header text alignment
	if loadedSettings.headerAlignment then
		state.headerAlignment = loadedSettings.headerAlignment
	end

	-- Glyphs (already converted from glyphs_enabled in migration)
	if loadedSettings.glyphsEnabled ~= nil then
		state.glyphsEnabled = loadedSettings.glyphsEnabled
	end

	-- Theme name
	if loadedSettings.themeName then
		state.themeName = loadedSettings.themeName
	end

	-- Header text alpha
	if loadedSettings.headerOpacity then
		state.headerOpacity = loadedSettings.headerOpacity
	end

	-- Source
	if loadedSettings.source then
		state.source = loadedSettings.source
	else
		state.source = settings.SOURCE_USER -- Default to user-created if not specified
	end

	-- Home screen layout
	if loadedSettings.homeScreenLayout then
		state.homeScreenLayout = loadedSettings.homeScreenLayout
	end

	return true
end

return settings
