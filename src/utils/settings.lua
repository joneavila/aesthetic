--- Settings management module
--- Handles saving and loading application (or configured theme) settings
local state = require("state")
local system = require("utils.system")
local errorHandler = require("screen.menu.error_handler")

local settings = {}

-- The filename to use for storing settings
settings.FILENAME = "settings.lua"

-- Function to save the current settings to a file
function settings.saveToFile()
	-- Get the ROOT_DIR from environment variable
	local rootDir = system.getEnvironmentVariable("ROOT_DIR")
	if not rootDir then
		errorHandler.setError("Failed to get ROOT_DIR environment variable")
		return false
	end

	-- Prepare the file path
	local filePath = rootDir .. "/" .. settings.FILENAME

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

	-- Glyphs
	file:write("  glyphs_enabled = " .. tostring(state.glyphs_enabled) .. ",\n")

	file:write("}\n")

	file:close()
	return true
end

-- Function to load settings from file
function settings.loadFromFile()
	-- Get the ROOT_DIR from environment variable
	local rootDir = system.getEnvironmentVariable("ROOT_DIR")
	if not rootDir then
		errorHandler.setError("Failed to get ROOT_DIR environment variable")
		return false
	end

	-- Prepare the file path
	local filePath = rootDir .. "/" .. settings.FILENAME

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

	-- Glyphs
	if loadedSettings.glyphs_enabled ~= nil then
		state.glyphs_enabled = loadedSettings.glyphs_enabled
	end

	return true
end

return settings
