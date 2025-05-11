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

-- Get current error message
function errorHandler.getErrorMessage()
	return errorMessage
end

-- Function to show error modal
function errorHandler.showErrorModal(prefix)
	local message = errorMessage or "Unknown error"
	if prefix then
		message = prefix .. ": " .. message
	end
	logger.error("Showing error modal: " .. message)

	-- Use scrollable modal with error font
	modal.showScrollableModal(message, { { text = "Exit", selected = true } }, fonts.loaded.error)
end

function errorHandler.update(_dt)
	-- No timer logic needed
end

return errorHandler
