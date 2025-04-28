--- LÖVE configuration file
local love = require("love")

function love.conf(t)
	-- The window dimensions below are set to match most Anbernic devices supported by muOS
	-- (see: https://muos.dev/devices/anbernic).
	-- The UI is fully responsive, so `window.resizable` to `true` will allow muOS to resize the window as needed.
	t.window.width = 640
	t.window.height = 480
	t.window.resizable = true
	t.window.fullscreen = false
	t.window.title = "Aesthetic"
	t.window.borderless = true
	t.gammacorrect = true
end
