--- Navigation Settings Screen
-- NOTE: The header screen (header.lua) and navigation screen (navigation.lua) share layout,
-- so any changes made here should be made to the other screen.
local love = require("love")

local colors = require("colors")
local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.header")
local Slider = require("ui.slider").Slider
local List = require("ui.list").List
local InputManager = require("ui.InputManager")

local navigationScreen = {}

-- UI Components
local input = nil
local headerInstance = Header:new({ title = "Navigation" })
local controlHintsInstance

-- Constants
local EDGE_PADDING = 18

-- Opacity values for the slider (0-100 in increments of 10)
local opacityValues = { 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 }

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
	local alignmentOptions = { "Left", "Center", "Right" }
	local currentIndex = ({ ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 })[state.navigationAlignment] or 2

	return Button:new({
		text = "Alignment",
		type = ButtonTypes.INDICATORS,
		options = alignmentOptions,
		currentOptionIndex = currentIndex,
		screenWidth = state.screenWidth,
		context = "navigationAlignment",
	})
end

-- Create the opacity slider
local function createOpacitySlider(y)
	-- Find the closest opacity value index
	local closestIndex = 11 -- Default to 100%
	local minDiff = 100

	local percent = state.navigationOpacity or 100
	for i, value in ipairs(opacityValues) do
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
		values = opacityValues,
		valueIndex = closestIndex,
		label = "Opacity",
		valueFormatter = formatSliderValue,
		onValueChanged = function(val, _idx)
			state.navigationOpacity = val
		end,
	})
end

function navigationScreen.draw()
	background.draw()
	headerInstance:draw()

	love.graphics.setFont(fonts.loaded.body)
	if navigationScreen.list then
		navigationScreen.list:draw()
	end
	-- Draw preview rectangle (same as before, but get opacity from slider)
	local opacitySlider = navigationScreen.list and navigationScreen.list.items[2]
	local previewY = (opacitySlider and opacitySlider.y + opacitySlider:getHeight() + 20) or 200
	local previewHeight = 100
	local previewWidth = state.screenWidth - 80
	local alpha = opacitySlider and opacitySlider.values[opacitySlider.valueIndex] / 100 or 1
	local bgColor = state.getColorValue("background")
	local bgR, bgG, bgB = love.math.colorFromBytes(
		tonumber(bgColor:sub(2, 3), 16),
		tonumber(bgColor:sub(4, 5), 16),
		tonumber(bgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(bgR, bgG, bgB, 1.0)
	love.graphics.rectangle("fill", 40, previewY, previewWidth, previewHeight, 8, 8)
	local fgColor = state.getColorValue("foreground")
	local fgR, fgG, fgB = love.math.colorFromBytes(
		tonumber(fgColor:sub(2, 3), 16),
		tonumber(fgColor:sub(4, 5), 16),
		tonumber(fgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(fgR, fgG, fgB, alpha)
	local textAlign = "center"
	local textPadding = 0
	local currentAlignment = state.navigationAlignment or "Center"
	if currentAlignment == "Left" then
		textAlign = "left"
		textPadding = 16
	elseif currentAlignment == "Center" then
		textAlign = "center"
	elseif currentAlignment == "Right" then
		textAlign = "right"
		textPadding = 16
	end
	love.graphics.printf(
		"Preview",
		40 + textPadding,
		previewY + (previewHeight / 2) - (fonts.loaded.body:getHeight() / 2),
		previewWidth - (textPadding * 2),
		textAlign
	)
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", 40, previewY, previewWidth, previewHeight, 8, 8)
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

function navigationScreen.update(dt)
	if navigationScreen.list then
		local navDir = InputManager.getNavigationDirection()
		navigationScreen.list:handleInput(navDir, input)
		navigationScreen.list:update(dt)
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

function navigationScreen.onEnter(_data)
	local startY = headerInstance:getContentStartY()
	local alignmentButton = createAlignmentButton()
	alignmentButton.y = 0 -- List will set position
	local opacitySlider = createOpacitySlider(0) -- List will set position
	navigationScreen.list = List:new({
		x = 0,
		y = startY,
		width = state.screenWidth,
		height = state.screenHeight - startY - 60,
		items = { alignmentButton, opacitySlider },
	})
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function navigationScreen.onExit()
	navigationScreen.list = nil
end

return navigationScreen
