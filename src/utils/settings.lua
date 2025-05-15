--- Settings management module
--- Manages persistent application-wide settings that are automatically saved and loaded between sessions in a single
--- configuration file
local state = require("state")
local system = require("utils.system")
local errorHandler = require("error_handler")

local settings = {}

-- The filename to use for storing settings
settings.FILENAME = "settings.lua"

-- Preset source type (built-in vs user-created)
settings.SOURCE_BUILTIN = "built-in"
settings.SOURCE_USER = "user"

-- Function to get the settings file path
function settings.getFilePath()
	-- Get the ROOT_DIR from environment variable
	local rootDir = system.getEnvironmentVariable("ROOT_DIR")
	if not rootDir then
		errorHandler.setError("Failed to get ROOT_DIR environment variable")
		return nil
	end

	-- Set baseDir based on development mode
	local baseDir
	if state.isDevelopment then
		baseDir = system.getEnvironmentVariable("DEV_DIR")
		if not baseDir then
			errorHandler.setError("DEV_DIR environment variable not set but isDevelopment is true")
			return nil
		end
	else
		baseDir = rootDir
	end

	-- Return the appropriate path
	return baseDir .. "/" .. settings.FILENAME
end

-- Function to save the current settings to a file
function settings.saveToFile()
	-- Get file path
	local filePath = settings.getFilePath()
	if not filePath then
		return false
	end

	-- Create the file
	local file, err = io.open(filePath, "w")
	if not file then
		errorHandler.setError("Failed to create settings file: " .. (err or "unknown error"))
		return false
	end

	-- Serialize the settings as Lua code
	file:write("-- Aesthetic settings file\n")
	file:write("return {\n")

	-- Background color
	file:write("  background = {\n")
	file:write('    value = "' .. state.getColorValue("background") .. '",\n')
	file:write("  },\n")

	-- Foreground color
	file:write("  foreground = {\n")
	file:write('    value = "' .. state.getColorValue("foreground") .. '",\n')
	file:write("  },\n")

	-- RGB lighting
	file:write("  rgb = {\n")
	file:write('    value = "' .. state.getColorValue("rgb") .. '",\n')
	file:write('    mode = "' .. state.rgbMode .. '",\n')
	file:write("    brightness = " .. state.rgbBrightness .. ",\n")
	file:write("    speed = " .. state.rgbSpeed .. ",\n")
	file:write("  },\n")

	-- Box art width
	-- This value can be an integer or a string since the option "Disabled" has been added
	if type(state.boxArtWidth) == "string" then
		file:write('  boxArtWidth = "' .. state.boxArtWidth .. '",\n')
	else
		file:write("  boxArtWidth = " .. state.boxArtWidth .. ",\n")
	end

	-- Font family
	file:write('  font = "' .. state.selectedFont .. '",\n')

	-- Font size
	file:write('  fontSize = "' .. state.fontSize .. '",\n')

	-- Navigation alignment
	file:write('  navigationAlignment = "' .. state.navigationAlignment .. '",\n')

	-- Navigation alpha
	file:write("  navigationAlpha = " .. state.navigationAlpha .. ",\n")

	-- Status alignment
	file:write('  statusAlignment = "' .. state.statusAlignment .. '",\n')

	-- Time alignment
	file:write('  timeAlignment = "' .. state.timeAlignment .. '",\n')

	-- Glyphs
	file:write("  glyphs_enabled = " .. tostring(state.glyphs_enabled) .. ",\n")

	-- Theme name
	file:write('  themeName = "' .. state.themeName .. '",\n')

	-- Header text enabled
	file:write('  headerTextEnabled = "' .. state.headerTextEnabled .. '",\n')

	-- Source (user-created by default when saving)
	file:write('  source = "' .. settings.SOURCE_USER .. '",\n')

	file:write("}\n")

	file:close()
	return true
end

-- Function to load settings from file
function settings.loadFromFile()
	-- Get file path
	local filePath = settings.getFilePath()
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

	-- Apply the loaded settings to the state
	if loadedSettings.background and loadedSettings.background.value then
		state.setColorValue("background", loadedSettings.background.value)
	end

	-- Foreground color
	if loadedSettings.foreground and loadedSettings.foreground.value then
		state.setColorValue("foreground", loadedSettings.foreground.value)
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

	-- Box art width
	if loadedSettings.boxArtWidth then
		state.boxArtWidth = loadedSettings.boxArtWidth
	end

	-- Font
	if loadedSettings.font then
		state.selectedFont = loadedSettings.font
	end

	-- Font size
	if loadedSettings.fontSize then
		state.fontSize = loadedSettings.fontSize
	end

	-- Navigation alignment
	if loadedSettings.navigationAlignment then
		state.navigationAlignment = loadedSettings.navigationAlignment
	end

	-- Navigation alpha
	if loadedSettings.navigationAlpha then
		state.navigationAlpha = loadedSettings.navigationAlpha
	end

	-- Status alignment
	if loadedSettings.statusAlignment then
		state.statusAlignment = loadedSettings.statusAlignment
	end

	-- Time alignment
	if loadedSettings.timeAlignment then
		state.timeAlignment = loadedSettings.timeAlignment
	end

	-- Glyphs
	if loadedSettings.glyphs_enabled ~= nil then
		state.glyphs_enabled = loadedSettings.glyphs_enabled
	end

	-- Theme name
	if loadedSettings.themeName then
		state.themeName = loadedSettings.themeName
	end

	-- Header text enabled
	if loadedSettings.headerTextEnabled then
		state.headerTextEnabled = loadedSettings.headerTextEnabled
	end

	-- Source
	if loadedSettings.source then
		state.source = loadedSettings.source
	else
		state.source = settings.SOURCE_USER -- Default to user-created if not specified
	end

	return true
end

return settings
