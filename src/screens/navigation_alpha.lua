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

-- Screen switching
local switchScreen = nil

-- Module table to export public functions
local navigation_alpha = {}

-- Alpha values for the slider (0-100 in increments of 10)
local alphaValues = { 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 }

-- Current selected value index
local currentValueIndex = 11 -- Default to 100%

-- Set the screen switcher function
function navigation_alpha.setScreenSwitcher(switcher)
	switchScreen = switcher
end

-- Draw the screen
function navigation_alpha.draw()
	-- Draw background
	background.draw()

	-- Draw header
	header.draw("NAVIGATION ALPHA")

	-- Set font
	love.graphics.setFont(state.fonts.body)

	-- Calculate position
	local startY = header.getHeight() + 60

	-- Draw slider
	local sliderY = startY + 40
	slider.draw(40, sliderY, state.screenWidth - 80, alphaValues, currentValueIndex, "Transparency")

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
	local alpha = alphaValues[currentValueIndex] / 100

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
	local virtualJoystick = input.virtualJoystick

	-- Handle left/right to adjust the slider
	if virtualJoystick.isGamepadPressedWithDelay("dpleft") then
		currentValueIndex = slider.updateValue(currentValueIndex, -1, alphaValues)
		state.navigationAlpha = alphaValues[currentValueIndex]
	elseif virtualJoystick.isGamepadPressedWithDelay("dpright") then
		currentValueIndex = slider.updateValue(currentValueIndex, 1, alphaValues)
		state.navigationAlpha = alphaValues[currentValueIndex]
	end

	-- Handle save button
	if virtualJoystick.isGamepadPressedWithDelay("b") and switchScreen then
		switchScreen("main_menu")
	end
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

	currentValueIndex = closestIndex

	-- Make sure state has the value set
	state.navigationAlpha = alphaValues[currentValueIndex]
end

return navigation_alpha
