--- LÖVE configuration file
local love = require("love")

function love.conf(t)
	t.window.width = tonumber(os.getenv("WIDTH"))
	t.window.height = tonumber(os.getenv("HEIGHT"))
	t.window.resizable = false
	t.window.msaa = 4 -- Enable multi-sample anti-aliasing for better quality (at cost of performance)
	t.window.title = "Aesthetic"
	t.version = "11.5"
	t.accelerometerjoystick = false
	t.window.fullscreen = true
	t.gammacorrect = true -- Enable gamma correction (when supported) for better color accuracy
	-- "Setting unused modules to false is encouraged when you release your game. It reduces startup time slightly
	-- (especially if the joystick module is disabled) and reduces memory usage (slightly)."
	-- https://www.love2d.org/wiki/Config_Files
	t.modules.mouse = false
	t.modules.physics = false
	t.modules.touch = false
	t.modules.video = false
end
