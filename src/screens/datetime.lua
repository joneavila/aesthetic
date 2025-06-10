--- Datetime Settings Screen
-- NOTE: The datetime screen (datetime.lua) and navigation screen (navigation.lua) share layout,
-- so any changes made here should be made to the other screen.
local love = require("love")

local colors = require("colors")
local controls = require("control_hints")
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

-- Add menuList variable
local menuList = nil

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
	love.graphics.setColor(colors.ui.foreground)

	if menuList then
		menuList:draw()
	end

	-- Draw preview rectangle
	local previewY = 0
	if menuList then
		previewY = menuList.y + menuList:getContentHeight() + 20
	else
		previewY = header.getContentStartY() + 120
	end
	local previewHeight = 100
	local previewWidth = state.screenWidth - 80

	-- Calculate alpha from current slider value (0-100 to 0-1)
	local alpha = 1
	if menuList and menuList.items[2] then
		local slider = menuList.items[2]
		alpha = slider.values[slider.valueIndex] / 100
	end

	-- Get background color from state and draw rectangle at full opacity
	local bgColor = state.getColorValue("background")
	local bgR, bgG, bgB = love.math.colorFromBytes(
		tonumber(bgColor:sub(2, 3), 16),
		tonumber(bgColor:sub(4, 5), 16),
		tonumber(bgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(bgR, bgG, bgB, 1.0)
	love.graphics.rectangle("fill", 40, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw "Preview" text with alignment matching the current setting
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
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end
	if input.isPressed("b") then
		screens.switchTo("main_menu")
	end
end

function datetimeScreen.onEnter(_data)
	input = inputHandler.create()

	local startY = header.getContentStartY()
	local warningHeight = calculateWarningHeight()
	local listY = startY + warningHeight + COMPONENT_SPACING - 2

	local items = {
		createAlignmentButton(),
		createOpacitySlider(0),
	}

	menuList = require("ui.list").List:new({
		x = 0,
		y = listY,
		width = state.screenWidth,
		height = state.screenHeight - listY - 60,
		items = items,
		onItemOptionCycle = function(button, direction)
			if button.context == "timeAlignment" then
				local changed = button:cycleOption(direction)
				if changed then
					local newValue = button:getCurrentOption()
					state.timeAlignment = newValue
				end
				return changed
			end
			return false
		end,
	})
end

function datetimeScreen.onExit()
	menuList = nil
end

return datetimeScreen
