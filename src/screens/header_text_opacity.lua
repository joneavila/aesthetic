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

-- Function to format slider values with percentage and special case for 0
local function formatSliderValue(value)
	if value == 0 then
		return "0% (Hidden)"
	else
		return value .. "%"
	end
end

local alphaSlider = nil

-- Draw the screen
function header_text_opacity.draw()
	background.draw()
	header.draw("header opacity")
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

	-- Draw preview box with background color at full opacity
	local previewWidth = state.screenWidth - 80

	-- Calculate alpha from current value (0-100 to 0-1)
	local alpha = alphaSlider and alphaSlider.values[alphaSlider.valueIndex] / 100 or 1

	-- Get background color from state and draw rectangle at full opacity
	local bgColor = state.getColorValue("background")
	local bgR, bgG, bgB = love.math.colorFromBytes(
		tonumber(bgColor:sub(2, 3), 16),
		tonumber(bgColor:sub(4, 5), 16),
		tonumber(bgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(bgR, bgG, bgB, 1.0)
	love.graphics.rectangle("fill", 40, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw "Preview" text in the center with matching opacity
	local fgColor = state.getColorValue("foreground")
	local fgR, fgG, fgB = love.math.colorFromBytes(
		tonumber(fgColor:sub(2, 3), 16),
		tonumber(fgColor:sub(4, 5), 16),
		tonumber(fgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(fgR, fgG, fgB, alpha)
	love.graphics.printf(
		"Preview",
		40,
		previewY + (previewHeight / 2) - (fonts.loaded.body:getHeight() / 2),
		previewWidth,
		"center"
	)

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
		-- Update state.headerOpacity (0-255) from slider percent
		local percent = alphaSlider.values[alphaSlider.valueIndex]
		state.headerOpacity = math.floor((percent / 100) * 255 + 0.5)
	end
end

-- Called when entering the screen
function header_text_opacity.onEnter()
	-- Find the closest alpha value index
	local closestIndex = 11 -- Default to 100%
	local minDiff = 100

	if state.headerOpacity then
		local percent = math.floor((state.headerOpacity / 255) * 100 + 0.5)
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
		label = "Opacity",
		valueFormatter = formatSliderValue,
		onValueChanged = function(val, _idx)
			state.headerOpacity = math.floor((val / 100) * 255 + 0.5)
		end,
	})
end

return header_text_opacity
