--- Logger module
--- Provides logging functions that write to the LOG_DIR specified in the launch script

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
	local info = debug.getinfo(3, "S")
	if info and info.source then
		-- Remove leading '@' if present
		local source = info.source:gsub("^@", "")
		-- Extract module name from path
		local moduleName = source:match("([^/\\]+)%.lua$") or "unknown"
		return moduleName
	end
	return "unknown"
end

-- Get current timestamp in format YYYY-MM-DD HH:MM:SS
local function getTimestamp()
	return os.date("%Y-%m-%d %H:%M:%S")
end

-- Internal function to write log message
local function writeLog(level, message)
	-- Get the calling module name
	local moduleName = getCallerModule()

	-- Format the log line
	local logLine = string.format("[%s] [%s] [%s] %s", getTimestamp(), level, moduleName, message)

	-- Get log directory from environment variable
	local logDir = os.getenv("LOG_DIR")
	if not logDir or logDir == "" then
		-- Fallback if LOG_DIR is not set
		print("WARNING: LOG_DIR environment variable not set. Logging to stdout only.")
		print(logLine)
		return
	end

	-- Create log filename using current date
	local logFile = logDir .. "/" .. os.date("%Y%m%d") .. ".log"

	-- Append to log file
	local file = io.open(logFile, "a")
	if file then
		file:write(logLine .. "\n")
		file:close()
	else
		print("ERROR: Could not open log file: " .. logFile)
		print(logLine)
	end

	-- Also print to console for debug purposes
	print(logLine)
end

-- Public logging functions
function logger.debug(message)
	writeLog(LOG_LEVELS.DEBUG, message)
end

function logger.info(message)
	writeLog(LOG_LEVELS.INFO, message)
end

function logger.warning(message)
	writeLog(LOG_LEVELS.WARNING, message)
end

function logger.error(message)
	writeLog(LOG_LEVELS.ERROR, message)
end

return logger
