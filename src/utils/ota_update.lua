--- OTA Update utility
--- Handles checking for and downloading GitHub .muxupd/.muxzip releases
local logger = require("utils.logger")
local errorHandler = require("error_handler")
local commands = require("utils.commands")
local system = require("utils.system")
local version = require("version")
local json = require("json_lua.json")

local otaUpdate = {}

-- GitHub repository information
local GITHUB_API_URL = "https://api.github.com/repos/joneavila/aesthetic/releases/latest"

-- Function to get archive path based on environment (development vs production)
local function getArchivePath()
	local devDir = os.getenv("DEV_DIR")
	if devDir then
		-- Development environment - use local dev directory
		local archivePath = devDir .. "/ARCHIVE"
		return archivePath
	else
		-- Production environment - use absolute path to actual handheld location
		return "/mnt/mmc/ARCHIVE"
	end
end

--- Parse version string into components for comparison
--- @param versionStr string Version string like "v1.6.0"
--- @return table Version components {major, minor, patch}
local function parseVersion(versionStr)
	local cleanVersion = versionStr:gsub("^v", "") -- Remove 'v' prefix if present
	local major, minor, patch = cleanVersion:match("(%d+)%.(%d+)%.(%d+)")
	if not major or not minor or not patch then
		return nil
	end
	return {
		major = tonumber(major),
		minor = tonumber(minor),
		patch = tonumber(patch),
	}
end

--- Compare two version objects
--- @param current table Current version components
--- @param latest table Latest version components
--- @return boolean True if latest is newer than current
local function isNewerVersion(current, latest)
	if latest.major > current.major then
		return true
	elseif latest.major < current.major then
		return false
	end

	if latest.minor > current.minor then
		return true
	elseif latest.minor < current.minor then
		return false
	end

	return latest.patch > current.patch
end

--- Check for updates and return version information
--- @return table|nil Result containing {hasUpdate, currentVersion, latestVersion, downloadUrl, error}
function otaUpdate.checkForUpdates()
	-- Get current version
	local currentVersionStr = version.getVersionString()
	local currentVersion = parseVersion(currentVersionStr)

	if not currentVersion then
		local error = "Failed to parse current version: " .. currentVersionStr
		logger.error(error)
		return { error = error }
	end

	-- Create temporary file for API response
	local tempFile = "/tmp/github_release_" .. os.time() .. ".json"

	-- Use curl or wget to fetch latest release info (curl is available on macOS)
	local downloadCmd
	if os.execute("which curl > /dev/null 2>&1") == 0 then
		-- Use curl (available on macOS and most Linux systems)
		downloadCmd = string.format('curl -s -o "%s" --connect-timeout 10 --max-time 10 "%s"', tempFile, GITHUB_API_URL)
	else
		-- Fall back to wget
		downloadCmd = string.format('wget -q -O "%s" --timeout=10 --tries=1 "%s"', tempFile, GITHUB_API_URL)
	end

	local result = commands.executeCommand(downloadCmd)

	if result ~= 0 then
		local error = "Failed to fetch release information from GitHub"
		logger.error(error)
		-- Clean up temp file
		system.removeFile(tempFile)
		return { error = error }
	end

	-- Read the JSON response
	local file = io.open(tempFile, "r")
	if not file then
		local error = "Failed to read GitHub API response"
		logger.error(error)
		system.removeFile(tempFile)
		return { error = error }
	end

	local jsonContent = file:read("*all")
	file:close()
	system.removeFile(tempFile)

	if not jsonContent or jsonContent == "" then
		local error = "Empty response from GitHub API"
		logger.error(error)
		return { error = error }
	end

	-- Parse JSON using json.lua library
	local releaseData
	local success, result = pcall(json.decode, jsonContent)
	if not success then
		local error = "Failed to parse GitHub API response as JSON: " .. tostring(result)
		logger.error(error)
		return { error = error }
	end
	releaseData = result

	-- Extract tag name
	local tagName = releaseData.tag_name
	if not tagName then
		local error = "Missing tag_name in GitHub release response"
		logger.error(error)
		return { error = error }
	end

	-- Look for the specific Aesthetic_v{version}.muxupd or Aesthetic_v{version}.muxzip file pattern
	local expectedAssetNameMuxupd = "Aesthetic_" .. tagName .. ".muxupd"
	local expectedAssetNameMuxzip = "Aesthetic_" .. tagName .. ".muxzip"

	local downloadUrl = nil
	local assetName = nil

	if releaseData.assets and type(releaseData.assets) == "table" then
		for _, asset in ipairs(releaseData.assets) do
			if
				asset.name
				and asset.browser_download_url
				and (asset.name == expectedAssetNameMuxupd or asset.name == expectedAssetNameMuxzip)
			then
				downloadUrl = asset.browser_download_url
				assetName = asset.name
				break
			end
		end
	end

	-- Return error if neither .muxupd nor .muxzip file is found
	if not downloadUrl then
		local error = "Required update file not found. Expected: "
			.. expectedAssetNameMuxupd
			.. " or "
			.. expectedAssetNameMuxzip
		logger.error(error)
		return { error = error }
	end

	local latestVersion = parseVersion(tagName)
	if not latestVersion then
		local error = "Failed to parse latest version: " .. tagName
		logger.error(error)
		return { error = error }
	end

	local hasUpdate = isNewerVersion(currentVersion, latestVersion)

	return {
		hasUpdate = hasUpdate,
		currentVersion = currentVersionStr,
		latestVersion = tagName,
		downloadUrl = downloadUrl,
		assetName = assetName,
		error = nil,
	}
end

--- Start a threaded download of the latest release .muxupd/.muxzip file
--- @param downloadUrl string URL to download from
--- @param assetName string Optional asset name for the downloaded file (.muxupd/.muxzip)
--- @return boolean Success status, string Error message or thread object
function otaUpdate.startThreadedDownload(downloadUrl, assetName)
	local love = require("love")

	-- Get the appropriate archive path for current environment
	local ARCHIVE_PATH = getArchivePath()

	-- Ensure archive directory exists using system utilities
	if not system.ensurePath(ARCHIVE_PATH .. "/") then -- Add trailing slash to ensure it's treated as directory
		local error = "Failed to create archive directory: " .. ARCHIVE_PATH
		logger.error(error)
		return false, error
	end

	-- Use provided asset name or generate filename based on timestamp
	local filename
	if assetName and assetName ~= "" then
		filename = assetName
	else
		local timestamp = os.date("%Y%m%d_%H%M%S")
		-- Default to .muxupd extension
		filename = "Aesthetic_update_" .. timestamp .. ".muxupd"
	end

	local fullPath = ARCHIVE_PATH .. "/" .. filename

	-- Create communication channels
	local errorChannel = love.thread.getChannel("download_error")
	local resultChannel = love.thread.getChannel("download_result")
	local configChannel = love.thread.getChannel("download_config")

	-- Clear any previous data from channels
	errorChannel:clear()
	resultChannel:clear()
	configChannel:clear()

	-- Create and start the download thread
	local downloadThread = love.thread.newThread("utils/download_thread.lua")

	-- Send configuration to the thread
	configChannel:push({
		downloadUrl = downloadUrl,
		fullPath = fullPath,
	})

	-- Start the thread
	downloadThread:start()

	return true, downloadThread
end

--- Check for download errors from thread
--- @return string|nil Error message or nil
function otaUpdate.getDownloadError()
	local love = require("love")
	local errorChannel = love.thread.getChannel("download_error")
	return errorChannel:pop() -- Non-blocking, returns nil if no data
end

--- Check if download is complete and get result
--- @return table|nil Result {success, filePath, fileSize} or nil
function otaUpdate.getDownloadResult()
	local love = require("love")
	local resultChannel = love.thread.getChannel("download_result")
	return resultChannel:pop() -- Non-blocking, returns nil if no data
end

return otaUpdate
