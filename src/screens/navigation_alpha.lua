--- Navigation Alpha screen
-- This screen allows controlling the alpha/transparency of navigation elements

local love = require("love")
local state = require("state")
local colors = require("colors")
local background = require("ui.background")
local header = require("ui.header")
local controls = require("controls")
local slider = require("ui.slider")
local input = require("input")
local list = require("ui.list")

-- Screen switching
local switchScreen = nil

-- Module table to export public functions
local navigation_alpha = {}

-- Alpha values for the slider (0-100 in increments of 10)
local alphaValues = { 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 }

-- Create a button that represents slider for list.handleInput
local BUTTONS = {
	{
		text = "Transparency",
		selected = true,
		min = 1,
		max = #alphaValues,
		value = 11, -- Default to 100%
		step = 1,
	},
}

-- Set the screen switcher function
function navigation_alpha.setScreenSwitcher(switcher)
	switchScreen = switcher
end

-- Draw the screen
function navigation_alpha.draw()
	-- Draw background
	background.draw()

	-- Draw header
	header.draw("navigation alpha")

	-- Set font
	love.graphics.setFont(state.fonts.body)

	-- Calculate position
	local startY = header.getContentStartY() + 60

	-- Draw slider
	local sliderY = startY + 40
	slider.draw(40, sliderY, state.screenWidth - 80, alphaValues, BUTTONS[1].value, "Transparency")

	-- Draw preview area
	local previewY = sliderY + 120
	local previewHeight = 100

	-- Draw preview label
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.printf("Preview", 40, previewY, state.screenWidth - 80, "center")

	-- Draw preview box with current alpha value
	previewY = previewY + 30
	local previewWidth = state.screenWidth - 80

	-- Calculate alpha from current value (0-100 to 0-1)
	local alpha = alphaValues[BUTTONS[1].value] / 100

	-- Draw preview rectangle with selected alpha
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], alpha)
	love.graphics.rectangle("fill", 40, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw border around preview
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", 40, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw control hints
	controls.draw({
		{ button = "b", text = "Save" },
		{ button = "d_pad", text = "Adjust" },
	})
end

-- Update function to handle input
function navigation_alpha.update(_dt)
	local virtualJoystick = input.virtualJoystick

	-- Handle save button
	if virtualJoystick.isGamepadPressedWithDelay("b") and switchScreen then
		switchScreen("main_menu")
		return
	end

	-- Use the enhanced list input handler for option cycling
	list.handleInput({
		items = BUTTONS,
		virtualJoystick = virtualJoystick,

		-- Handle option cycling (left/right d-pad)
		handleItemOption = function(btn, direction)
			-- Calculate new value with bounds checking
			local newValue = btn.value + direction

			-- Clamp to min/max
			if newValue < btn.min then
				newValue = btn.min
			elseif newValue > btn.max then
				newValue = btn.max
			end

			-- Only update if changed
			if newValue ~= btn.value then
				btn.value = newValue
				state.navigationAlpha = alphaValues[btn.value]
				return true
			end

			return false
		end,
	})
end

-- Called when entering the screen
function navigation_alpha.onEnter()
	-- Find the closest alpha value index
	local closestIndex = 11 -- Default to 100%
	local minDiff = 100

	-- If navigationAlpha is already set in state, find the closest value
	if state.navigationAlpha then
		for i, value in ipairs(alphaValues) do
			local diff = math.abs(state.navigationAlpha - value)
			if diff < minDiff then
				minDiff = diff
				closestIndex = i
			end
		end
	end

	BUTTONS[1].value = closestIndex

	-- Initialize the list UI state with the selected item
	list.setSelectedIndex(1, BUTTONS)

	-- Make sure state has the value set
	state.navigationAlpha = alphaValues[BUTTONS[1].value]
end

return navigation_alpha
