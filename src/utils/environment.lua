--- Environment detection utilities
local logger = require("utils.logger")

local environment = {}

-- Function to get the current operating system
function environment.getOS()
	local osType = io.popen("uname -s"):read("*l")
	if osType == "Darwin" then
		return "macos"
	elseif osType == "Linux" then
		return "linux"
	else
		-- Default to a safe option if we can't detect
		logger.warning("Unknown OS detected: " .. tostring(osType) .. ", defaulting to Linux")
		return "unknown"
	end
end

-- Function to check if running on a muOS device
function environment.ismuOSDevice()
	-- Check for muOS version file
	local versionFile = io.open("/opt/muos/config/version.txt", "r")
	if versionFile then
		versionFile:close()
		return true
	end
	return false
end

-- A more robust method would be to check if the device has a muOS version file,
-- this would allow for Linux development machines to be detected properly since
-- just checking for Linux is not enough to distinguish between a development machine
-- and an actual handheld device running muOS.

return environment
