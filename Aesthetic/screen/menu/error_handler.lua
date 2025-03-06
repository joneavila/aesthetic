--- Menu error handler
local constants = require("screen.menu.constants")

local errorHandler = {}

-- Error state
local errorMessage = nil
local errorTimer = 0

-- Function to set error message
function errorHandler.setError(message)
	errorMessage = message
	errorTimer = constants.ERROR_DISPLAY_TIME_SECONDS
end

-- Get current error message
function errorHandler.getErrorMessage()
	return errorMessage
end

-- Update error timer
function errorHandler.update(dt)
	if errorMessage and errorTimer > 0 then
		errorTimer = errorTimer - dt
		if errorTimer <= 0 then
			errorMessage = nil
		end
	end
end

return errorHandler
