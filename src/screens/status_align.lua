local love = require("love")
local state = require("state")
local header = require("ui.header")
local button = require("ui.button")
local controls = require("controls")
local background = require("ui.background")
local colors = require("colors")

local status_align = {}

local OPTIONS = {
	"Left",
	"Right",
	"Center",
	"Space Evenly",
	"Equal Distribution",
	"Edge Anchored",
}

local DESCRIPTIONS = {
	"Icons are left aligned.",
	"Icons are right aligned.",
	"Icons are center aligned.",
	"Icons are spaced evenly across the header.",
	"Icons are evenly distributed with equal space around them.",
	"First icon is aligned left, last icon is aligned right, all other icons are evenly distributed.",
}

local selectedIndex = 1

local function getCurrentIndex()
	for i, v in ipairs(OPTIONS) do
		if state.statusAlignment == v then
			return i
		end
	end
	return 1
end

function status_align.onEnter()
	selectedIndex = getCurrentIndex()
end

function status_align.draw()
	background.draw()
	header.draw("Status Alignment")
	local screenWidth = state.screenWidth
	local y = header.getHeight() + 30
	local font = state.fonts.body
	love.graphics.setFont(font)

	-- Draw the button with indicators
	button.drawWithIndicators("Status Alignment", 0, y, true, false, screenWidth, OPTIONS[selectedIndex])

	-- Draw the description below the button
	local desc = DESCRIPTIONS[selectedIndex]
	local descY = y + button.calculateHeight() + 24
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.setFont(font)
	local padding = button.BUTTON.EDGE_MARGIN + 10
	local descX = padding
	local descWidth = screenWidth - padding * 2
	love.graphics.printf(desc, descX, descY, descWidth)

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Change" },
		{ button = "b", text = "Save" },
	})
end

function status_align.update(dt)
	local virtualJoystick = require("input").virtualJoystick
	local changed = false
	if virtualJoystick.isGamepadPressedWithDelay("dpleft") then
		selectedIndex = selectedIndex - 1
		if selectedIndex < 1 then
			selectedIndex = #OPTIONS
		end
		changed = true
	elseif virtualJoystick.isGamepadPressedWithDelay("dpright") then
		selectedIndex = selectedIndex + 1
		if selectedIndex > #OPTIONS then
			selectedIndex = 1
		end
		changed = true
	end
	if changed then
		state.statusAlignment = OPTIONS[selectedIndex]
	end
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		if status_align.switchScreen then
			status_align.switchScreen("main_menu")
		end
	end
end

function status_align.setScreenSwitcher(switchFunc)
	status_align.switchScreen = switchFunc
end

return status_align
