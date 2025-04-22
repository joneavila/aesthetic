--- Error handler

local errorHandler = {}
local modal = require("ui.modal")

-- Error state
local errorMessage = nil
local ui = nil -- Keeping for backward compatibility

--- Sets the UI module reference (keeping for backward compatibility)
--- This function is necessary to avoid circular dependencies between modules
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

-- Function to show error modal
function errorHandler.showErrorModal(prefix)
	local message = errorMessage or "Unknown error"
	if prefix then
		message = prefix .. ": " .. message
	end
	modal.showModal(message, { { text = "Exit", selected = true } })
end

function errorHandler.update(_dt)
	-- No timer logic needed
end

return errorHandler
