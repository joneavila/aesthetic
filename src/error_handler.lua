--- Error handler
--- This module centralizes error handling functionality throughout the application

local errorHandler = {}
local modal = require("ui.modal")
local logger = require("utils.logger")
local fonts = require("ui.fonts")

-- Error state
local errorMessage = nil

-- Function to set error message
function errorHandler.setError(message)
	logger.error("Error set: " .. tostring(message))
	errorMessage = message
end

-- Function to get error message
function errorHandler.getErrorMessage()
	return errorMessage
end

function errorHandler.update(_dt)
	-- No timer logic needed
end

return errorHandler
