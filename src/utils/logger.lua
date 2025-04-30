--- Logger module
--- Provides logging functions that write to the LOG_DIR specified in the environment

-- Module table
local logger = {}

-- Constants for log levels
local LOG_LEVELS = {
	DEBUG = "DEBUG",
	INFO = "INFO",
	WARNING = "WARNING",
	ERROR = "ERROR",
}

-- Get calling module name from stack traceback
local function getCallerModule()
	local info = debug.getinfo(4, "S")
	local unknownModuleName = "unknown-module"
	if info and info.source then
		-- Remove leading '@' if present
		local source = info.source:gsub("^@", "")
		-- Extract module name from path
		local moduleName = source:match("([^/\\]+)%.lua$") or unknownModuleName
		return moduleName
	end
	return unknownModuleName
end

-- Get current timestamp in format YYYY-MM-DD HH:MM:SS
local function getTimestamp()
	return os.date("%Y-%m-%d %H:%M:%S")
end

-- Internal function to write log message
local function writeLog(level, message)
	local moduleName = getCallerModule()
	local logLine = string.format("[%s] [%s] [%s] %s", getTimestamp(), level, moduleName, message)

	-- Get session log file from environment variable
	local sessionLogFile = os.getenv("SESSION_LOG_FILE")
	local logDir = os.getenv("LOG_DIR")

	if not sessionLogFile or sessionLogFile == "" then
		-- Fallback to LOG_DIR if SESSION_LOG_FILE is not set
		if not logDir or logDir == "" then
			-- Last fallback if neither variable is set
			print("WARNING: SESSION_LOG_FILE and LOG_DIR environment variables not set. Logging to stdout only.")
			print(logLine)
			return
		else
			-- Create session ID if not already set
			local sessionId = os.getenv("SESSION_ID") or os.date("%Y%m%d_%H%M%S")
			sessionLogFile = logDir .. "/" .. sessionId .. ".log"
		end
	end

	-- Append to log file
	local file = io.open(sessionLogFile, "a")
	if file then
		file:write(logLine .. "\n")
		file:close()
	else
		print("ERROR: Could not open log file: " .. sessionLogFile)
		print(logLine)
	end
end

-- Public logging function
-- Each level in the LOG_LEVELS table is a public function in the logger module, e.g. logger.debug
for level, levelStr in pairs(LOG_LEVELS) do
	logger[level:lower()] = function(message)
		writeLog(levelStr, message)
	end
end

return logger
