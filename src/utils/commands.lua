--- Executes a command and sets an error message if the command fails

local errorHandler = require("error_handler")
local logger = require("utils.logger")

local commands = {}
function commands.executeCommand(command)
	logger.debug("Executing command: " .. command)

	-- Use popen to capture command output
	local handle = io.popen(command .. " 2>&1")
	if not handle then
		logger.error("Failed to execute command: " .. command)
		errorHandler.setError("Failed to execute command: " .. command)
		return false
	end

	local output = handle:read("*a")
	local _, result, code = handle:close()

	if not result then
		logger.error("Command failed: " .. command)
		errorHandler.setError("Failed to execute command: " .. command)
		return false
	end

	if code == 0 then
		logger.debug("Command executed successfully, result: " .. tostring(code))
	else
		logger.error("Command returned error code: " .. tostring(code))
		logger.error("Command output: " .. output)
	end

	return code
end

return commands
