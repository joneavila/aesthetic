--- Executes a command and sets an error message if the command fails

local logger = require("utils.logger")

local commands = {}
function commands.executeCommand(command)
	-- os.execute is more consistent, less flexible than io.popen
	logger.debug("Executing command: " .. command)
	local result = os.execute(command)
	if result == 0 then
		logger.debug("Command executed successfully, result: " .. tostring(result))
	else
		logger.error("Command returned error code: " .. tostring(result))
	end
	return result
end

return commands
