local love = require("love")
local screens = require("screens")
local state = require("state")
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local List = require("ui.list").List
local background = require("ui.background")
local controlHints = require("control_hints")
local Slider = require("ui.slider").Slider

local battery = {}

local menuList = nil
local input = nil

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
			text = "Active",
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
			text = "Low",
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
	header.draw("Battery")
	love.graphics.setFont(fonts.loaded.body)
	if menuList then
		menuList:draw()
	end
	controlHints.draw({
		{ button = "b", text = "Back" },
		{ button = "a", text = "Select" },
	})
end

function battery.update(dt)
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end
	local virtualJoystick = require("input").virtualJoystick
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		screens.switchTo("main_menu")
		return
	end
end

function battery.onEnter()
	input = inputHandler.create()
	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - header.getContentStartY() - 60,
		items = createBatteryListItems(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
	})
end

return battery
