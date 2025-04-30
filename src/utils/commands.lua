--- Executes a command and sets an error message if the command fails
--- This function calls `errorHandler.setError()` so it does not need to be called separately

local errorHandler = require("error_handler")
local logger = require("utils.logger")

local commands = {}
function commands.executeCommand(command)
	logger.debug("Executing command: " .. command)
	local result = os.execute(command)
	if not result then
		logger.error("Command failed: " .. command)
		errorHandler.setError("Failed to execute command: " .. command)
		return false
	end
	if result == 0 then
		logger.debug("Command executed successfully, result: " .. tostring(result))
	else
		logger.error("Command returned error: " .. tostring(result))
	end
	return result
end

return commands
