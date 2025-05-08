--- Input handling module
---
--- Global input delay: All input events are throttled by a default delay via isGamepadPressedWithDelay(button, delay)
--- to ensure consistent input handling across all screens. Use this function for all navigation and action input
--- checks. To override, pass a custom delay as the second argument.
local love = require("love")
local input = {}

local joystick
local virtualJoystick = {}

-- Default global input delay (seconds)
local DEFAULT_INPUT_DELAY = 0.2
-- Table to track last press time for each button
local lastButtonPress = {}

-- Virtual joystick key mappings
-- Useful for testing application while developing
local keyToButton = {

	["return"] = "start", -- Start
	["space"] = "back", -- Back (Select)
	["escape"] = "guide", -- Guide (M)
	["c"] = "leftstick", -- Left Stick
	["v"] = "rightstick", -- Right Stick
	["q"] = "leftshoulder", -- L1
	["w"] = "rightshoulder", -- R1
	["e"] = "lefttrigger", -- L2
	["r"] = "righttrigger", -- R2
	["up"] = "dpup", -- D-Pad Up
	["down"] = "dpdown", -- D-Pad Down
	["left"] = "dpleft", -- D-Pad Left
	["right"] = "dpright", -- D-Pad Right
	["z"] = "a", -- A
	["x"] = "b", -- B
	["a"] = "x", -- X
	["s"] = "y", -- Y
}

-- Check if a gamepad button is pressed, enforcing a global or custom delay
function virtualJoystick.isGamepadPressedWithDelay(button, delay)
	delay = delay or DEFAULT_INPUT_DELAY
	local now = love.timer.getTime()

	-- Check if the button is currently pressed (physical gamepad or keyboard mapping)
	local isButtonDown = false

	-- Check if button parameter is valid
	if not button then
		error("Button parameter cannot be nil")
	elseif type(button) ~= "string" then
		error("Button parameter must be a string, got " .. type(button))
	end

	-- Check physical gamepad
	if joystick and joystick:isGamepadDown(button) then
		isButtonDown = true
	else
		-- Check keyboard mappings
		for key, mappedButton in pairs(keyToButton) do
			if mappedButton == button and love.keyboard.isDown(key) then
				isButtonDown = true
				break
			end
		end
	end

	-- Apply delay logic
	if isButtonDown then
		if not lastButtonPress[button] or now - lastButtonPress[button] >= delay then
			lastButtonPress[button] = now
			return true
		end
	else
		lastButtonPress[button] = nil -- Reset on release
	end
	return false
end

function input.load()
	local joysticks = love.joystick.getJoysticks()
	-- If there is at least one joystick connected, use the first one
	if #joysticks > 0 then
		joystick = joysticks[1]
	end
end

function input.update(dt)
	-- Check for global exit shortcut
	local leftShoulderPressed = false
	local rightShoulderPressed = false

	if joystick and joystick:isGamepadDown("leftshoulder") then
		leftShoulderPressed = true
	end
	if joystick and joystick:isGamepadDown("rightshoulder") then
		rightShoulderPressed = true
	end

	-- Also check keyboard mappings
	for key, mappedButton in pairs(keyToButton) do
		if mappedButton == "leftshoulder" and love.keyboard.isDown(key) then
			leftShoulderPressed = true
		end
		if mappedButton == "rightshoulder" and love.keyboard.isDown(key) then
			rightShoulderPressed = true
		end
	end

	if leftShoulderPressed and rightShoulderPressed then
		love.event.quit()
	end
end

-- Expose the virtual joystick for use in other modules
input.virtualJoystick = virtualJoystick

return input
