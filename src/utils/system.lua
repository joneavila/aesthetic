--- System utilities
--- This module avoids using `love.filesystem` since most functions are not sandboxed
local errorHandler = require("error_handler")
local commands = require("utils.commands")
local logger = require("utils.logger")
local environment = require("utils.environment")
local system = {}
local fail = require("utils.fail")

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

-- Helper function to create archive with no compression (faster, larger file)
-- @param sourceDir (string): Directory to archive
-- @param outputPath (string): Output archive path (should end with .muxthm)
function system.createArchive(sourceDir, outputPath)
	local finalPath = system.getNextAvailableFilename(outputPath)
	if not finalPath then
		errorHandler.setError("Failed to get available filename")
		return false
	end
	logger.debug(string.format("Using archive path '%s'", finalPath))
	local zipFlags = "-qr0" -- quiet, recursive, no compression
	local cmd = string.format('cd "%s" && zip %s "%s" . -x "*.DS_Store"', sourceDir, zipFlags, finalPath)
	local result = commands.executeCommand(cmd)
	if result ~= 0 then
		errorHandler.setError("Archive creation failed: " .. tostring(result))
		return false
	end
	return finalPath
end

-- Helper function to copy directory contents
function system.copyDir(src, dest)
	if not src:match("/$") then
		src = src .. "/"
	end

	if not system.ensurePath(dest) then
		return fail("Failed to create destination directory: " .. dest)
	end

	local checkCmd = string.format('test -d "%s"', src:sub(1, -2))
	if commands.executeCommand(checkCmd) ~= 0 then
		return fail("Source directory does not exist: " .. src)
	end

	local rsyncCmd
	local osType = environment.getOS()

	if osType == "macos" then
		rsincCmd = string.format('rsync -aq "%s" "%s"', src, dest)
	else
		rsincCmd = string.format('rsync -a -W -z0 --info=none "%s" "%s"', src, dest)
	end

	if commands.executeCommand(rsincCmd) ~= 0 then
		return fail("rsync command failed: " .. rsincCmd)
	end

	return true
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
	if not system.fileExists(sourcePath) then
		return fail("Source file does not exist: " .. sourcePath)
	end

	if not system.ensurePath(destinationPath) then
		return fail("Failed to create destination directory: " .. destinationPath)
	end

	local cmd = string.format('cp "%s" "%s"', sourcePath, destinationPath)
	if commands.executeCommand(cmd) ~= 0 then
		return fail("cp command failed: " .. cmd)
	end

	return true
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
		return fail("Environment variable not found: " .. name)
	end
	logger.info(string.format("Environment variable [%s] = '%s'", name, value))
	return value
end

-- Remove a directory and all its contents recursively
function system.removeDir(dir)
	if not dir then
		return fail("No directory path provided to removeDir")
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
		return fail("Failed to create directory for file: " .. filePath)
	end

	local file, err = io.open(filePath, "wb")
	if not file then
		return fail("Failed to open file for writing (" .. filePath .. "): " .. err)
	end

	local success = file:write(content)
	file:close()

	if not success then
		return fail("Failed to write content to file: " .. filePath)
	end

	return true
end

-- Check if RGB lighting is supported on the current device
-- by reading the RGB setting from the device config file
function system.hasRGBSupport()
	-- New CFW: /opt/muos/device/config (no extension, contains '0' or '1')
	local newConfigPath = "/opt/muos/device/config/led/rgb"
	local file = io.open(newConfigPath, "r")
	if file then
		local content = file:read("*all")
		file:close()
		if content then
			content = content:match("^%s*(.-)%s*$") -- trim whitespace
			if content == "1" then
				logger.debug("RGB supported (new config, value=1)")
				return true
			elseif content == "0" then
				logger.debug("RGB not supported (new config, value=0)")
				return false
			else
				logger.warning("Unknown value in new RGB config: " .. tostring(content))
				return false
			end
		end
	end

	-- Old CFW: /opt/muos/device/current/config.ini ([led] section, rgb=1)
	local oldConfigPath = "/opt/muos/device/current/config.ini"
	file = io.open(oldConfigPath, "r")
	if file then
		local content = file:read("*all")
		file:close()
		if content then
			-- Find the [led] section and check for rgb=1
			local inLedSection = false
			for line in content:gmatch("([^\n]*)\n?") do
				local section = line:match("^%[(.+)%]$")
				if section then
					inLedSection = (section == "led")
				elseif inLedSection then
					local key, value = line:match("^%s*([%w_]+)%s*=%s*(%d+)%s*$")
					if key == "rgb" then
						logger.debug("Found RGB setting in old config: " .. value)
						return value == "1"
					end
				end
			end
		end
	end

	-- If neither config found, default to false (no RGB support)
	logger.debug("No RGB config found, defaulting to not supported")
	return false
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
		return fail("No file path provided to removeFile")
	end
	if not system.isFile(path) then
		logger.warning("File does not exist for removal: " .. path)
		return true -- Nothing to remove
	end
	local ok, err = os.remove(path)
	if not ok then
		return fail("Failed to remove file: " .. tostring(err))
	end
	return true
end

-- Function to get the system version (GOOSE or PIXIE)
function system.getSystemVersion()
	local paths = require("paths")
	local versionFile = paths.MUOS_VERSION_FILE
	if not versionFile or not system.fileExists(versionFile) then
		return fail("MUOS version file not found")
	end
	local content = system.readFile(versionFile)
	if not content then
		return fail("Failed to read MUOS version file")
	end
	local variant = content:match("_(%u+)")
	if not variant then
		return fail("Failed to parse system version from MUOS version file")
	end
	return variant
end

return system
