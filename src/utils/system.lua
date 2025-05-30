--- System utilities
--- This module avoids using `love.filesystem` since most functions are not sandboxed
local errorHandler = require("error_handler")
local commands = require("utils.commands")
local logger = require("utils.logger")
local environment = require("utils.environment")
local system = {}

-- Helper function to escape pattern special characters
function system.escapePattern(str)
	-- Escape these special characters: ^$()%.[]*+-?
	return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

-- Function to check if file exists
function system.fileExists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end
	logger.warning("File does not exist: " .. path)
	errorHandler.setError("File does not exist: " .. path)
	return false
end

-- Function to find next available filename
function system.getNextAvailableFilename(basePath)
	-- Check file existence without setting error
	local function checkFileExists(path)
		local file = io.open(path, "r")
		if file then
			file:close()
			return true
		end
		return false
	end

	-- Try without number first
	if not checkFileExists(basePath) then
		return basePath
	end

	-- Extract the extension from the original path
	local baseName, extension = basePath:match("(.+)(%.[^%.]+)$")
	if not baseName then
		baseName = basePath
		extension = ""
	end

	local i = 1
	while true do
		local newPath = string.format("%s (%d)%s", baseName, i, extension)
		if not checkFileExists(newPath) then
			return newPath
		end
		i = i + 1
		local maxAttempts = 100
		if i > maxAttempts then
			errorHandler.setError("Failed to find available filename after " .. maxAttempts .. " attempts")
			return nil
		end
	end
end

-- Helper function to replace color in file (text replacement)
function system.replaceColor(filepath, replacements)
	local file = io.open(filepath, "r")
	if not file then
		errorHandler.setError("Cannot read theme file: " .. filepath)
		return false
	end

	local content = file:read("*all")
	if not content then
		file:close()
		errorHandler.setError("Failed to read content from: " .. filepath .. "\nFile may be empty or corrupted")
		return false
	end
	file:close()

	-- Replace each color placeholder
	local newContent = content
	local totalReplacements = 0

	for placeholder, hexColor in pairs(replacements) do
		local escapedPlaceholder = system.escapePattern(placeholder)
		local pattern = "%%{" .. escapedPlaceholder .. "}"
		local count
		newContent, count = string.gsub(newContent, pattern, hexColor)
		totalReplacements = totalReplacements + count
	end

	-- Write updated content
	file = io.open(filepath, "w")
	if not file then
		errorHandler.setError("Cannot write to theme file: " .. filepath)
		return false
	end

	local success = file:write(newContent)
	file:close()

	if not success then
		errorHandler.setError("Failed to write updated content to: " .. filepath)
		return false
	end

	return true
end

-- Helper function to create archive
function system.createArchive(sourceDir, outputPath)
	logger.debug("Creating archive from " .. sourceDir .. " to " .. outputPath)

	-- Get next available filename
	local finalPath = system.getNextAvailableFilename(outputPath)
	if not finalPath then
		logger.error("Failed to get available filename for archive")
		errorHandler.setError("Failed to get available filename")
		return false
	end

	logger.debug("Using archive path: " .. finalPath)

	-- Note: 7zip would be nice here but the system does not support the -tzip option
	-- Naming the file .zip and renaming to .muxthm will not work
	local cmd = string.format('cd "%s" && zip -r "%s" * -x "*.DS_Store"', sourceDir, finalPath)
	logger.debug("Archive command: " .. cmd)

	-- Execute command and capture output
	local handle = io.popen(cmd .. " 2>&1")
	if not handle then
		logger.error("Failed to execute archive command")
		errorHandler.setError("Failed to execute archive command")
		return false
	end

	local result = handle:read("*a")
	local success = handle:close()

	if not success then
		logger.error("Archive creation failed: " .. result)
		errorHandler.setError("Archive creation failed: " .. result)
		return false
	end

	logger.debug("Created archive using zip at " .. finalPath)

	-- Execute sync to ensure filesystem catches up
	commands.executeCommand("sync")

	return finalPath
end

-- Helper function to copy directory contents
function system.copyDir(src, dest)
	-- Ensure source ends with a slash to copy contents rather than the directory itself
	if not src:match("/$") then
		src = src .. "/"
	end

	if not system.ensurePath(dest) then
		errorHandler.setError("Failed to create destination directory: " .. dest)
		return false
	end

	-- Check if source directory exists
	local checkCmd = string.format('test -d "%s"', src:sub(1, -2))
	if commands.executeCommand(checkCmd) ~= 0 then
		errorHandler.setError("Source directory does not exist: " .. src)
		return false
	end

	-- Determine which rsync command to use based on OS
	local rsyncCmd
	local osType = environment.getOS()

	if osType == "macos" then
		-- macOS compatible command (older rsync)
		-- -a: archive mode (preserves permissions, etc.)
		-- -q: quiet mode (suppresses non-error messages)
		rsyncCmd = string.format('rsync -aq "%s" "%s"', src, dest)
	else
		-- Linux or other (assumes newer rsync with more options)
		-- -a: archive mode (preserves permissions, etc.)
		-- --no-whole-file: use delta-transfer algorithm (faster for existing files)
		-- -W: For new files, whole files are sent without using delta algorithm (faster for new files)
		-- -z0: disable compression (more CPU efficient)
		-- --info=none: disable progress information (reduces overhead)
		rsyncCmd = string.format('rsync -a -W -z0 --info=none "%s" "%s"', src, dest)
	end

	return commands.executeCommand(rsyncCmd) == 0
end

--- Ensures a directory exists, creating it if necessary
--- If path points to a file, creates the parent directory
--- If path points to a directory, creates that directory
function system.ensurePath(path)
	if not path then
		logger.error("No path provided to ensurePath")
		errorHandler.setError("No path provided to ensurePath")
		return false
	end

	-- If path ends with a slash, treat as directory path
	-- Otherwise, extract parent directory from potential file path
	local dir
	if path:match("/$") then
		dir = path:sub(1, -2) -- Remove trailing slash
	else
		dir = path:match("(.+)/[^/]+$") or path
	end

	local result = os.execute('mkdir -p "' .. dir .. '"')
	if not result then
		logger.error("Failed to create directory (" .. dir .. "): " .. tostring(result))
		errorHandler.setError("Failed to create directory (" .. dir .. "): " .. tostring(result))
		return false
	end
	return true
end

-- Copy a file and create destination directory if needed
function system.copyFile(sourcePath, destinationPath)
	-- Check if source file exists
	if not system.fileExists(sourcePath) then
		errorHandler.setError("Source file does not exist: " .. sourcePath)
		return false
	end

	-- Ensure destination directory exists
	if not system.ensurePath(destinationPath) then
		errorHandler.setError("Failed to create destination directory: " .. destinationPath)
		return false
	end

	-- Use direct copy (faster for small files)
	-- Note: For larger files, rsync would be more efficient with:
	-- rsync -a -W --no-compress sourcePath destinationPath
	local cmd = string.format('cp "%s" "%s"', sourcePath, destinationPath)

	return commands.executeCommand(cmd)
end

-- Function to check if a path is a directory using `test -d`
function system.isDir(path)
	if not path then
		return false
	end
	local cmd = string.format('test -d "%s"', path)
	-- Use os.execute instead of commands.executeCommand to avoid printing
	local result = os.execute(cmd)
	return result == 0
end

-- Get environment variable, setting error if not found
function system.getEnvironmentVariable(name)
	local value = os.getenv(name)
	if value == nil then
		logger.error("Environment variable not found: " .. name)
		errorHandler.setError("Environment variable not found: " .. name)
		return nil
	end
	logger.debug(string.format("Environment variable '%s' has value '%s'", name, value))
	return value
end

-- Remove a directory and all its contents recursively
function system.removeDir(dir)
	if not dir then
		errorHandler.setError("No directory path provided to removeDir")
		return false
	end

	-- Check if directory exists before attempting removal
	local checkCmd = string.format('test -d "%s"', dir)
	if commands.executeCommand(checkCmd) ~= 0 then
		logger.warning("Directory does not exist for removal: " .. dir)
		return true -- Return true since there's nothing to remove
	end

	return commands.executeCommand('rm -rf "' .. dir .. '"')
end

-- Create a simple text file with the given content
function system.createTextFile(filePath, content)
	local file = io.open(filePath, "w")
	if not file then
		errorHandler.setError("Failed to create file: " .. filePath)
		return false
	end
	file:write(content)
	file:close()
	return true
end

-- Modify a file using a function that processes its content
-- modifierFunc receives the file content and should return (modifiedContent, success)
function system.modifyFile(filePath, modifierFunc)
	-- Read the file content
	local file, err = io.open(filePath, "r")
	if not file then
		errorHandler.setError("Failed to open file (" .. filePath .. "): " .. err)
		return false
	end

	local fileContent = file:read("*all")
	file:close()

	-- Modify the content using the provided function
	local modifiedContent, success = modifierFunc(fileContent)
	if not success then
		return false
	end

	-- Write the updated content back to the file
	file, err = io.open(filePath, "w")
	if not file then
		errorHandler.setError("Failed to write to file (" .. filePath .. "): " .. err)
		return false
	end

	file:write(modifiedContent)
	file:close()
	return true
end

-- Read the entire content of a file
function system.readFile(filePath)
	-- Check if file exists to provide better error message
	if not system.fileExists(filePath) then
		errorHandler.setError("File does not exist for reading: " .. filePath)
		return nil
	end

	-- Standard file reading
	-- Note: For larger files (>10MB), memory mapping with dd would be more efficient:
	-- dd if=filePath bs=4M
	local file, err = io.open(filePath, "r")
	if not file then
		errorHandler.setError("Failed to open file for reading (" .. filePath .. "): " .. err)
		return nil
	end

	local content = file:read("*all")
	file:close()

	if not content then
		errorHandler.setError("Failed to read content from file: " .. filePath)
		return nil
	end

	return content
end

-- Write content to a file, creating directories if needed
function system.writeFile(filePath, content)
	-- Ensure the directory exists
	if not system.ensurePath(filePath) then
		return false
	end

	local file, err = io.open(filePath, "wb")
	if not file then
		errorHandler.setError("Failed to open file for writing (" .. filePath .. "): " .. err)
		return false
	end

	local success = file:write(content)
	file:close()

	if not success then
		errorHandler.setError("Failed to write content to file: " .. filePath)
		return false
	end

	return true
end

-- Check if RGB lighting is supported on the current device
-- by reading the RGB setting from the device config file
function system.hasRGBSupport()
	local configPath = "/opt/muos/device/current/config.ini"
	local file = io.open(configPath, "r")

	-- Default to true if we can't read the config file, to preserve existing behavior
	if not file then
		logger.warning("Could not read device config file: " .. configPath)
		return true
	end

	local content = file:read("*all")
	file:close()

	-- Find the [led] section and check for rgb=1
	local inLedSection = false
	for line in content:gmatch("([^\n]*)\n?") do
		-- Check for section header
		local section = line:match("^%[(.+)%]$")
		if section then
			inLedSection = (section == "led")
		elseif inLedSection then
			-- Look for rgb setting in [led] section
			local key, value = line:match("^%s*([%w_]+)%s*=%s*(%d+)%s*$")
			if key == "rgb" then
				logger.debug("Found RGB setting in device config: " .. value)
				return value == "1"
			end
		end
	end

	-- Default to true if setting not found, to maintain compatibility
	logger.debug("RGB setting not found in config file, defaulting to enabled")
	return true
end

-- List files in a directory matching a pattern (returns table of filenames, not full paths)
function system.listFiles(dir, pattern)
	if not dir or not pattern then
		errorHandler.setError("Directory and pattern required for listFiles")
		return {}
	end
	local cmd = string.format('ls "%s"/%s 2>/dev/null', dir, pattern)
	local handle = io.popen(cmd)
	if not handle then
		errorHandler.setError("Failed to list files in directory: " .. dir)
		return {}
	end
	local result = handle:read("*a")
	handle:close()
	local files = {}
	for filename in string.gmatch(result, "[^\n]+") do
		local name = filename:match("([^/]+)$")
		if name then
			table.insert(files, name)
		end
	end
	return files
end

-- Read the system version from the MUOS version file
function system.getSystemVersion()
	local paths = require("paths")
	local versionFilePath = paths.MUOS_VERSION
	local versionFileContent = system.readFile(versionFilePath)
	if versionFileContent == nil then
		logger.error("Failed to read system version from " .. versionFilePath)
		return "Unknown"
	end
	-- Replace all newlines with spaces, trim leading/trailing whitespace, and replace spaces with underscores
	local versionString = versionFileContent:gsub("[\r\n]+", " "):gsub("^%s*(.-)%s*$", "%1"):gsub(" ", "_")
	logger.debug(string.format("Read version '%s'", versionString))
	return versionString
end

-- Returns the normalized base system version (e.g., '2502.0_PIXIE_54c85a0f' -> '2502.0_PIXIE')
function system.getNormalizedSystemVersion()
	local versionString = system.getSystemVersion()
	if not versionString or versionString == "" then
		return versionString
	end
	local base = versionString:match("^(%d+%.%d+_%u+)")
	if base then
		return base
	end
	base = versionString:match("^(%d+%.%d+_%a+)")
	if base then
		return base
	end
	return versionString
end

-- Function to list contents of a directory
function system.listDir(dir)
	if not dir then
		errorHandler.setError("No directory path provided to listDir")
		return nil
	end

	-- Check if directory exists before listing
	local checkCmd = string.format('test -d "%s"', dir)
	if commands.executeCommand(checkCmd) ~= 0 then
		logger.warning("Directory does not exist for listing: " .. dir)
		-- Return an empty table if the directory doesn't exist (graceful handling)
		return {}
	end

	-- Use ls -a1 to list all entries (including hidden) one per line
	local cmd = string.format('ls -a1 "%s"', dir)
	local handle = io.popen(cmd .. " 2>&1")
	if not handle then
		logger.error("Failed to execute list directory command")
		errorHandler.setError("Failed to execute list directory command")
		return nil
	end

	local result = handle:read("*a")
	local success = handle:close()

	if not success then
		logger.error("List directory command failed: " .. result)
		errorHandler.setError("List directory command failed: " .. result)
		return nil
	end

	local items = {}
	-- Split output into lines and add to table, excluding '.' and '..'
	for item in result:gmatch("[^\n]+") do
		if item ~= "." and item ~= ".." then
			table.insert(items, item)
		end
	end

	return items
end

-- Function to check if a path is a file using `test -f`
function system.isFile(path)
	if not path then
		return false
	end
	local cmd = string.format('test -f "%s"', path)
	-- Use os.execute instead of commands.executeCommand to avoid printing
	local result = os.execute(cmd)
	return result == 0
end

-- Remove a file at the given path
function system.removeFile(path)
	if not path then
		errorHandler.setError("No file path provided to removeFile")
		return false
	end
	if not system.isFile(path) then
		logger.warning("File does not exist for removal: " .. path)
		return true -- Nothing to remove
	end
	local ok, err = os.remove(path)
	if not ok then
		logger.error("Failed to remove file: " .. tostring(err))
		errorHandler.setError("Failed to remove file: " .. tostring(err))
		return false
	end
	return true
end

return system
