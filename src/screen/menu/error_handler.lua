--- Menu error handler
local ui = require("screen.menu.ui")

local errorHandler = {}

-- Error state
local errorMessage = nil

-- Function to set error message
function errorHandler.setError(message)
	errorMessage = message

	-- Show error in popup with an Exit button that quits the application
	ui.showPopup(message, { { text = "Exit", selected = true } })
end

-- Get current error message
function errorHandler.getErrorMessage()
	return errorMessage
end

function errorHandler.update(dt)
	-- No timer logic needed
end

return errorHandler
