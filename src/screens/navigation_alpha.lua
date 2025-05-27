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
local screens = require("screens")

-- Screen switching
local MENU_SCREEN = "main_menu" -- Add MENU_SCREEN constant

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

-- Animated slider state managed by slider.lua
local alphaSliderState = nil
local ANIMATION_DURATION = 0.25 -- Define animation duration locally

-- Function to get display text for an alpha value
local function getDisplayText(alpha)
	return tostring(alpha) .. "%"
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
	-- Use the animated value from the state table for drawing the handle position
	slider.draw(
		40, -- x
		sliderY, -- y
		state.screenWidth - 80, -- width
		alphaValues, -- values
		alphaSliderState.animatedValue, -- animatedIndex (use tweenTarget.value for smooth drawing)
		BUTTONS[1].value, -- currentIndex (for displaying value text)
		"Transparency"
	)

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
	-- Use the actual BUTTONS value, not the animated value, for the preview transparency
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
function navigation_alpha.update(dt)
	-- Update the animated slider state
	slider.updateAnimatedSliderState(alphaSliderState, dt)

	local virtualJoystick = input.virtualJoystick

	-- Handle save button
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		screens.switchTo(MENU_SCREEN)
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
				state.navigationAlpha = alphaValues[btn.value] -- Update application state

				-- Start the animation in the slider component
				slider.setAnimatedSliderValue(alphaSliderState, newValue, ANIMATION_DURATION)

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

	-- Initialize the animated slider state
	alphaSliderState = slider.createAnimatedSliderState(BUTTONS[1].value)

	-- Initialize the list UI state with the selected item
	list.setSelectedIndex(1, BUTTONS)
end

return navigation_alpha
