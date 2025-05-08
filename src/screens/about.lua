local love = require("love")
local state = require("state")
local colors = require("colors")
local controls = require("controls")
local input = require("input")
local version = require("version")
local background = require("ui.background")
local virtualJoystick = require("input").virtualJoystick

local about = {}

-- Constants
local PADDING = 20
local MENU_SCREEN = "main_menu"
local ABOUT_TEXT_PART1 = "Check out the source code on GitHub!"
local GITHUB_LINK = "https://github.com/joneavila/aesthetic"
local ABOUT_TEXT_PART2 = [[

Made with LÖVE by mxdamp.

Contact:
@mxdamp (muOS community forum)
@joneavila (GitHub)]]

-- Store screen switching function
local switchScreen = nil

function about.load()
	-- Initialize any required resources here
end

function about.draw()
	-- Set background
	background.draw()

	-- Calculate text positions
	local headerHeight = state.fonts.header:getHeight()
	local contentWidth = state.screenWidth - (PADDING * 2)
	local headerY = PADDING
	local bodyY = headerY + headerHeight + PADDING

	-- Calculate text heights for positioning
	local font = state.fonts.body
	local part1Height = font:getHeight()
	local linkHeight = font:getHeight()

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

	-- Draw body text in parts
	love.graphics.setFont(state.fonts.body)

	-- Part 1
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.printf(ABOUT_TEXT_PART1, PADDING, bodyY, contentWidth, "left")

	-- GitHub link with accent color
	love.graphics.setColor(colors.ui.accent)
	love.graphics.printf(GITHUB_LINK, PADDING, bodyY + part1Height, contentWidth, "left")

	-- Part 2
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.printf(ABOUT_TEXT_PART2, PADDING, bodyY + part1Height + linkHeight, contentWidth, "left")

	-- Draw controls
	controls.draw({ {
		button = "b",
		text = "Back",
	} })
end

function about.update(_dt)
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		if switchScreen then
			switchScreen(MENU_SCREEN)
		end
	end
end

function about.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

return about
