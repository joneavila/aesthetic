--- RGB lighting settings screen
local love = require("love")

local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local List = require("ui.components.list").List
local InputManager = require("ui.controllers.input_manager")
local Slider = require("ui.components.slider").Slider

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

-- Store button instances globally
local modeButton, breathingSpeedButton, brightnessSlider, colorButton, speedButton

-- Track previous menu structure
local prevMenuStructure = {}

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

local function createButtons()
	modeButton = Button:new({
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
	if isBreathingSpeedVisible() then
		breathingSpeedButton = Button:new({
			text = "Speed",
			type = ButtonTypes.INDICATORS,
			options = BREATHING_SPEEDS,
			currentOptionIndex = getCurrentBreathingSpeed(),
			screenWidth = state.screenWidth,
			context = "breathingSpeedToggle",
		})
	else
		breathingSpeedButton = nil
	end
	if isBrightnessVisible() then
		brightnessSlider = Slider:new({
			label = "Brightness",
			values = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
			valueIndex = state.rgbBrightness or 5,
			width = state.screenWidth,
			valueFormatter = function(val)
				return tostring(val * 10) .. "%"
			end,
			onValueChanged = function(val, idx)
				state.rgbBrightness = idx
				if state.hasRGBSupport then
					rgbUtils.updateConfig()
				end
			end,
		})
	else
		brightnessSlider = nil
	end
	if isColorVisible() then
		colorButton = Button:new({
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
	else
		colorButton = nil
	end
	if isSpeedVisible() and not isBreathingSpeedVisible() then
		speedButton = Button:new({
			text = "Speed",
			type = ButtonTypes.INDICATORS,
			options = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
			currentOptionIndex = state.rgbSpeed or 5,
			screenWidth = state.screenWidth,
			context = "speedToggle",
		})
	else
		speedButton = nil
	end
end

local function getMenuItems()
	local items = { modeButton }
	if breathingSpeedButton then
		table.insert(items, breathingSpeedButton)
	end
	if brightnessSlider then
		table.insert(items, brightnessSlider)
	end
	if colorButton then
		table.insert(items, colorButton)
	end
	if speedButton then
		table.insert(items, speedButton)
	end
	return items
end

local function getMenuStructure()
	return {
		isBreathing = isBreathingSpeedVisible(),
		isSpeed = isSpeedVisible() and not isBreathingSpeedVisible(),
		isBrightness = isBrightnessVisible(),
		isColor = isColorVisible(),
		mode = getCurrentModeDisplay(),
	}
end

local function menuStructureChanged(a, b)
	if not a or not b then
		return true
	end
	return a.isBreathing ~= b.isBreathing
		or a.isSpeed ~= b.isSpeed
		or a.isBrightness ~= b.isBrightness
		or a.isColor ~= b.isColor
		or a.mode ~= b.mode
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

		local prevMode = state.rgbMode
		local prevBrightness = state.rgbBrightness
		local prevSpeed = state.rgbSpeed

		-- Handle Mode button
		if modeButton and modeButton.getCurrentOption then
			local selectedMode = modeButton:getCurrentOption()
			if selectedMode == "Breathing" then
				if
					not (
						state.rgbMode == "Fast Breathing"
						or state.rgbMode == "Medium Breathing"
						or state.rgbMode == "Slow Breathing"
					)
				then
					state.rgbMode = "Medium Breathing"
				end
			else
				if state.rgbMode ~= selectedMode then
					state.rgbMode = selectedMode
				end
			end
			-- If mode changed, immediately rebuild menu and return
			if prevMode ~= state.rgbMode then
				createButtons()
				menuList:setItems(getMenuItems())
				prevMenuStructure = getMenuStructure()
				if state.hasRGBSupport then
					rgbUtils.updateConfig()
				end
				return
			end
		end

		-- Handle Breathing Speed button
		if breathingSpeedButton and breathingSpeedButton.getCurrentOption then
			local selectedSpeed = breathingSpeedButton:getCurrentOption()
			local newMode = nil
			if selectedSpeed == "Fast" then
				newMode = "Fast Breathing"
			elseif selectedSpeed == "Medium" then
				newMode = "Medium Breathing"
			elseif selectedSpeed == "Slow" then
				newMode = "Slow Breathing"
			end
			if newMode and state.rgbMode ~= newMode then
				state.rgbMode = newMode
			end
		end

		-- Handle Brightness slider
		if brightnessSlider and brightnessSlider.valueIndex then
			if state.rgbBrightness ~= brightnessSlider.valueIndex then
				state.rgbBrightness = brightnessSlider.valueIndex
			end
		end

		-- Handle Speed button
		if speedButton and speedButton.getCurrentOption then
			local newSpeed = speedButton:getCurrentOption()
			if state.rgbSpeed ~= newSpeed then
				state.rgbSpeed = newSpeed
			end
		end

		if
			state.hasRGBSupport
			and (prevMode ~= state.rgbMode or prevBrightness ~= state.rgbBrightness or prevSpeed ~= state.rgbSpeed)
		then
			rgbUtils.updateConfig()
		end

		-- Only rebuild menu if structure changes
		local currentStructure = getMenuStructure()
		if menuStructureChanged(currentStructure, prevMenuStructure) then
			createButtons()
			menuList:setItems(getMenuItems())
			prevMenuStructure = currentStructure
		end
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo(MENU_SCREEN)
		return
	end
end

function rgb_lighting.onEnter()
	createButtons()
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - 60,
		items = getMenuItems(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
	})
	prevMenuStructure = getMenuStructure()
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
