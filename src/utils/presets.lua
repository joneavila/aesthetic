--- Presets management module
--- Enables user to save, load, and switch between multiple named theme configurations stored as separate files in a
--- presets directory
local state = require("state")
local system = require("utils.system")
local errorHandler = require("error_handler")
local paths = require("paths")

local presets = {}

-- Function to validate a preset file
function presets.validatePreset(presetName)
	if not presetName then
		return false, nil
	end

	-- Prepare the file path
	local filePath = paths.PRESETS_DIR .. "/" .. presetName .. ".lua"

	-- Check if the file exists
	if not system.fileExists(filePath) then
		return false, nil
	end

	-- Try to load the preset file
	local success, loadedPreset = pcall(function()
		local chunk, err = loadfile(filePath)
		if not chunk then
			error("Failed to load preset file: " .. (err or "unknown error"))
		end
		return chunk()
	end)

	if not success or type(loadedPreset) ~= "table" then
		errorHandler.setError("Invalid preset found: " .. presetName)
		return false, nil
	end

	-- Check essential preset properties
	if not loadedPreset.background or not loadedPreset.foreground or not loadedPreset.rgb then
		errorHandler.setError("Preset missing required properties: " .. presetName)
		return false, nil
	end

	return true, loadedPreset
end

-- Function to save a preset file
function presets.savePreset(presetName)
	if not presetName then
		presetName = "preset1"
	end

	-- Sanitize preset name for filesystem
	local sanitizedName = presetName:gsub("[%s%p]", "_")

	-- Create the presets directory if it doesn't exist
	-- Unlike most paths in `constants.lua` this path must be created regardless if theme is created
	local presetsDir = paths.PRESETS_DIR
	os.execute("test -d " .. presetsDir .. " || mkdir -p " .. presetsDir)

	-- Prepare the file path
	local filePath = presetsDir .. "/" .. sanitizedName .. ".lua"

	-- Create the file
	local file, err = io.open(filePath, "w")
	if not file then
		errorHandler.setError("Failed to create preset file: " .. (err or "unknown error"))
		return false
	end

	-- Serialize the preset as Lua code
	file:write("-- Aesthetic preset file\n")
	file:write("return {\n")

	-- Store the original display name
	file:write('  displayName = "' .. presetName .. '",\n')

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

	-- Created timestamp
	local currentTime = os.time()
	file:write("  created = " .. currentTime .. ",\n")

	-- Box art width
	file:write("  boxArtWidth = " .. state.boxArtWidth .. ",\n")

	-- Font family
	file:write('  font = "' .. state.selectedFont .. '",\n')

	-- Font size
	file:write('  fontSize = "' .. state.fontSize .. '",\n')

	-- Glyphs
	file:write("  glyphs_enabled = " .. tostring(state.glyphs_enabled) .. ",\n")

	-- Header text enabled
	file:write('  headerTextEnabled = "' .. state.headerTextEnabled .. '",\n')

	-- Header text alpha
	file:write("  headerTextAlpha = " .. tostring(state.headerTextAlpha) .. ",\n")

	-- Source (user-created by default when saving)
	file:write('  source = "' .. state.source .. '",\n')

	-- Launch screen type
	file:write('  launchScreenType = "' .. state.launchScreenType .. '",\n')

	file:write("}\n")

	file:close()
	return true
end

-- Function to load a preset from file
function presets.loadPreset(presetName)
	if not presetName then
		presetName = "preset1"
	end

	-- Get the ROOT_DIR from environment variable
	local rootDir = system.getEnvironmentVariable("ROOT_DIR")
	if not rootDir then
		return false
	end

	-- Prepare the file path - presetName is already sanitized at this point
	local filePath = rootDir .. "/presets/" .. presetName .. ".lua"

	-- Check if the file exists
	if not system.fileExists(filePath) then
		return false
	end

	-- Try to load the preset file
	local success, loadedPreset = pcall(function()
		local chunk, err = loadfile(filePath)
		if not chunk then
			error("Failed to load preset file: " .. (err or "unknown error"))
		end
		return chunk()
	end)

	if not success or type(loadedPreset) ~= "table" then
		return false
	end

	-- Apply the loaded preset to the state
	if loadedPreset.background and loadedPreset.background.value then
		state.setColorValue("background", loadedPreset.background.value)
	end

	-- Foreground color
	if loadedPreset.foreground and loadedPreset.foreground.value then
		state.setColorValue("foreground", loadedPreset.foreground.value)
	end

	-- RGB settings
	if loadedPreset.rgb then
		if loadedPreset.rgb.value then
			state.setColorValue("rgb", loadedPreset.rgb.value)
		end

		if loadedPreset.rgb.mode then
			state.rgbMode = loadedPreset.rgb.mode
		end

		if loadedPreset.rgb.brightness then
			state.rgbBrightness = loadedPreset.rgb.brightness
		end

		if loadedPreset.rgb.speed then
			state.rgbSpeed = loadedPreset.rgb.speed
		end
	end

	-- Box art width
	-- TODO: Delete old settings file from system to avoid converting to number
	if loadedPreset.boxArtWidth then
		state.boxArtWidth = tonumber(loadedPreset.boxArtWidth) or 0
	end

	-- Font
	if loadedPreset.font then
		state.selectedFont = loadedPreset.font
	end

	-- Font size
	if loadedPreset.fontSize then
		state.fontSize = loadedPreset.fontSize
	end

	-- Glyphs
	if loadedPreset.glyphs_enabled ~= nil then
		state.glyphs_enabled = loadedPreset.glyphs_enabled
	end

	-- Header text enabled
	if loadedPreset.headerTextEnabled then
		state.headerTextEnabled = loadedPreset.headerTextEnabled
	end

	-- Header text alpha
	if loadedPreset.headerTextAlpha then
		state.headerTextAlpha = tonumber(loadedPreset.headerTextAlpha) or 255
	end

	-- Source
	if loadedPreset.source then
		state.source = loadedPreset.source
	else
		state.source = "user" -- Default to user-created if not specified
	end

	-- Launch screen type
	if loadedPreset.launchScreenType then
		state.launchScreenType = loadedPreset.launchScreenType
	end

	return true
end

-- Function to list available presets
function presets.listPresets()
	-- Get the ROOT_DIR from environment variable
	local rootDir = system.getEnvironmentVariable("ROOT_DIR")
	if not rootDir then
		return {}
	end

	-- Prepare the presets directory
	local presetsDir = rootDir .. "/presets"

	-- Check if the directory exists
	local exists = os.execute("test -d " .. presetsDir)
	if not exists then
		return {}
	end

	-- List .lua files in the presets directory
	local presetsList = {}
	local handle = io.popen("ls " .. presetsDir .. "/*.lua 2>/dev/null")
	if not handle then
		errorHandler.setError("Failed to list presets")
		return {}
	end
	local result = handle:read("*a")
	handle:close()

	-- Parse the filenames from the result
	for filename in string.gmatch(result, "[^\n]+") do
		local presetName = string.match(filename, "/([^/]+)%.lua$")
		if presetName then
			table.insert(presetsList, presetName)
		end
	end

	return presetsList
end

return presets
