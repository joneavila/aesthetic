local love = require("love")

local colors = require("colors")
local controlHints = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local InputManager = require("ui.controllers.input_manager")
local List = require("ui.components.list").List
local Slider = require("ui.components.slider").Slider

local battery = {}

local menuList = nil
local input = nil
local headerInstance = Header:new({ title = "Battery" })
local controlHintsInstance

local opacityValues = { 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 }
local function formatSliderValue(value)
	if value == 0 then
		return "0% (Hidden)"
	else
		return value .. "%"
	end
end
local function createBatteryListItems()
	local items = {
		Button:new({
			text = "Charging Color",
			type = ButtonTypes.COLOR,
			hexColor = state.getColorValue("batteryActive"),
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				state.activeColorContext = "batteryActive"
				state.previousScreen = "battery"
				screens.switchTo("color_picker")
			end,
		}),
		Button:new({
			text = "Low Color",
			type = ButtonTypes.COLOR,
			hexColor = state.getColorValue("batteryLow"),
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				state.activeColorContext = "batteryLow"
				state.previousScreen = "battery"
				screens.switchTo("color_picker")
			end,
		}),
	}
	-- Find closest index for batteryOpacity
	local closestIndex = 11
	local minDiff = 255
	local percent = state.batteryOpacity or 255
	for i, value in ipairs(opacityValues) do
		local scaled = value * 2.55
		local diff = math.abs(percent - scaled)
		if diff < minDiff then
			minDiff = diff
			closestIndex = i
		end
	end
	table.insert(
		items,
		Slider:new({
			x = 0,
			y = 0, -- List will set position
			width = state.screenWidth - 36,
			values = opacityValues,
			valueIndex = closestIndex,
			label = "Opacity",
			valueFormatter = formatSliderValue,
			onValueChanged = function(val, _idx)
				state.batteryOpacity = math.floor(val * 2.55 + 0.5)
			end,
		})
	)
	return items
end

function battery.draw()
	background.draw()
	headerInstance:draw()
	love.graphics.setFont(fonts.loaded.body)
	if menuList then
		menuList:draw()
	end

	-- Find the slider in the menuList
	local slider = menuList and menuList.items and menuList.items[3]
	local previewY = (slider and slider.y + slider:getHeight() + 20) or 200
	local previewHeight = 100
	local previewWidth = state.screenWidth - 80
	local previewX = 40

	-- Get background color from state
	local colorUtils = require("utils.color")
	local svg = require("utils.svg")
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	love.graphics.setColor(bgColor)
	love.graphics.rectangle("fill", previewX, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw border
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", previewX, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw two SVG icons centered in the rectangle
	local iconSize = 48
	local iconSpacing = 36 -- increased by 4px
	local centerX = previewX + previewWidth / 2
	local centerY = previewY + previewHeight / 2

	-- Load icons
	local batteryActiveIcon = svg.loadIcon(
		"battery_android_5_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24",
		iconSize,
		"assets/icons/material_symbols/"
	)
	local batteryLowIcon = svg.loadIcon(
		"battery_android_1_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24",
		iconSize,
		"assets/icons/material_symbols/"
	)

	-- Get colors
	local batteryActiveColor = colorUtils.hexToLove(state.getColorValue("batteryActive"))
	local batteryLowColor = colorUtils.hexToLove(state.getColorValue("batteryLow"))

	-- Get opacity from state (0-255 scaled to 0-1)
	local opacity = (state.batteryOpacity or 255) / 255

	-- Draw icons if loaded
	if batteryActiveIcon then
		svg.drawIcon(batteryActiveIcon, centerX - iconSpacing, centerY, batteryActiveColor, opacity)
	end
	if batteryLowIcon then
		svg.drawIcon(batteryLowIcon, centerX + iconSpacing, centerY, batteryLowColor, opacity)
	end

	local controlsList = {
		{ button = "b", text = "Back" },
		{ button = "a", text = "Select" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

function battery.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, input)
		menuList:update(dt)
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
		return
	end
end

function battery.onEnter()
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - 60,
		items = createBatteryListItems(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
	})
	if not controlHintsInstance then
		controlHintsInstance = controlHints:new({})
	end
end

return battery
