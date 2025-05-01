--- LÖVE configuration file
local love = require("love")

function love.conf(t)
	-- Default dimensions
	local defaultWidth = 640
	local defaultHeight = 480

	-- Check for width and height from environment variables
	local width = os.getenv("WIDTH")
	local height = os.getenv("HEIGHT")

	-- The window dimensions below are set to match most Anbernic devices supported by muOS
	-- (see: https://muos.dev/devices/anbernic).
	-- The UI is fully responsive, so `window.resizable` is set to `true` to allow muOS to resize the window
	-- based on the device's screen dimensions
	t.window.width = tonumber(width) or defaultWidth
	t.window.height = tonumber(height) or defaultHeight
	t.window.minwidth = 640
	t.window.minheight = 480
	t.window.resizable = true

	t.window.borderless = false -- Enable for better screenshots
	t.window.fullscreen = false
	t.window.highdpi = true
	t.window.msaa = 4 -- Enable multi-sample anti-aliasing for better quality (at cost of performance)
	t.window.title = "Aesthetic"
	t.version = "11.5"
	t.accelerometerjoystick = false

	-- Enable gamma correction (when supported) for better color accuracy
	t.gammacorrect = true

	-- Disable unused modules to (slightly) improve performance
	t.modules.mouse = false
	t.modules.touch = false
end
