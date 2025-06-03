--- Datetime Settings Screen
-- NOTE: The datetime screen (datetime.lua) and navigation screen (navigation.lua) share layout,
-- so any changes made here should be made to the other screen.
local love = require("love")

local colors = require("colors")
local controls = require("controls")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local Slider = require("ui.slider").Slider

local datetimeScreen = {}

-- UI Components
local alignmentButton = nil
local opacitySlider = nil
local input = nil
local focusedComponent = 1 -- 1 = button, 2 = slider

-- Constants
local CONTROLS_HEIGHT = controls.calculateHeight()
local EDGE_PADDING = 18
local COMPONENT_SPACING = 18
local WARNING_TEXT = "Note: Time alignment setting may conflict with header alignment and status alignment settings."

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

-- Create the alignment selection button
local function createAlignmentButton()
	local alignmentOptions = { "Auto", "Left", "Center", "Right" }
	local currentIndex = ({ ["Auto"] = 1, ["Left"] = 2, ["Center"] = 3, ["Right"] = 4 })[state.timeAlignment] or 2

	return Button:new({
		text = "Alignment",
		type = ButtonTypes.INDICATORS,
		options = alignmentOptions,
		currentOptionIndex = currentIndex,
		screenWidth = state.screenWidth,
		context = "timeAlignment",
	})
end

-- Create the opacity slider
local function createOpacitySlider(y)
	-- Find the closest alpha value index
	local closestIndex = 11 -- Default to 100%
	local minDiff = 100

	local percent = math.floor((state.datetimeOpacity / 255) * 100 + 0.5)
	for i, value in ipairs(alphaValues) do
		local diff = math.abs(percent - value)
		if diff < minDiff then
			minDiff = diff
			closestIndex = i
		end
	end

	return Slider:new({
		x = EDGE_PADDING,
		y = y,
		width = state.screenWidth - (EDGE_PADDING * 2),
		values = alphaValues,
		valueIndex = closestIndex,
		label = "Opacity",
		valueFormatter = formatSliderValue,
		onValueChanged = function(val, _idx)
			state.datetimeOpacity = math.floor((val / 100) * 255 + 0.5)
		end,
	})
end

-- Handle option cycling for alignment button
local function handleAlignmentOptionCycle(direction)
	if not alignmentButton then
		return false
	end

	local changed = alignmentButton:cycleOption(direction)
	if not changed then
		return false
	end

	local newValue = alignmentButton:getCurrentOption()
	state.timeAlignment = newValue

	return true
end

-- Update focus states
local function updateFocusStates()
	if alignmentButton then
		alignmentButton:setFocused(focusedComponent == 1)
	end
	if opacitySlider then
		opacitySlider:setFocused(focusedComponent == 2)
	end
end

-- Calculate warning text height properly accounting for wrapping
local function calculateWarningHeight()
	local warningWidth = state.screenWidth - (EDGE_PADDING * 2)
	local _, wrappedLines = fonts.loaded.caption:getWrap(WARNING_TEXT, warningWidth)
	return #wrappedLines * fonts.loaded.caption:getHeight() + 10 -- Add some bottom padding
end

function datetimeScreen.load()
	input = inputHandler.create()

	-- Calculate positions
	local startY = header.getContentStartY()
	local warningHeight = calculateWarningHeight()
	local buttonY = startY + warningHeight + COMPONENT_SPACING - 2

	-- Create alignment button first to get its height
	alignmentButton = createAlignmentButton()
	alignmentButton.y = buttonY

	-- Calculate slider position based on button's actual position and height
	local sliderY = alignmentButton.y + alignmentButton.height + COMPONENT_SPACING

	opacitySlider = createOpacitySlider(sliderY)

	-- Set initial focus
	updateFocusStates()
end

function datetimeScreen.draw()
	background.draw()
	header.draw("Time")

	-- Draw warning text below header
	love.graphics.setFont(fonts.loaded.caption)
	love.graphics.setColor(colors.ui.subtext)
	local warningY = header.getContentStartY() + 2
	local warningWidth = state.screenWidth - (EDGE_PADDING * 2)
	love.graphics.printf(WARNING_TEXT, EDGE_PADDING, warningY, warningWidth, "left")
	love.graphics.setFont(fonts.loaded.body)

	-- Draw alignment button
	if alignmentButton then
		alignmentButton:draw()
	end

	-- Draw slider
	if opacitySlider then
		opacitySlider:draw()
	end

	-- Draw preview rectangle
	local previewY = opacitySlider.y + opacitySlider:getTotalHeight() + 20
	local previewHeight = 100
	local previewWidth = state.screenWidth - 80

	-- Calculate alpha from current slider value (0-100 to 0-1)
	local alpha = opacitySlider and opacitySlider.values[opacitySlider.valueIndex] / 100 or 1

	-- Get background color from state and draw rectangle at full opacity
	local bgColor = state.getColorValue("background")
	local bgR, bgG, bgB = love.math.colorFromBytes(
		tonumber(bgColor:sub(2, 3), 16),
		tonumber(bgColor:sub(4, 5), 16),
		tonumber(bgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(bgR, bgG, bgB, 1.0)
	love.graphics.rectangle("fill", 40, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw "12:34" text with alignment matching the current setting
	local fgColor = state.getColorValue("foreground")
	local fgR, fgG, fgB = love.math.colorFromBytes(
		tonumber(fgColor:sub(2, 3), 16),
		tonumber(fgColor:sub(4, 5), 16),
		tonumber(fgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(fgR, fgG, fgB, alpha)

	-- Determine text alignment based on time alignment setting
	local textAlign = "left" -- default
	local textPadding = 0
	local currentAlignment = state.timeAlignment or "Left"
	if currentAlignment == "Auto" then
		textAlign = "center"
	elseif currentAlignment == "Left" then
		textAlign = "left"
		textPadding = 16 -- Add left padding
	elseif currentAlignment == "Center" then
		textAlign = "center"
	elseif currentAlignment == "Right" then
		textAlign = "right"
		textPadding = 16 -- Add right padding by reducing width
	end

	love.graphics.printf(
		"Preview",
		40 + textPadding,
		previewY + (previewHeight / 2) - (fonts.loaded.body:getHeight() / 2),
		previewWidth - (textPadding * 2), -- Reduce width for both left and right padding
		textAlign
	)

	-- Draw border around preview
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", 40, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw controls
	controls.draw({
		{ button = "b", text = "Back" },
	})
end

function datetimeScreen.update(dt)
	-- Handle navigation between components
	if input.isPressed("dpup") then
		if focusedComponent > 1 then
			focusedComponent = focusedComponent - 1
			updateFocusStates()
		end
	elseif input.isPressed("dpdown") then
		if focusedComponent < 2 then
			focusedComponent = focusedComponent + 1
			updateFocusStates()
		end
	end

	-- Handle component-specific input
	if focusedComponent == 1 and alignmentButton then
		-- Handle alignment button input
		if input.isPressed("dpleft") then
			handleAlignmentOptionCycle(-1)
		elseif input.isPressed("dpright") then
			handleAlignmentOptionCycle(1)
		end
	elseif focusedComponent == 2 and opacitySlider then
		-- Handle slider input
		if opacitySlider:handleInput(input) then
			-- Slider value was changed
		end
	end

	-- Update components
	if alignmentButton then
		alignmentButton:update(dt)
	end
	if opacitySlider then
		opacitySlider:update(dt)
	end

	-- Handle B button press to go back
	if input.isPressed("b") then
		screens.switchTo("main_menu")
	end
end

function datetimeScreen.onEnter(data)
	-- Recreate components in case state changed
	local startY = header.getContentStartY()
	local warningHeight = calculateWarningHeight()
	local buttonY = startY + warningHeight + COMPONENT_SPACING

	alignmentButton = createAlignmentButton()
	alignmentButton.y = buttonY

	-- Calculate slider position based on button's actual position and height
	local sliderY = alignmentButton.y + alignmentButton.height + COMPONENT_SPACING

	opacitySlider = createOpacitySlider(sliderY)

	-- Reset focus to first component
	focusedComponent = 1
	updateFocusStates()
end

function datetimeScreen.onExit()
	-- Clean up
	alignmentButton = nil
	opacitySlider = nil
end

return datetimeScreen
