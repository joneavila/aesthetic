--- Executes a command and sets an error message if the command fails
--- This function calls `errorHandler.setError()` so it does not need to be called separately

local errorHandler = require("error_handler")
local logger = require("utils.logger")

local commands = {}
function commands.executeCommand(command)
	logger.debug("Executing command: " .. command)
	local result = os.execute(command)
	if not result then
		errorHandler.setError("Failed to execute command: " .. command)
		return false
	end
	return result
end

return commands
