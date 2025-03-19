--- Version information
local version = {}

-- Version components
version.major = 1
version.minor = 3
version.patch = 0

-- Format the version string
function version.getVersionString()
	return string.format("v%d.%d.%d", version.major, version.minor, version.patch)
end

return version
