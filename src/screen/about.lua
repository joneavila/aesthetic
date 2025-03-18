local love = require("love")
local state = require("state")
local colors = require("colors")
local controls = require("controls")
local input = require("input")
local version = require("version")

local about = {}

-- Constants
local PADDING = 20
local MENU_SCREEN = "menu"
local ABOUT_TEXT = [[
Check out the source code on GitHub!
https://github.com/joneavila/aesthetic
Made with LÖVE by @joneavila]]

-- Store screen switching function
local switchScreen = nil

function about.load()
	-- Initialize any required resources here
end

function about.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	-- Calculate text positions
	local headerHeight = state.fonts.header:getHeight()
	local contentWidth = state.screenWidth - (PADDING * 2)
	local headerY = PADDING
	local bodyY = headerY + headerHeight + PADDING

	-- Draw header
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(state.fonts.header)
	love.graphics.printf(
		state.applicationName .. " " .. version.getVersionString(),
		PADDING,
		headerY,
		contentWidth,
		"center"
	)

	-- Draw body text
	love.graphics.setFont(state.fonts.body)
	love.graphics.printf(ABOUT_TEXT, PADDING, bodyY, contentWidth, "left")

	-- Draw controls
	controls.draw({ {
		icon = "b.png",
		text = "back",
	} })
end

function about.update(_dt)
	if state.canProcessInput() and input.virtualJoystick:isGamepadDown("b") then
		if switchScreen then
			switchScreen(MENU_SCREEN)
			state.resetInputTimer()
		end
	end
end

function about.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

return about
