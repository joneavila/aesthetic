--- Menu error handler
local ui = require("screen.menu.ui")

local errorHandler = {}

-- Error state
local errorMessage = nil

-- Function to set error message
function errorHandler.setError(message)
	errorMessage = message
end

-- Get current error message
function errorHandler.getErrorMessage()
	return errorMessage
end

-- Function to show error popup
function errorHandler.showErrorPopup(prefix)
	local message = errorMessage or "Unknown error"
	if prefix then
		message = prefix .. ": " .. message
	end
	ui.showPopup(message, { { text = "Exit", selected = true } })
end

function errorHandler.update(dt)
	-- No timer logic needed
end

return errorHandler
