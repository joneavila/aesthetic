--- Debug screen for development purposes
local love = require("love")
local state = require("state")
local controls = require("controls")
local background = require("ui.background")
local header = require("ui.header")

-- Module table to export public functions
local debug = {}

-- Screen switching
local switchScreen = nil

-- Debug state
local lastButtonPressed = ""
local lastAxisMoved = ""
local axisValues = {}
local rawButtonValues = {}
local nonStandardButtonsPressed = {}

-- Gamepad button list (from GamepadButton enum)
local gamepadButtons = {
	"a",
	"b",
	"x",
	"y",
	"start",
	"back",
	"guide",
	"leftstick",
	"rightstick",
	"leftshoulder",
	"rightshoulder",
	"dpup",
	"dpdown",
	"dpleft",
	"dpright",
}

-- Non-standard buttons to detect
local nonStandardButtons = {
	"power",
	"volumeup",
	"volumedown",
	"l2trigger",
	"r2trigger",
}

-- Gamepad axis list (from GamepadAxis enum)
local gamepadAxes = {
	"leftx",
	"lefty",
	"rightx",
	"righty",
	"triggerleft",
	"triggerright",
}

-- Function to check if the debug button combo is pressed
local function isDebugComboPressed(virtualJoystick)
	return virtualJoystick.isGamepadPressedWithDelay("dpleft") and virtualJoystick.isGamepadPressedWithDelay("a")
end

-- Safely check if a gamepad button is supported and pressed
local function safeIsGamepadDown(joystick, button)
	local success, result = pcall(function()
		return joystick.isGamepadPressedWithDelay(button)
	end)

	return success and result
end

-- Safely get gamepad axis value
local function safeGetGamepadAxis(joystick, axis)
	local success, result = pcall(function()
		return joystick:getGamepadAxis(axis)
	end)

	return success and result or 0
end

-- Safely get raw button state (for detecting any button)
local function getRawButtonValue(joystick, button)
	local success, result = pcall(function()
		return joystick:isDown(button)
	end)

	return success and result or false
end

function debug.load()
	-- Initialize debug screen
	axisValues = {}
	for _, axis in ipairs(gamepadAxes) do
		axisValues[axis] = 0
	end

	-- Initialize raw button detection
	rawButtonValues = {}
	nonStandardButtonsPressed = {}
	for _, button in ipairs(nonStandardButtons) do
		nonStandardButtonsPressed[button] = false
	end
end

function debug.draw()
	-- Draw background and header
	background.draw()
	header.draw("DEBUG")

	-- Set default body font
	love.graphics.setFont(state.fonts.body)

	-- Calculate text position (below header)
	local textY = header.getHeight() + 20

	-- Draw last button pressed text
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print("Last button pressed: " .. lastButtonPressed, 20, textY)
	textY = textY + 30

	-- Draw last axis moved text
	love.graphics.print("Last axis moved: " .. lastAxisMoved, 20, textY)
	textY = textY + 30

	-- Draw all axis values
	love.graphics.setColor(0.8, 0.8, 1, 1)
	love.graphics.print("Axis values:", 20, textY)
	textY = textY + 25

	for _, axis in ipairs(gamepadAxes) do
		local value = axisValues[axis] or 0
		love.graphics.print(axis .. ": " .. string.format("%.3f", value), 30, textY)
		textY = textY + 20
	end

	-- Draw all available buttons
	textY = textY + 10
	love.graphics.setColor(0.8, 1, 0.8, 1)
	love.graphics.print("Available buttons:", 20, textY)
	textY = textY + 25

	local virtualJoystick = require("input").virtualJoystick
	local col1Y = textY
	local col2Y = textY

	for i, button in ipairs(gamepadButtons) do
		local y = i <= #gamepadButtons / 2 and col1Y or col2Y
		local x = i <= #gamepadButtons / 2 and 30 or 200

		local isDown = safeIsGamepadDown(virtualJoystick, button)

		if isDown ~= nil then
			love.graphics.setColor(isDown and 1 or 0.6, isDown and 0.6 or 0.6, isDown and 0.6 or 0.6, 1)
			love.graphics.print(button, x, y)

			if i <= #gamepadButtons / 2 then
				col1Y = col1Y + 20
			else
				col2Y = col2Y + 20
			end
		end
	end

	-- Draw non-standard buttons section
	textY = textY + math.max(col1Y - textY, col2Y - textY) + 20
	love.graphics.setColor(1, 0.8, 0.8, 1)
	love.graphics.print("Non-standard buttons:", 20, textY)
	textY = textY + 25

	for _, button in ipairs(nonStandardButtons) do
		local isDown = nonStandardButtonsPressed[button] or false
		love.graphics.setColor(isDown and 1 or 0.6, isDown and 0.6 or 0.6, isDown and 0.6 or 0.6, 1)
		love.graphics.print(button, 30, textY)
		textY = textY + 20
	end

	-- Draw raw button values section
	textY = textY + 10
	love.graphics.setColor(0.8, 0.8, 0.8, 1)
	love.graphics.print("Raw button activity:", 20, textY)
	textY = textY + 25

	local rawTextY = textY
	local maxRawButtons = 8 -- Max number of raw buttons to display
	local displayCount = 0

	for button, value in pairs(rawButtonValues) do
		if value and displayCount < maxRawButtons then
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print("Button " .. button .. ": " .. tostring(value), 30, rawTextY)
			rawTextY = rawTextY + 20
			displayCount = displayCount + 1
		end
	end

	if displayCount == 0 then
		love.graphics.setColor(0.7, 0.7, 0.7, 1)
		love.graphics.print("Press any button to see raw values", 30, rawTextY)
	end

	-- Show instructions to exit
	local instructionsY = love.graphics.getHeight() - 50
	love.graphics.setColor(0.7, 0.7, 0.7, 1)
	love.graphics.print("Press D-pad Left + A to return to main menu", 20, instructionsY)
end

function debug.update(dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Check for button presses
	for _, button in ipairs(gamepadButtons) do
		local isDown = safeIsGamepadDown(virtualJoystick, button)

		if isDown then
			-- Update last button pressed (only if it's not part of the exit combo)
			if
				not (button == "dpleft" and safeIsGamepadDown(virtualJoystick, "a"))
				and not (button == "a" and safeIsGamepadDown(virtualJoystick, "dpleft"))
			then
				lastButtonPressed = button
			end
		end
	end

	-- Check for non-standard button presses
	for _, button in ipairs(nonStandardButtons) do
		local isDown = safeIsGamepadDown(virtualJoystick, button)
		nonStandardButtonsPressed[button] = isDown

		if isDown then
			lastButtonPressed = button
		end
	end

	-- Detect raw button presses (detect any button)
	for i = 1, 32 do -- Check a reasonable number of possible buttons
		local isDown = getRawButtonValue(virtualJoystick, i)
		if isDown then
			rawButtonValues[i] = true
			-- Update last button pressed
			lastButtonPressed = "Raw:" .. i
		else
			-- Clear the value if not pressed
			rawButtonValues[i] = nil
		end
	end

	-- Check axis movements
	for _, axis in ipairs(gamepadAxes) do
		local value = safeGetGamepadAxis(virtualJoystick, axis)

		-- Store the axis value
		axisValues[axis] = value

		-- Update last axis moved if there's significant movement
		if math.abs(value) > 0.25 then
			lastAxisMoved = axis .. " (" .. string.format("%.2f", value) .. ")"
		end
	end

	-- Return to main menu with the same button combination
	if isDebugComboPressed(virtualJoystick) and switchScreen then
		switchScreen("main_menu")
	end
end

function debug.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function debug.onEnter()
	-- Reset when entering
	lastButtonPressed = ""
	lastAxisMoved = ""
	for _, axis in ipairs(gamepadAxes) do
		axisValues[axis] = 0
	end

	-- Clear button detection
	rawButtonValues = {}
	nonStandardButtonsPressed = {}
	for _, button in ipairs(nonStandardButtons) do
		nonStandardButtonsPressed[button] = false
	end
end

function debug.onExit()
	-- Clean up when exiting the screen
	rawButtonValues = {}
	nonStandardButtonsPressed = {}
end

return debug
