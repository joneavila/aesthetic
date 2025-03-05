--- LÖVE configuration file: https://www.love2d.org/wiki/Config_Files
local love = require("love")
function love.conf(t)
	-- These dimensions match most muOS Ambernic supported devices: https://muos.dev/devices/anbernic
	-- Enabling window resizing allows support for other resolutions
	t.window.width = 640
	t.window.height = 480
	t.window.resizable = true
	t.window.title = "Aesthetic"
	-- t.window.borderless = true -- Useful for screenshots
end
