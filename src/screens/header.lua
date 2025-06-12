--- Header Settings Screen
-- NOTE: The header screen (header.lua) and navigation screen (navigation.lua) share layout,
-- so any changes made here should be made to the other screen.
local love = require("love")

local colors = require("colors")
local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local InputManager = require("ui.controllers.input_manager")
local Slider = require("ui.components.slider").Slider
local List = require("ui.components.list").List

local headerScreen = {}

-- UI Components
local menuList = nil
local input = nil
local headerInstance = Header:new({ title = "Header" })

-- Constants
local EDGE_PADDING = 18
local COMPONENT_SPACING = 10
local WARNING_TEXT = "Note: Header alignment setting may conflict with time alignment and status alignment settings."
local WARNING_TEXT_FONT = fonts.loaded.caption

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
	local currentIndex = (state.headerAlignment or 0) + 1

	return Button:new({
		text = "Alignment",
		type = ButtonTypes.INDICATORS,
		options = alignmentOptions,
		currentOptionIndex = currentIndex,
		screenWidth = state.screenWidth,
		context = "headerAlignment",
	})
end

-- Create the opacity slider
local function createOpacitySlider()
	-- Find the closest alpha value index
	local closestIndex = 11 -- Default to 100%
	local minDiff = 100

	local percent = math.floor((state.headerOpacity / 255) * 100 + 0.5)
	for i, value in ipairs(alphaValues) do
		local diff = math.abs(percent - value)
		if diff < minDiff then
			minDiff = diff
			closestIndex = i
		end
	end

	return Slider:new({
		x = EDGE_PADDING,
		y = 0, -- Will be set by List
		width = state.screenWidth - (EDGE_PADDING * 2),
		values = alphaValues,
		valueIndex = closestIndex,
		label = "Opacity",
		valueFormatter = formatSliderValue,
		onValueChanged = function(val, _idx)
			state.headerOpacity = math.floor((val / 100) * 255 + 0.5)
		end,
	})
end

-- Handle option cycling for alignment button
local function handleAlignmentOptionCycle(button, direction)
	if button.context == "headerAlignment" then
		local changed = button:cycleOption(direction)
		if changed then
			local newValue = button:getCurrentOption()
			local alignmentMap = { ["Auto"] = 0, ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 }
			state.headerAlignment = alignmentMap[newValue] or 2
		end
		return changed
	end
	return false
end

-- Calculate warning text height properly accounting for wrapping
local function calculateWarningHeight()
	local warningWidth = state.screenWidth - (EDGE_PADDING * 2)
	local _, wrappedLines = WARNING_TEXT_FONT:getWrap(WARNING_TEXT, warningWidth)
	return #wrappedLines * WARNING_TEXT_FONT:getHeight()
end

function headerScreen.draw()
	background.draw()
	headerInstance:draw()

	-- Draw warning text below header
	love.graphics.setFont(WARNING_TEXT_FONT)
	love.graphics.setColor(colors.ui.subtext)
	local warningY = headerInstance:getContentStartY() + 2
	local warningWidth = state.screenWidth - (EDGE_PADDING * 2)
	love.graphics.printf(WARNING_TEXT, EDGE_PADDING, warningY, warningWidth, "left")
	love.graphics.setFont(fonts.loaded.body)
	love.graphics.setColor(colors.ui.foreground)

	local previewY = headerInstance:getContentStartY() + calculateWarningHeight() + COMPONENT_SPACING
	if menuList then
		menuList:calculateDimensions()
		menuList:draw()
		previewY = previewY + menuList.y + menuList:getContentHeight()
	end
	local previewX = 40
	local previewWidth = state.screenWidth - 80
	local controlsHeight = controls.calculateHeight()
	local previewHeight = state.screenHeight - controlsHeight - previewY - 20

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
	love.graphics.rectangle("fill", previewX, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw "Preview" text with alignment matching the current setting
	local fgColor = state.getColorValue("foreground")
	local fgR, fgG, fgB = love.math.colorFromBytes(
		tonumber(fgColor:sub(2, 3), 16),
		tonumber(fgColor:sub(4, 5), 16),
		tonumber(fgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(fgR, fgG, fgB, alpha)

	-- Determine text alignment based on header alignment setting
	local textAlign = "center" -- default
	local textPadding = 0
	local currentAlignment = state.headerAlignment or 2
	if currentAlignment == 1 then
		textAlign = "left"
		textPadding = 16 -- Add left padding
	elseif currentAlignment == 2 then
		textAlign = "center"
	elseif currentAlignment == 3 then
		textAlign = "right"
		textPadding = 16 -- Add right padding by reducing width
	end
	-- Auto (0) uses center as default

	love.graphics.printf(
		"Preview",
		previewX + textPadding,
		previewY + (previewHeight / 2) - (fonts.loaded.body:getHeight() / 2),
		previewWidth - (textPadding * 2),
		textAlign
	)

	-- Draw border around preview
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", previewX, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw controls
	controls.draw({
		{ button = "b", text = "Back" },
	})
end

function headerScreen.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, input)
		menuList:update(dt)
		local alignmentButton = menuList.items[1]
		if alignmentButton and alignmentButton.getCurrentOption then
			local alignmentMap = { ["Auto"] = 0, ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 }
			local newValue = alignmentButton:getCurrentOption()
			state.headerAlignment = alignmentMap[newValue] or 2
		end
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

function headerScreen.onEnter(_data)
	local startY = headerInstance:getContentStartY()
	local warningHeight = calculateWarningHeight()
	local listY = startY + warningHeight + COMPONENT_SPACING

	local items = {
		createAlignmentButton(),
		createOpacitySlider(),
	}

	menuList = List:new({
		x = 0,
		y = listY,
		width = state.screenWidth,
		height = state.screenHeight - listY - 60,
		items = items,
		onItemOptionCycle = handleAlignmentOptionCycle,
	})
end

function headerScreen.onExit()
	menuList = nil
end

return headerScreen
