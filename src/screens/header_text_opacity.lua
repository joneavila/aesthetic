--- Header Text Alpha screen
-- This screen allows controlling the alpha/transparency of header text
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
local MENU_SCREEN = "main_menu"

local header_text_opacity = {}

-- Alpha values for the slider (0-100 in increments of 10)
local alphaValues = { 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 }

local alphaSlider = nil

-- Draw the screen
function header_text_opacity.draw()
	background.draw()
	header.draw("header text alpha")
	love.graphics.setFont(fonts.loaded.body)

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
function header_text_opacity.update(dt)
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
		-- Update state.headerTextAlpha (0-255) from slider percent
		local percent = alphaSlider.values[alphaSlider.valueIndex]
		state.headerTextAlpha = math.floor((percent / 100) * 255 + 0.5)
	end
end

-- Called when entering the screen
function header_text_opacity.onEnter()
	-- Find the closest alpha value index
	local closestIndex = 11 -- Default to 100%
	local minDiff = 100

	if state.headerTextAlpha then
		local percent = math.floor((state.headerTextAlpha / 255) * 100 + 0.5)
		for i, value in ipairs(alphaValues) do
			local diff = math.abs(percent - value)
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
			state.headerTextAlpha = math.floor((val / 100) * 255 + 0.5)
		end,
	})
end

return header_text_opacity
