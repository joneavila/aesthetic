--- Presets management module
---
--- This module enables users to save, load, and switch between multiple named theme configurations
--- stored as separate files in a presets directory.
---
--- PRESET FILE FORMAT: Each preset file is a Lua table containing theme configuration fields that map directly to
--- state.lua variables.
---
--- ERROR HANDLING: Missing or invalid fields trigger logger warnings and fallback to state.lua defaults.

local errorHandler = require("error_handler")
local logger = require("utils.logger")
local paths = require("paths")
local state = require("state")

local fonts = require("ui.fonts")

local system = require("utils.system")

local presets = {}

-- Helper to get all preset directories (user first, then default)
local function getPresetDirectories()
	local dirs = {}
	local userDir = paths.getUserThemePresetsPath()
	if userDir then
		table.insert(dirs, userDir)
	end
	table.insert(dirs, paths.PRESETS_DIR)
	return dirs
end

-- Helper to get the preset file path (user first, then default)
local function getPresetFilePath(presetName)
	for _, dir in ipairs(getPresetDirectories()) do
		local filePath = dir .. "/" .. presetName .. ".lua"
		if system.fileExists(filePath) then
			return filePath
		end
	end
	-- Default to user dir for saving
	local userDir = paths.getUserThemePresetsPath() or paths.PRESETS_DIR
	return userDir .. "/" .. presetName .. ".lua"
end

-- Function to validate a preset file
function presets.validatePreset(presetName)
	if not presetName then
		return false, nil
	end
	local filePath = getPresetFilePath(presetName)
	if not system.fileExists(filePath) then
		return false, nil
	end
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
	local sanitizedName = presetName:gsub("[%s%p]", "_")
	local presetsDir = paths.getUserThemePresetsPath() or paths.PRESETS_DIR
	os.execute("test -d " .. presetsDir .. " || mkdir -p " .. presetsDir)
	local filePath = presetsDir .. "/" .. sanitizedName .. ".lua"
	local file, err = io.open(filePath, "w")
	if not file then
		errorHandler.setError("Failed to create preset file: " .. (err or "unknown error"))
		return false
	end
	file:write("-- Aesthetic preset file\n")
	file:write("return {\n")
	file:write('  displayName = "' .. presetName .. '",\n')
	file:write("  background = {\n")
	file:write('    value = "' .. state.getColorValue("background") .. '",\n')
	file:write("  },\n")
	file:write("  foreground = {\n")
	file:write('    value = "' .. state.getColorValue("foreground") .. '",\n')
	file:write("  },\n")
	file:write("  rgb = {\n")
	file:write('    value = "' .. state.getColorValue("rgb") .. '",\n')
	file:write('    mode = "' .. state.rgbMode .. '",\n')
	file:write("    brightness = " .. state.rgbBrightness .. ",\n")
	file:write("    speed = " .. state.rgbSpeed .. ",\n")
	file:write("  },\n")
	local currentTime = os.time()
	file:write("  created = " .. currentTime .. ",\n")
	file:write("  boxArtWidth = " .. state.boxArtWidth .. ",\n")
	file:write('  font = "' .. fonts.getSelectedFont() .. '",\n')
	file:write("  glyphsEnabled = " .. tostring(state.glyphsEnabled) .. ",\n")
	file:write('  headerTextEnabled = "' .. state.headerTextEnabled .. '",\n')
	file:write("  headerTextAlpha = " .. tostring(state.headerTextAlpha) .. ",\n")
	file:write('  source = "' .. state.source .. '",\n')
	file:write('  homeScreenLayout = "' .. state.homeScreenLayout .. '",\n')
	file:write("}\n")
	file:close()
	return true
end

-- Helper function to safely load a field with logging and default fallback
local function loadField(loadedPreset, presetName, fieldPath, targetSetter, defaultValue, fieldType)
	logger.debug("loadField called for field: " .. fieldPath)
	fieldType = fieldType or "any"

	-- Navigate nested field path (e.g., "background.value")
	local value = loadedPreset
	local pathParts = {}
	for part in fieldPath:gmatch("[^%.]+") do
		table.insert(pathParts, part)
	end

	for _, part in ipairs(pathParts) do
		if type(value) == "table" and value[part] ~= nil then
			value = value[part]
		else
			value = nil
			break
		end
	end
	logger.debug("Field " .. fieldPath .. " has value: " .. tostring(value))

	-- Validate field type if specified
	if value ~= nil then
		if fieldType == "number" and type(value) ~= "number" then
			value = tonumber(value)
			if value == nil then
				logger.warning(
					"Preset '"
						.. presetName
						.. "': Field '"
						.. fieldPath
						.. "' is not a valid number, using default: "
						.. tostring(defaultValue)
				)
				value = defaultValue
			end
		elseif fieldType == "string" and type(value) ~= "string" then
			logger.warning(
				"Preset '"
					.. presetName
					.. "': Field '"
					.. fieldPath
					.. "' is not a string, using default: "
					.. tostring(defaultValue)
			)
			value = defaultValue
		elseif fieldType == "boolean" and type(value) ~= "boolean" then
			logger.warning(
				"Preset '"
					.. presetName
					.. "': Field '"
					.. fieldPath
					.. "' is not a boolean, using default: "
					.. tostring(defaultValue)
			)
			value = defaultValue
		end
	end

	-- Use default if field is missing
	if value == nil then
		if defaultValue ~= nil then
			logger.warning(
				"Preset '"
					.. presetName
					.. "': Missing field '"
					.. fieldPath
					.. "', using default: "
					.. tostring(defaultValue)
			)
			value = defaultValue
		else
			logger.warning("Preset '" .. presetName .. "': Missing field '" .. fieldPath .. "', skipping")
			return false
		end
	end

	-- Apply the value using the provided setter function
	local success, err = pcall(targetSetter, value)
	if not success then
		logger.warning(
			"Preset '"
				.. presetName
				.. "': Failed to set field '"
				.. fieldPath
				.. "': "
				.. tostring(err)
				.. ", using default: "
				.. tostring(defaultValue)
		)
		if defaultValue ~= nil then
			logger.debug("Setting default value for field: " .. fieldPath)
			pcall(targetSetter, defaultValue)
		end
		return false
	end
	logger.debug("Successfully set field: " .. fieldPath)

	return true
end

-- Function to load a preset from file
function presets.loadPreset(presetName)
	logger.debug("Starting loadPreset for: " .. tostring(presetName))
	local filePath = getPresetFilePath(presetName)
	logger.debug("Looking for preset file at: " .. filePath)
	if not system.fileExists(filePath) then
		logger.error("Preset file does not exist: " .. filePath)
		return false
	end
	logger.debug("Preset file exists, attempting to load")
	local success, loadedPreset = pcall(function()
		local chunk, err = loadfile(filePath)
		if not chunk then
			error("Failed to load preset file: " .. (err or "unknown error"))
		end
		return chunk()
	end)
	if not success or type(loadedPreset) ~= "table" then
		logger.error("Failed to load or parse preset file: " .. presetName .. " - " .. tostring(loadedPreset))
		return false
	end
	logger.debug("Successfully loaded preset file, beginning field loading")
	logger.info("Loading preset: " .. presetName)

	-- REQUIRED FIELDS - Theme name
	logger.debug("Loading theme name field")
	loadField(loadedPreset, presetName, "themeName", function(v)
		state.themeName = v
	end, "Aesthetic", "string")

	-- REQUIRED FIELDS - Colors
	logger.debug("Loading background color field")
	loadField(loadedPreset, presetName, "background.value", function(v)
		state.setColorValue("background", v)
	end, "#1E40AF", "string")
	logger.debug("Loading foreground color field")
	loadField(loadedPreset, presetName, "foreground.value", function(v)
		state.setColorValue("foreground", v)
	end, "#FFFFFF", "string")
	logger.debug("Loading rgb color field")
	loadField(loadedPreset, presetName, "rgb.value", function(v)
		state.setColorValue("rgb", v)
	end, "#1E40AF", "string")

	-- OPTIONAL FIELDS - Background settings
	loadField(loadedPreset, presetName, "background.type", function(v)
		state.backgroundType = v
	end, "Solid", "string")

	-- Background gradient handling
	local hasGradient = loadedPreset.backgroundGradient and loadedPreset.backgroundGradient.value
	if hasGradient then
		loadField(loadedPreset, presetName, "backgroundGradient.value", function(v)
			state.setColorValue("backgroundGradient", v)
		end, "#155CFB", "string")
		loadField(loadedPreset, presetName, "backgroundGradient.direction", function(v)
			state.backgroundGradientDirection = v
		end, "Vertical", "string")

		-- Set background type based on gradient presence and color matching
		local bgValue = loadedPreset.background and loadedPreset.background.value
		local gradientValue = loadedPreset.backgroundGradient.value
		if bgValue and gradientValue and bgValue ~= gradientValue then
			state.backgroundType = "Gradient"
		end
	end

	-- OPTIONAL FIELDS - RGB settings
	loadField(loadedPreset, presetName, "rgb.mode", function(v)
		state.rgbMode = v
	end, "Solid", "string")
	loadField(loadedPreset, presetName, "rgb.brightness", function(v)
		state.rgbBrightness = v
	end, 5, "number")
	loadField(loadedPreset, presetName, "rgb.speed", function(v)
		state.rgbSpeed = v
	end, 5, "number")

	-- OPTIONAL FIELDS - Layout and display
	loadField(loadedPreset, presetName, "boxArtWidth", function(v)
		state.boxArtWidth = v
	end, 0, "number")
	loadField(loadedPreset, presetName, "homeScreenLayout", function(v)
		state.homeScreenLayout = v
	end, "Grid", "string")

	-- OPTIONAL FIELDS - Font settings (support both fontFamily and legacy font field)
	logger.debug("Loading font family field")
	local fontSet = loadField(loadedPreset, presetName, "fontFamily", function(v)
		logger.debug("Attempting to set font family to: " .. tostring(v))
		fonts.setSelectedFont(v)
	end, nil, "string")
	if not fontSet then
		logger.debug("fontFamily field not found, trying legacy font field")
		loadField(loadedPreset, presetName, "font", function(v)
			logger.debug("Attempting to set font (legacy) to: " .. tostring(v))
			fonts.setSelectedFont(v)
		end, nil, "string")
	end
	-- TEMPORARILY DISABLED: Font size loading
	-- logger.debug("Loading font size field")
	-- loadField(loadedPreset, presetName, "fontSize", function(v)
	-- 	logger.debug("Attempting to set font size to: " .. tostring(v))
	-- 	fonts.setFontSize(v)
	-- end, nil, "string")

	-- OPTIONAL FIELDS - Header settings
	loadField(loadedPreset, presetName, "headerTextAlignment", function(v)
		state.headerTextAlignment = v
	end, 2, "number")
	loadField(loadedPreset, presetName, "headerTextAlpha", function(v)
		state.headerTextAlpha = v
	end, 0, "number")
	loadField(loadedPreset, presetName, "headerTextEnabled", function(v)
		state.headerTextEnabled = v
	end, "Disabled", "string")

	-- OPTIONAL FIELDS - Navigation settings
	loadField(loadedPreset, presetName, "navigationAlignment", function(v)
		state.navigationAlignment = v
	end, "Left", "string")
	loadField(loadedPreset, presetName, "navigationAlpha", function(v)
		state.navigationAlpha = v
	end, 100, "number")

	-- OPTIONAL FIELDS - Status and time alignment
	loadField(loadedPreset, presetName, "statusAlignment", function(v)
		state.statusAlignment = v
	end, "Right", "string")
	loadField(loadedPreset, presetName, "timeAlignment", function(v)
		state.timeAlignment = v
	end, "Left", "string")

	-- OPTIONAL FIELDS - UI features
	loadField(loadedPreset, presetName, "glyphsEnabled", function(v)
		state.glyphsEnabled = v
	end, true, "boolean")

	-- OPTIONAL FIELDS - Metadata
	loadField(loadedPreset, presetName, "source", function(v)
		state.source = v
	end, "user", "string")

	logger.info("Successfully loaded preset: " .. presetName)
	logger.debug("Finished loading all fields for preset: " .. presetName)
	return true
end

-- Function to list available presets
function presets.listPresets()
	local dirs = getPresetDirectories()
	local presetSet = {}
	local presetList = {}
	for _, dir in ipairs(dirs) do
		local exists = os.execute("test -d " .. dir)
		if exists then
			local handle = io.popen("ls " .. dir .. "/*.lua 2>/dev/null")
			if handle then
				local result = handle:read("*a")
				handle:close()
				for filename in string.gmatch(result, "[^\n]+") do
					local presetName = string.match(filename, "/([^/]+)%.lua$")
					if presetName and not presetSet[presetName] then
						presetSet[presetName] = true
						table.insert(presetList, presetName)
					end
				end
			end
		end
	end
	return presetList
end

return presets
