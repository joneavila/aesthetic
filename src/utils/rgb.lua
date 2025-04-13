local state = require("state")
local colorUtils = require("utils.color")
local commands = require("utils.commands")
local system = require("utils.system")
local constants = require("screen.menu.constants")

local paths = constants.PATHS

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
		return false
	end

	local file = io.open(rgbConfPath, "r")
	if not file then
		return false
	end

	local command = file:read("*all")
	file:close()

	if not command or command == "" then
		return false
	end

	-- Always execute the command directly due to permission issues
	local result = commands.executeCommand(command)

	return result == 0
end

-- Function to update RGB configuration and apply it immediately
function rgb.updateConfig()
	local rgbDir = system.getEnvironmentVariable("RGB_DIR") or "/run/muos/storage/theme/active/rgb"
	local rgbConfPath = rgbDir .. "/rgbconf.sh"

	system.ensurePath(rgbDir)

	-- Generate the command
	local command = rgb.buildCommand()

	-- Create the configuration file for persistence
	if rgb.writeCommandToFile(command, rgbConfPath) then
		-- Execute the command directly
		local result = commands.executeCommand(command)
		return result == 0
	end

	return false
end

-- Function to build the RGB command string based on current settings
function rgb.buildCommand()
	-- Base command for led_control.sh
	local command = "/opt/muos/device/current/script/led_control.sh"

	-- Special case for "Off" mode
	if state.rgbMode == "Off" then
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
	-- Write directly to the target file using command
	commands.executeCommand(string.format('echo "%s" > "%s"', command, rgbConfPath))

	-- Make the file executable
	commands.executeCommand(string.format('chmod +x "%s"', rgbConfPath))

	return true
end

-- Function to create RGB configuration file at the specified path
function rgb.createConfigFile(rgbDir, rgbConfPath)
	system.ensurePath(rgbDir)

	-- Build the command
	local command = rgb.buildCommand()

	-- Write the command to file
	return rgb.writeCommandToFile(command, rgbConfPath)
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

-- Function to restore RGB configuration from backup or turn off if no backup
function rgb.restoreConfig()
	-- Only restore if we haven't applied a theme
	if state.themeApplied then
		return false
	end

	-- If backup exists, restore it
	if system.fileExists(paths.ACTIVE_RGB_CONF_BACKUP_PATH) then
		-- Copy backup back to active config
		if not system.copyFile(paths.ACTIVE_RGB_CONF_BACKUP_PATH, paths.ACTIVE_RGB_CONF_PATH) then
			return false
		end

		-- Execute the restored config
		return rgb.executeConfig(paths.ACTIVE_RGB_CONF_PATH)
	else
		-- No backup exists, which means there was no RGB lighting
		-- when the application started. Turn off RGB lighting.
		local rgbDir = system.getEnvironmentVariable("RGB_DIR") or "/run/muos/storage/theme/active/rgb"
		local rgbConfPath = rgbDir .. "/rgbconf.sh"

		-- Ensure directory exists
		system.ensurePath(rgbDir)

		-- Create an "off" command for RGB
		local command = "/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0"

		-- Write the command to file
		rgb.writeCommandToFile(command, rgbConfPath)

		-- Execute the command directly to turn off lighting
		return commands.executeCommand(command) == 0
	end
end

-- Function to initialize RGB state from current configuration
function rgb.initializeFromCurrentConfig()
	-- Try to read current configuration
	if system.fileExists(paths.ACTIVE_RGB_CONF_PATH) then
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
	else
		-- If no RGB configuration exists, just take note of this fact
		-- We'll use this later to turn off RGB when exiting without applying a theme
		return true
	end
end

-- Function to install RGB config from theme to active config
function rgb.installFromTheme()
	-- Get the active RGB directory and configuration path
	local rgbDir = system.getEnvironmentVariable("RGB_DIR") or "/run/muos/storage/theme/active/rgb"
	local rgbConfPath = rgbDir .. "/rgbconf.sh"

	system.ensurePath(rgbDir)

	-- Build command string based on current RGB settings
	local command = rgb.buildCommand()

	-- Write command to config file for persistence
	rgb.writeCommandToFile(command, rgbConfPath)

	-- Execute the command directly
	commands.executeCommand(command)

	return true
end

return rgb
