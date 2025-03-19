--- Menu file utilities
local errorHandler = require("screen.menu.error_handler")

local fileUtils = {}

-- Helper function to escape pattern special characters
function fileUtils.escapePattern(str)
	-- Escape these special characters: ^$()%.[]*+-?
	return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

-- Function to check if file exists
function fileUtils.fileExists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end
	return false
end

-- Function to find next available filename
function fileUtils.getNextAvailableFilename(basePath)
	-- Try without number first
	if not fileUtils.fileExists(basePath) then
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
		if not fileUtils.fileExists(newPath) then
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
function fileUtils.replaceColor(filepath, replacements)
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
		local escapedPlaceholder = fileUtils.escapePattern(placeholder)
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

-- Helper function to create ZIP archive
function fileUtils.createZipArchive(sourceDir, outputPath)
	-- Get next available filename
	local finalPath = fileUtils.getNextAvailableFilename(outputPath)
	if not finalPath then
		errorHandler.setError("Failed to get available filename")
		return false
	end

	-- Use zip command line tool with error capture
	local cmd = string.format('cd "%s" && zip -r "%s" *', sourceDir, finalPath)
	local handle = io.popen(cmd .. " 2>&1")
	if not handle then
		errorHandler.setError("Failed to execute zip command")
		return false
	end

	local result = handle:read("*a")
	if not result then
		handle:close()
		errorHandler.setError("Failed to read command output")
		return false
	end

	local success = handle:close()
	if not success then
		errorHandler.setError("zip command failed: " .. result)
		return false
	end

	return finalPath
end

-- Helper function to copy directory contents
function fileUtils.copyDir(src, dest)
	-- Create destination directory
	os.execute('mkdir -p "' .. dest .. '"')

	-- Copy all contents from source to destination
	local cmd = string.format('cp -r "%s/"* "%s/"', src, dest)
	local success = os.execute(cmd)

	return success == 0 or success == true
end

return fileUtils
