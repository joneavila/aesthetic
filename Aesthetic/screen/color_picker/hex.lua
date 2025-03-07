--- Hex color picker screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")

local hex = {}

-- Store screen switching function
local switchScreen = nil

function hex.load()
	-- Placeholder for now
end

function hex.draw()
	-- Set background
	love.graphics.setColor(colors.bg)
	love.graphics.clear()

	-- Draw placeholder text
	love.graphics.setColor(colors.fg)
	love.graphics.setFont(state.fonts.header)
	love.graphics.printf(
		"TODO",
		0,
		state.screenHeight / 2 - state.fonts.header:getHeight() / 2,
		state.screenWidth,
		"center"
	)

	-- Draw controls
	controls.draw({
		{ icon = "l1.png", text = "Prev. Tab" },
		{ icon = "r1.png", text = "Next Tab" },
		{ icon = "b.png", text = "Back" },
	})
end

function hex.update(_dt)
	if state.canProcessInput() then
		local virtualJoystick = require("input").virtualJoystick

		-- Handle cancel
		if virtualJoystick:isGamepadDown("b") then
			if switchScreen then
				switchScreen("color_picker")
				state.resetInputTimer()
			end
			return
		end
	end
end

function hex.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

return hex
