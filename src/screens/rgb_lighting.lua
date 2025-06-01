--- RGB lighting settings screen
local love = require("love")

local controls = require("controls")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List

local rgbUtils = require("utils.rgb")

-- Module table to export public functions
local rgb_lighting = {}

-- Screen switching
local MENU_SCREEN = "main_menu"
local COLOR_PICKER_SCREEN = "color_picker"

-- RGB mode options
local RGB_MODES = {
	"Solid",
	"Fast Breathing",
	"Medium Breathing",
	"Slow Breathing",
	"Mono Rainbow",
	"Multi Rainbow",
	"Off",
}

local menuList = nil
local input = nil

-- Helper function to check if RGB color should be visible based on mode
local function isColorVisible()
	local currentMode = state.rgbMode
	return currentMode ~= "Off" and currentMode ~= "Multi Rainbow" and currentMode ~= "Mono Rainbow"
end

-- Helper function to check if RGB speed should be visible based on mode
local function isSpeedVisible()
	local currentMode = state.rgbMode
	return currentMode ~= "Off"
		and currentMode ~= "Solid"
		and currentMode ~= "Fast Breathing"
		and currentMode ~= "Medium Breathing"
		and currentMode ~= "Slow Breathing"
end

-- Helper function to check if RGB brightness should be visible based on mode
local function isBrightnessVisible()
	local currentMode = state.rgbMode
	return currentMode ~= "Off"
end

local function createMenuButtons()
	local buttons = {}
	table.insert(
		buttons,
		Button:new({
			text = "Mode",
			type = ButtonTypes.INDICATORS,
			options = RGB_MODES,
			currentOptionIndex = (function()
				for i, option in ipairs(RGB_MODES) do
					if option == state.rgbMode then
						return i
					end
				end
				return 1
			end)(),
			screenWidth = state.screenWidth,
			context = "modeToggle",
		})
	)
	if isBrightnessVisible() then
		table.insert(
			buttons,
			Button:new({
				text = "Brightness",
				type = ButtonTypes.INDICATORS,
				options = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
				currentOptionIndex = state.rgbBrightness or 5,
				screenWidth = state.screenWidth,
				context = "brightnessToggle",
			})
		)
	end
	if isColorVisible() then
		table.insert(
			buttons,
			Button:new({
				text = "Color",
				type = ButtonTypes.COLOR,
				hexColor = state.getColorValue("rgb"),
				monoFont = fonts.loaded.monoBody,
				screenWidth = state.screenWidth,
				onClick = function()
					state.activeColorContext = "rgb"
					state.previousScreen = "rgb_lighting"
					screens.switchTo(COLOR_PICKER_SCREEN)
				end,
			})
		)
	end
	if isSpeedVisible() then
		table.insert(
			buttons,
			Button:new({
				text = "Speed",
				type = ButtonTypes.INDICATORS,
				options = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
				currentOptionIndex = state.rgbSpeed or 5,
				screenWidth = state.screenWidth,
				context = "speedToggle",
			})
		)
	end
	return buttons
end

local function handleOptionCycle(button, direction)
	if button.context == "modeToggle" then
		local changed = button:cycleOption(direction)
		if changed then
			state.rgbMode = button:getCurrentOption()
			if state.hasRGBSupport then
				rgbUtils.updateConfig()
			end
			if menuList then
				menuList:setItems(createMenuButtons())
			end
		end
		return changed
	elseif button.context == "brightnessToggle" then
		local changed = button:cycleOption(direction)
		if changed then
			state.rgbBrightness = button:getCurrentOption()
			if state.hasRGBSupport then
				rgbUtils.updateConfig()
			end
		end
		return changed
	elseif button.context == "speedToggle" then
		local changed = button:cycleOption(direction)
		if changed then
			state.rgbSpeed = button:getCurrentOption()
			if state.hasRGBSupport then
				rgbUtils.updateConfig()
			end
		end
		return changed
	end
	return false
end

function rgb_lighting.load()
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
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})
end

function rgb_lighting.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("rgb lighting")

	love.graphics.setFont(fonts.loaded.body)

	if menuList then
		menuList:draw()
	end

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Change value" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Save" },
	})
end

function rgb_lighting.update(dt)
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end
	local virtualJoystick = require("input").virtualJoystick
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		screens.switchTo(MENU_SCREEN)
		return
	end
end

function rgb_lighting.onEnter()
	if menuList then
		menuList:setItems(createMenuButtons())
	end
	if state.hasRGBSupport then
		rgbUtils.updateConfig()
	end
end

function rgb_lighting.onExit()
	-- No-op for now
end

return rgb_lighting
