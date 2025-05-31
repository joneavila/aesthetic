--- Download Thread for LÖVE
--- This thread handles file downloads without blocking the main UI thread

-- Import the commands utility
local commands = require("utils.commands")

-- Get the communication channels
local errorChannel = love.thread.getChannel("download_error")
local resultChannel = love.thread.getChannel("download_result")
local configChannel = love.thread.getChannel("download_config")

-- Wait for download configuration
local config = configChannel:demand() -- Blocks until config is available

local downloadUrl = config.downloadUrl
local fullPath = config.fullPath

-- Build download command
local downloadCmd
if os.execute("which curl > /dev/null 2>&1") == 0 then
	-- Use curl without progress bar for cleaner output
	downloadCmd =
		string.format('curl -L -s -o "%s" --connect-timeout 30 --max-time 300 --fail "%s"', fullPath, downloadUrl)
else
	-- Fall back to wget without progress
	downloadCmd = string.format('wget -q -O "%s" --timeout=30 --tries=3 "%s"', fullPath, downloadUrl)
end

local result = commands.executeCommand(downloadCmd)

if result ~= 0 then
	-- Handle error based on return code
	local errorDetails
	if result == 6 then -- curl: Couldn't resolve host
		errorDetails = "Network connection failed. Check internet connection."
	elseif result == 7 then -- curl: Failed to connect
		errorDetails = "Failed to connect to server. Check internet connection."
	elseif result == 22 then -- curl: HTTP error (404, etc.)
		errorDetails = "File not found on server. This version may not exist."
	elseif result == 28 then -- curl: Timeout
		errorDetails = "Download timed out. Check internet connection."
	else
		errorDetails = "Download failed with error code: " .. tostring(result)
	end

	errorChannel:push("Download failed:\n" .. errorDetails)
	return
end

-- Verify file exists and has reasonable size
local file = io.open(fullPath, "rb")
if not file then
	errorChannel:push("Download completed but file not found at: " .. fullPath)
	return
end

local fileSize = file:seek("end")
file:close()

if fileSize < 1024 then
	-- File too small, likely an error page
	os.remove(fullPath)
	errorChannel:push(string.format("Downloaded file is too small (%d bytes), likely an error", fileSize))
	return
end

resultChannel:push({
	success = true,
	filePath = fullPath,
	fileSize = fileSize,
})
