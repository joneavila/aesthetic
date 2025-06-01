--- Version information
local version = {}

-- Version components
version.major = 1
version.minor = 7
version.patch = 0
version.prerelease = nil -- e.g., "beta.1", can be nil for stable releases

-- Format the version string
function version.getVersionString()
	local versionStr = string.format("v%d.%d.%d", version.major, version.minor, version.patch)
	if version.prerelease then
		versionStr = versionStr .. "-" .. version.prerelease
	end
	return versionStr
end

return version
