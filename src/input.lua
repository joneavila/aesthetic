--- Input handling module
local love = require("love")
local input = {}
local inputCooldown = 0.15
local timeSinceLastInput = 0
local joystick
local virtualJoystick = {}

-- Virtual joystick key mappings
-- Useful for testing application while developing
local keyToButton = {
	["escape"] = "back",
	["return"] = "start",
	["lshift"] = "leftshoulder",
	["rshift"] = "rightshoulder",
	["up"] = "dpup",
	["down"] = "dpdown",
	["left"] = "dpleft",
	["right"] = "dpright",
	["a"] = "a",
	["b"] = "b",
	["x"] = "x",
	["y"] = "y",
}

-- Check if a gamepad button is currently pressed
virtualJoystick.isGamepadDown = function(_self, button)
	if not button then
		error("Button parameter cannot be nil")
	end

	-- Check physical gamepad
	if joystick and joystick:isGamepadDown(button) then
		return true
	end

	-- Check keyboard mappings
	for key, mappedButton in pairs(keyToButton) do
		if mappedButton == button and love.keyboard.isDown(key) then
			return true
		end
	end

	return false
end

-- Handle input
local function handleInput(_dt)
	-- Check if enough time has passed since the last input to prevent rapid inputs
	if timeSinceLastInput >= inputCooldown then
		-- Exit application on shoulder button combination
		-- This input is handled here because it is a global shortcut
		if virtualJoystick:isGamepadDown("leftshoulder") and virtualJoystick:isGamepadDown("rightshoulder") then
			love.event.quit()
			timeSinceLastInput = 0
			return
		end
	end
end

function input.load()
	local joysticks = love.joystick.getJoysticks()
	-- If there is at least one joystick connected, use the first one
	if #joysticks > 0 then
		joystick = joysticks[1]
	end
end

function input.update(dt)
	timeSinceLastInput = timeSinceLastInput + dt
	handleInput(dt)
end

-- Expose the virtual joystick for use in other modules
input.virtualJoystick = virtualJoystick

return input
