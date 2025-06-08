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

local battery = {}

local menuList = nil
local input = nil

local function createMenuButtons()
	return {
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
		items = createMenuButtons(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
	})
end

return battery
