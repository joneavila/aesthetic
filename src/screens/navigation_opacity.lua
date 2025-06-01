--- Navigation Alpha screen
-- This screen allows controlling the alpha/transparency of navigation elements

local love = require("love")

local colors = require("colors")
local controls = require("controls")
local input = require("input")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local Slider = require("ui.slider").Slider

-- Screen switching
local MENU_SCREEN = "main_menu" -- Add MENU_SCREEN constant

-- Module table to export public functions
local navigation_opacity = {}

-- Alpha values for the slider (0-100 in increments of 10)
local alphaValues = { 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 }

local alphaSlider = nil

-- Function to get display text for an alpha value
local function getDisplayText(alpha)
	return tostring(alpha) .. "%"
end

-- Draw the screen
function navigation_opacity.draw()
	-- Draw background
	background.draw()

	-- Draw header
	header.draw("navigation alpha")

	-- Set font
	love.graphics.setFont(fonts.loaded.body)

	-- Calculate position
	local startY = header.getContentStartY() + 60

	-- Draw slider
	local sliderY = startY + 40
	if alphaSlider then
		alphaSlider:draw()
	end

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
	local alpha = alphaSlider and alphaSlider.values[alphaSlider.valueIndex] / 100 or 1

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
function navigation_opacity.update(dt)
	if alphaSlider then
		alphaSlider:update(dt)
	end
	local virtualJoystick = input.virtualJoystick
	local handler = inputHandler.create(virtualJoystick)
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		screens.switchTo(MENU_SCREEN)
		return
	end
	if alphaSlider and alphaSlider:handleInput(handler) then
		state.navigationAlpha = alphaSlider.values[alphaSlider.valueIndex]
	end
end

-- Called when entering the screen
function navigation_opacity.onEnter()
	-- Find the closest alpha value index
	local closestIndex = 11 -- Default to 100%
	local minDiff = 100

	if state.navigationAlpha then
		for i, value in ipairs(alphaValues) do
			local diff = math.abs(state.navigationAlpha - value)
			if diff < minDiff then
				minDiff = diff
				closestIndex = i
			end
		end
	end

	alphaSlider = Slider:new({
		x = 40,
		y = header.getContentStartY() + 100,
		width = state.screenWidth - 80,
		values = alphaValues,
		valueIndex = closestIndex,
		label = "Transparency",
		onValueChanged = function(val, _idx)
			state.navigationAlpha = val
		end,
	})
end

return navigation_opacity
