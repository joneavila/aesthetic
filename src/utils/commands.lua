--- Executes a command and sets an error message if the command fails
--- This function calls `errorHandler.setError()` so it does not need to be called separately

local errorHandler = require("error_handler")

local commands = {}
function commands.executeCommand(command, errorMessage)
	logger.debug("Executing command: " .. command)
	local result = os.execute(command)
	if not result and errorMessage then
		errorHandler.setError(errorMessage)
		return false
	end
	return result
end

return commands
