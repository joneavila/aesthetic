local state = require("state")
local colorUtils = require("utils.color")
local commands = require("utils.commands")
local system = require("utils.system")
local paths = require("paths")
local logger = require("utils.logger")
local fail = require("utils.fail")

-- Module table to export public functions
local rgb = {}

-- Function to convert brightness from UI range (1-10) to hardware range (0-255)
function rgb.brightnessToHardware(brightness)
	if brightness <= 1 then
		return 10 -- Minimum value to ensure LEDs stay on
	else
		return math.floor(((brightness - 1) / 9) * 255)
	end
end

-- Function to convert brightness from hardware range (0-255) to UI range (1-10)
function rgb.brightnessToUI(brightness)
	return math.min(10, math.max(1, math.floor((brightness / 255) * 9) + 1))
end

-- Function to convert hex color to standard RGB (0-255) values
function rgb.hexToStandardRGB(hexColor)
	local r, g, b = colorUtils.hexToRgb(hexColor)
	return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

-- Function to convert standard RGB (0-255) values to hex color
function rgb.standardRGBToHex(r, g, b)
	return colorUtils.rgbToHex(r / 255, g / 255, b / 255)
end

-- Function to execute the RGB configuration file or its contents
function rgb.executeConfig(rgbConfPath)
	if not rgbConfPath then
		logger.error("RGB configuration path is nil")
		return false
	end

	local file = io.open(rgbConfPath, "r")
	if not file then
		logger.error("Failed to open RGB configuration file: " .. rgbConfPath)
		return false
	end

	local command = file:read("*all")
	file:close()

	if not command or command == "" then
		logger.error("RGB configuration file is empty: " .. rgbConfPath)
		return false
	end

	-- Always execute the command directly due to permission issues
	local result = commands.executeCommand(command)

	return result == 0
end

-- Function to update RGB configuration and apply it immediately
function rgb.updateConfig()
	-- Generate the command
	local command = rgb.buildCommand()

	-- Create the configuration file for persistence
	if rgb.writeCommandToFile(command, paths.ACTIVE_RGB_CONF) then
		-- Execute the command directly
		local result = commands.executeCommand(command)
		return result == 0
	end

	return false
end

-- Function to build the RGB command string based on current settings
function rgb.buildCommand(forceOff)
	-- Base command for led_control.sh
	local command
	if system.isFile(paths.LED_CONTROL_SCRIPT) then
		command = paths.LED_CONTROL_SCRIPT
	else
		logger.error("LED control script not found")
		return false
	end

	-- Special case for "Off" mode or when forceOff is true
	if state.rgbMode == "Off" or forceOff then
		-- Format: $0 1 0 0 0 0 0 0 0
		command = command .. " 1 0 0 0 0 0 0 0"
	else
		-- Map RGB brightness from 1-10 to 0-255
		local brightness = rgb.brightnessToHardware(state.rgbBrightness)

		-- Get RGB color and convert to standard RGB components (0-255)
		local rgbColor = state.getColorValue("rgb")
		local r, g, b = rgb.hexToStandardRGB(rgbColor)

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
	end

	return command
end

-- Function to write command to config file
function rgb.writeCommandToFile(command, rgbConfPath)
	if type(command) ~= "string" or command == "" then
		return fail("Invalid command passed to writeCommandToFile: " .. tostring(command))
	end
	system.writeFile(rgbConfPath, command)
	logger.debug(string.format("Writing command '%s' to '%s'", command, rgbConfPath))
	commands.executeCommand(string.format('echo "%s" > "%s"', command, rgbConfPath))
	return true
end

-- Function to create RGB configuration file at the specified path
function rgb.createConfigFile(rgbConfPath)
	-- Build the command
	local command = rgb.buildCommand()

	-- Write the command to file
	return rgb.writeCommandToFile(command, rgbConfPath)
end

-- Function to parse RGB configuration from a file
function rgb.parseConfig(filePath)
	if not filePath then
		logger.error("File path is nil")
		return nil
	end

	local file = io.open(filePath, "r")
	if not file then
		logger.error("Failed to open RGB configuration file: " .. filePath)
		fail("Failed to open RGB configuration file: " .. filePath)
		return nil
	end

	local content = file:read("*all")
	file:close()

	-- Extract parameters from the command
	local params = {}

	-- Parse mode number (first parameter after the script path)
	-- Match regardless of the path to led_control.sh
	local modeNum = content:match("led_control%.sh%s+(%d+)")
	if not modeNum then
		logger.error("Failed to parse mode from RGB config: " .. content)
		return nil
	end

	-- Parse remaining parameters based on mode
	local paramStr = content:match("led_control%.sh%s+%d+%s+(.+)$")
	if not paramStr then
		logger.error("Failed to parse parameters from RGB config: " .. content)
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
		brightness = rgb.brightnessToUI(params[1]),
	}

	-- Parse remaining parameters based on mode
	if modeNum == "1" then
		-- Solid: brightness, right_r, right_g, right_b, left_r, left_g, left_b
		config.color = rgb.standardRGBToHex(params[2], params[3], params[4])
	elseif modeNum == "2" or modeNum == "3" or modeNum == "4" then
		-- Breathing modes: brightness, r, g, b
		config.color = rgb.standardRGBToHex(params[2], params[3], params[4])
	elseif modeNum == "5" or modeNum == "6" then
		-- Rainbow modes: brightness, speed
		config.speed = math.floor(params[2] / 5)
	end

	return config
end

-- Function to restore RGB configuration from backup or turn off if no backup
function rgb.restoreConfig()
	-- Skip if RGB is not supported on this device
	if state.hasRGBSupport == false then
		logger.debug("Skipping RGB restoreConfig - device does not support RGB lighting")
		return true
	end

	-- If backup exists, restore it
	if system.fileExists(paths.ACTIVE_RGB_CONF_BACKUP) then
		-- Copy backup back to active config
		if not system.copyFile(paths.ACTIVE_RGB_CONF_BACKUP, paths.ACTIVE_RGB_CONF) then
			return false
		end

		-- Execute the restored config
		logger.debug("Backup found, executing restored config")
		return rgb.executeConfig(paths.ACTIVE_RGB_CONF)
	else
		-- No backup exists, which means there was no RGB lighting
		-- when the application started. Turn off RGB lighting.
		-- Create an "off" command for RGB using buildCommand with forceOff parameter
		local command = rgb.buildCommand(true)

		-- Write the command to file
		logger.debug("No backup found, writing 'off' command to file")
		rgb.writeCommandToFile(command, paths.ACTIVE_RGB_CONF)

		-- Execute the command directly to turn off lighting
		logger.debug("Executing 'off' command")
		return commands.executeCommand(command) == 0
	end
end

-- Function to backup the current RGB configuration if it exists
function rgb.backupConfig()
	if not system.fileExists(paths.ACTIVE_RGB_CONF) then
		logger.error("Active RGB configuration file does not exist: " .. paths.ACTIVE_RGB_CONF)
		return fail("Active RGB configuration file does not exist: " .. paths.ACTIVE_RGB_CONF)
	end
	return system.copy(paths.ACTIVE_RGB_CONF, paths.ACTIVE_RGB_CONF_BACKUP)
end

-- Function to install RGB config from theme to active config
function rgb.installFromTheme()
	-- Skip if RGB is not supported on this device
	if state.hasRGBSupport == false then
		logger.debug("Skipping RGB theme installation - device does not support RGB lighting")
		return true
	end

	-- Build command string based on current RGB settings
	local command = rgb.buildCommand()

	-- Write command to config file for persistence
	local writeSuccess = rgb.writeCommandToFile(command, paths.ACTIVE_RGB_CONF)
	if not writeSuccess then
		return fail("Failed to write RGB command to config file")
	end

	-- Execute the command directly
	logger.debug(string.format("Setting RGB lighting with command '%s'", command))
	commands.executeCommand(command)

	return true
end

return rgb
