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
	CRITICAL = "CRITICAL", -- Added additional level for critical errors
}

-- Enable console logging (set to true for development)
local CONSOLE_LOGGING = true

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

-- Get current timestamp in format YYYY-MM-DD HH:MM:SS.MMM
local function getTimestamp()
	-- Standard timestamp
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")

	-- Add milliseconds if possible
	local clock = os.clock()
	local ms = math.floor((clock % 1) * 1000)
	return timestamp .. "." .. string.format("%03d", ms)
end

-- Internal function to write log message
local function writeLog(level, message)
	local moduleName = getCallerModule()
	local logLine = string.format("[%s] [%s] [%s] %s", getTimestamp(), level, moduleName, message)

	-- Get session log file from environment variable
	local sessionLogFile = os.getenv("SESSION_LOG_FILE")
	local logDir = os.getenv("LOG_DIR")

	-- Always print to console in development mode
	if CONSOLE_LOGGING or level == LOG_LEVELS.ERROR or level == LOG_LEVELS.CRITICAL then
		print(logLine)
	end

	if not sessionLogFile or sessionLogFile == "" then
		-- Fallback to LOG_DIR if SESSION_LOG_FILE is not set
		if not logDir or logDir == "" then
			-- Last fallback if neither variable is set
			print("WARNING: SESSION_LOG_FILE and LOG_DIR environment variables not set. Logging to stdout only.")
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
	end
end

-- Public logging function
-- Each level in the LOG_LEVELS table is a public function in the logger module, e.g. logger.debug
for level, levelStr in pairs(LOG_LEVELS) do
	logger[level:lower()] = function(message)
		writeLog(levelStr, message)
	end
end

-- Log that the logger module has been initialized
writeLog(LOG_LEVELS.DEBUG, "Logger module initialized")

return logger
