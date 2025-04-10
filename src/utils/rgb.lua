local state = require("state")
local colorUtils = require("utils.color")
local commands = require("utils.commands")
local system = require("utils.system")
local constants = require("screen.menu.constants")

local paths = constants.PATHS

-- Module table to export public functions
local rgb = {}

-- Function to create RGB configuration file at the specified path
function rgb.createConfigFile(rgbDir, rgbConfPath)
	-- Ensure path exists for RGB directory
	if not system.ensurePath(rgbDir) then
		return false
	end

	-- Open `rgbconf.sh` for writing
	local rgbConfFile = io.open(rgbConfPath, "w")
	if not rgbConfFile then
		return false
	end

	-- Base command for led_control.sh
	local command = "/opt/muos/device/current/script/led_control.sh"

	-- Map RGB brightness from 0-100 to 0-255
	local brightness = math.floor((state.rgbBrightness / 100) * 255)

	-- Get RGB color and convert to RGB components (0-255)
	local rgbColor = state.getColorValue("rgb")
	local r, g, b = colorUtils.hexToRgb(rgbColor)
	r = math.floor(r * 255)
	g = math.floor(g * 255)
	b = math.floor(b * 255)

	-- Format command based on rgbMode
	if state.rgbMode == "Solid" then
		-- Mode 1: Solid Color (No Effects)
		-- Format: $0 1 <brightness> <right_r> <right_g> <right_b> <left_r> <left_g> <left_b>
		-- Both joysticks get the same color in this implementation
		command = command .. string.format(" 1 %d %d %d %d %d %d %d", brightness, r, g, b, r, g, b)
	elseif state.rgbMode == "Fast Breathing" then
		-- Mode 2: Solid Color (Breathing, Fast)
		-- Format: $0 2 <brightness> <r> <g> <b>
		command = command .. string.format(" 2 %d %d %d %d", brightness, r, g, b)
	elseif state.rgbMode == "Medium Breathing" then
		-- Mode 3: Solid Color (Breathing, Medium)
		-- Format: $0 3 <brightness> <r> <g> <b>
		command = command .. string.format(" 3 %d %d %d %d", brightness, r, g, b)
	elseif state.rgbMode == "Slow Breathing" then
		-- Mode 4: Solid Color (Breathing, Slow)
		-- Format: $0 4 <brightness> <r> <g> <b>
		command = command .. string.format(" 4 %d %d %d %d", brightness, r, g, b)
	elseif state.rgbMode == "Mono Rainbow" then
		-- Mode 5: Monochromatic Rainbow (Cycle Between RGB Colors)
		-- Format: $0 5 <brightness_value> <speed_value>
		command = command .. string.format(" 5 %d %d", brightness, state.rgbSpeed * 5)
	elseif state.rgbMode == "Multi Rainbow" then
		-- Mode 6: Multicolor Rainbow (Rainbow Swirl Effect)
		-- Format: $0 6 <brightness_value> <speed_value>
		command = command .. string.format(" 6 %d %d", brightness, state.rgbSpeed * 5)
	end

	-- Write command to file
	rgbConfFile:write(command)
	rgbConfFile:close()

	-- Make the file executable
	commands.executeCommand(string.format('chmod +x "%s"', rgbConfPath))

	return true
end

-- Function to execute the RGB configuration file
function rgb.executeConfig(rgbConfPath)
	if not rgbConfPath then
		return false
	end
	commands.executeCommand(rgbConfPath)
	return true
end

-- Function to update RGB configuration and apply it immediately
function rgb.updateConfig()
	local rgbDir = "/run/muos/storage/theme/active/rgb"
	local rgbConfPath = rgbDir .. "/rgbconf.sh"

	-- Create and execute the configuration
	if rgb.createConfigFile(rgbDir, rgbConfPath) then
		return rgb.executeConfig(rgbConfPath)
	end
	return false
end

-- Function to parse RGB configuration from a file
function rgb.parseConfig(filePath)
	if not filePath then
		return nil
	end

	local file = io.open(filePath, "r")
	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	-- Extract parameters from the command
	local mode, brightness, r, g, b, speed
	local params = {}

	-- Parse mode number (first parameter after the script path)
	local modeNum = content:match("/led_control%.sh%s+(%d+)")
	if not modeNum then
		return nil
	end

	-- Parse remaining parameters based on mode
	local paramStr = content:match("/led_control%.sh%s+%d+%s+(.+)$")
	if not paramStr then
		return nil
	end

	-- Split parameters into array
	for param in paramStr:gmatch("%S+") do
		table.insert(params, tonumber(param) or 0)
	end

	-- Map mode number to mode name
	local modeMap = {
		["1"] = "Solid",
		["2"] = "Fast Breathing",
		["3"] = "Medium Breathing",
		["4"] = "Slow Breathing",
		["5"] = "Mono Rainbow",
		["6"] = "Multi Rainbow",
	}

	local config = {
		mode = modeMap[modeNum] or "Solid",
		brightness = math.floor((params[1] / 255) * 100), -- Convert 0-255 to 0-100
	}

	-- Parse remaining parameters based on mode
	if modeNum == "1" then
		-- Solid: brightness, right_r, right_g, right_b, left_r, left_g, left_b
		config.color = colorUtils.rgbToHex(params[2] / 255, params[3] / 255, params[4] / 255)
	elseif modeNum == "2" or modeNum == "3" or modeNum == "4" then
		-- Breathing modes: brightness, r, g, b
		config.color = colorUtils.rgbToHex(params[2] / 255, params[3] / 255, params[4] / 255)
	elseif modeNum == "5" or modeNum == "6" then
		-- Rainbow modes: brightness, speed
		config.speed = math.floor(params[2] / 5)
	end

	return config
end

-- Function to backup current RGB configuration
function rgb.backupConfig()
	-- Check if active config exists
	if not system.fileExists(paths.ACTIVE_RGB_CONF_PATH) then
		return false
	end

	-- Ensure backup directory exists
	if not system.ensurePath(paths.ACTIVE_RGB_DIR) then
		return false
	end

	-- Copy current config to backup
	return system.copyFile(paths.ACTIVE_RGB_CONF_PATH, paths.ACTIVE_RGB_CONF_BACKUP_PATH)
end

-- Function to restore RGB configuration from backup
function rgb.restoreConfig()
	-- Only restore if we haven't applied a theme and backup exists
	if state.themeApplied or not system.fileExists(paths.ACTIVE_RGB_CONF_BACKUP_PATH) then
		return false
	end

	-- Copy backup back to active config
	if not system.copyFile(paths.ACTIVE_RGB_CONF_BACKUP_PATH, paths.ACTIVE_RGB_CONF_PATH) then
		return false
	end

	-- Execute the restored config
	return rgb.executeConfig(paths.ACTIVE_RGB_CONF_PATH)
end

-- Function to initialize RGB state from current configuration
function rgb.initializeFromCurrentConfig()
	-- Try to read current configuration
	local config = rgb.parseConfig(paths.ACTIVE_RGB_CONF_PATH)
	if config then
		-- Update state with current settings
		state.rgbMode = config.mode
		state.rgbBrightness = config.brightness
		if config.color then
			state.setColorValue("rgb", config.color)
		end
		if config.speed then
			state.rgbSpeed = config.speed
		end
	end

	-- Backup current configuration
	return rgb.backupConfig()
end

return rgb
