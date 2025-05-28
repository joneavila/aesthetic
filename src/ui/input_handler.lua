--- Input Handler
--- Provides a clean abstraction layer for input handling in UI components
local inputHandler = {}

-- Create a new input handler that wraps the virtual joystick
function inputHandler.create(virtualJoystick)
	local inputModule = require("input")
	local handler = {}

	-- Use passed virtualJoystick if valid, otherwise fallback to input.virtualJoystick
	if virtualJoystick and type(virtualJoystick.isGamepadPressedWithDelay) == "function" then
		handler.virtualJoystick = virtualJoystick
	else
		handler.virtualJoystick = inputModule.virtualJoystick
	end

	-- Check if a button was pressed this frame with delay
	function handler.isPressed(button)
		return handler.virtualJoystick.isGamepadPressedWithDelay(button)
	end

	-- Check if a button is currently held down
	function handler.isDown(button)
		return handler.virtualJoystick.isGamepadDown and handler.virtualJoystick.isGamepadDown(button) or false
	end

	-- Get analog stick values (if needed in the future)
	function handler.getAnalogStick()
		return 0, 0
	end

	return handler
end

return inputHandler
