--- Theme packaging utilities
-- Handles archiving, name file creation, and cleanup for theme creation
local system = require("utils.system")
local logger = require("utils.logger")

local themePackager = {}

-- Create the theme archive (muxthm file)
-- @param workingDir (string): Directory to archive
-- @param outputPath (string): Output archive path (should end with .muxthm)
-- @return (string|false): Final archive path or false on error
function themePackager.createThemeArchive(workingDir, outputPath)
	local finalPath = system.createArchive(workingDir, outputPath)
	if not finalPath then
		return false
	end
	return finalPath
end

-- Create name.txt with the theme's name (derived from archive path)
-- @param finalArchivePath (string): Path to the final archive
-- @param nameFilePath (string): Path to write name.txt
-- @return (boolean): Success
function themePackager.createNameFile(finalArchivePath, nameFilePath)
	local name = finalArchivePath:match("([^/]+)%.muxthm$") or finalArchivePath
	logger.debug(string.format("Creating theme name file with name '%s'", name))
	return system.createTextFile(nameFilePath, name)
end

return themePackager
