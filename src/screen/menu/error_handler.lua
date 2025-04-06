--- Menu error handler

local errorHandler = {}

-- Error state
local errorMessage = nil
local ui = nil -- Will be set when initialized

-- Function to set UI module reference (called after UI is loaded)
function errorHandler.setUI(uiModule)
	ui = uiModule
end

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
	if not ui then
		print("Error: UI module not set in errorHandler")
		return
	end

	local message = errorMessage or "Unknown error"
	if prefix then
		message = prefix .. ": " .. message
	end
	ui.showPopup(message, { { text = "Exit", selected = true } })
end

function errorHandler.update(_dt)
	-- No timer logic needed
end

return errorHandler
