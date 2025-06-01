local love = require("love")
local state = require("state")
local header = require("ui.header")
local button = require("ui.button")
local controls = require("controls")
local background = require("ui.background")
local colors = require("colors")
local list = require("ui.list")
local screens = require("screens")
local fonts = require("ui.fonts")

local status_alignment = {}

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

-- Create a single button that will be managed with list.handleInput
local BUTTONS = {
	{
		text = "Status Alignment",
		selected = true,
		options = OPTIONS,
		currentOption = 1, -- Will be updated in onEnter
	},
}

local function getCurrentIndex()
	for i, v in ipairs(OPTIONS) do
		if state.statusAlignment == v then
			return i
		end
	end
	return 1
end

function status_alignment.onEnter()
	BUTTONS[1].currentOption = getCurrentIndex()
end

function status_alignment.draw()
	background.draw()
	header.draw("status alignment")
	local screenWidth = state.screenWidth
	local y = header.getContentStartY() + 30
	local font = fonts.loaded.body
	love.graphics.setFont(font)

	-- Draw the button with indicators
	button.drawWithIndicators("Status Alignment", 0, y, true, false, screenWidth, OPTIONS[BUTTONS[1].currentOption])

	-- Draw the description below the button
	local desc = DESCRIPTIONS[BUTTONS[1].currentOption]
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

function status_alignment.update(_dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Handle B button to return to menu
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		screens.switchTo("main_menu")
		return
	end

	-- Use the enhanced list input handler for option cycling
	list.handleInput({
		items = BUTTONS,
		virtualJoystick = virtualJoystick,

		-- Handle option cycling (left/right d-pad)
		handleItemOption = function(btn, direction)
			-- Calculate new option index
			local newIndex = btn.currentOption + direction

			-- Wrap around if needed
			if newIndex < 1 then
				newIndex = #btn.options
			elseif newIndex > #btn.options then
				newIndex = 1
			end

			-- Update current option
			btn.currentOption = newIndex

			-- Update state with selected option
			state.statusAlignment = btn.options[newIndex]

			return true
		end,
	})
end

return status_alignment
