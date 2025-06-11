--- RGB lighting settings screen
local love = require("love")

local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.header")
local List = require("ui.list").List
local InputManager = require("ui.InputManager")

local rgbUtils = require("utils.rgb")

-- Module table to export public functions
local rgb_lighting = {}

-- Screen switching
local MENU_SCREEN = "main_menu"
local COLOR_PICKER_SCREEN = "color_picker"

-- RGB mode options
local RGB_MODES = {
	"Solid",
	"Breathing",
	"Mono Rainbow",
	"Multi Rainbow",
	"Off",
}

-- Breathing speed options
local BREATHING_SPEEDS = {
	"Slow",
	"Medium",
	"Fast",
}

local menuList = nil
local input = nil

local headerInstance = Header:new({ title = "RGB Lighting" })
local controlHintsInstance

-- Helper function to get the current breathing speed based on rgbMode
local function getCurrentBreathingSpeed()
	if state.rgbMode == "Fast Breathing" then
		return 1
	elseif state.rgbMode == "Medium Breathing" then
		return 2
	elseif state.rgbMode == "Slow Breathing" then
		return 3
	else
		return 2 -- Default to Medium
	end
end

-- Helper function to get the current mode display name
local function getCurrentModeDisplay()
	if
		state.rgbMode == "Fast Breathing"
		or state.rgbMode == "Medium Breathing"
		or state.rgbMode == "Slow Breathing"
	then
		return "Breathing"
	else
		return state.rgbMode
	end
end

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
		and (
			currentMode == "Fast Breathing"
			or currentMode == "Medium Breathing"
			or currentMode == "Slow Breathing"
			or currentMode == "Mono Rainbow"
			or currentMode == "Multi Rainbow"
		)
end

-- Helper function to check if breathing speed should be visible
local function isBreathingSpeedVisible()
	local currentMode = state.rgbMode
	return currentMode == "Fast Breathing" or currentMode == "Medium Breathing" or currentMode == "Slow Breathing"
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
				local currentDisplay = getCurrentModeDisplay()
				for i, option in ipairs(RGB_MODES) do
					if option == currentDisplay then
						return i
					end
				end
				return 1
			end)(),
			screenWidth = state.screenWidth,
			context = "modeToggle",
		})
	)
	if isBreathingSpeedVisible() then
		table.insert(
			buttons,
			Button:new({
				text = "Speed",
				type = ButtonTypes.INDICATORS,
				options = BREATHING_SPEEDS,
				currentOptionIndex = getCurrentBreathingSpeed(),
				screenWidth = state.screenWidth,
				context = "breathingSpeedToggle",
			})
		)
	end
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

	if isSpeedVisible() and not isBreathingSpeedVisible() then
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
			local selectedMode = button:getCurrentOption()
			if selectedMode == "Breathing" then
				-- Default to Medium Breathing when switching to Breathing mode
				state.rgbMode = "Medium Breathing"
			else
				state.rgbMode = selectedMode
			end
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
	elseif button.context == "breathingSpeedToggle" then
		local changed = button:cycleOption(direction)
		if changed then
			local selectedSpeed = button:getCurrentOption()
			if selectedSpeed == "Fast" then
				state.rgbMode = "Fast Breathing"
			elseif selectedSpeed == "Medium" then
				state.rgbMode = "Medium Breathing"
			elseif selectedSpeed == "Slow" then
				state.rgbMode = "Slow Breathing"
			end
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

function rgb_lighting.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	headerInstance:draw()

	love.graphics.setFont(fonts.loaded.body)

	if menuList then
		menuList:draw()
	end

	-- Draw controls
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

function rgb_lighting.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, input)
		menuList:update(dt)
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo(MENU_SCREEN)
		return
	end
end

function rgb_lighting.onEnter()
	-- Create menu list
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - 60,
		items = createMenuButtons(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})

	if state.hasRGBSupport then
		rgbUtils.updateConfig()
	end

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function rgb_lighting.onExit()
	-- No-op for now
end

return rgb_lighting
