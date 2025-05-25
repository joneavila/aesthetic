--- RGB lighting settings screen
local love = require("love")
local state = require("state")
local controls = require("controls")
local rgbUtils = require("utils.rgb")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local button = require("ui.button")
local fonts = require("ui.fonts")

-- Module table to export public functions
local rgb = {}

-- Screen switching
local switchScreen = nil
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

-- Store the last selected index for persistence
local savedSelectedIndex = 1

local scrollPosition = 0
local visibleCount = 0

-- Buttons in this screen
local ALL_BUTTONS = {
	{
		text = "Mode",
		selected = true,
		options = RGB_MODES,
		currentOption = 1, -- Will be updated in load() based on state.rgbMode
	},
	{
		text = "Color",
		selected = false,
		colorKey = "rgb",
	},
	{
		text = "Brightness",
		selected = false,
		min = 1,
		max = 10,
		step = 1,
		value = 5, -- Will be updated in load() based on state.rgbBrightness
	},
	{
		text = "Speed",
		selected = false,
		min = 1,
		max = 10,
		step = 1,
		value = 5, -- Will be updated in load() based on state.rgbSpeed
	},
}

-- Filtered list of visible buttons
local visibleButtons = {}

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

-- Update UI state based on current state values and filter visible buttons
local function updateButtonStates()
	-- Set the correct current option index based on state.rgbMode
	for i, option in ipairs(RGB_MODES) do
		if option == state.rgbMode then
			ALL_BUTTONS[1].currentOption = i
			break
		end
	end

	-- Update brightness and speed values
	ALL_BUTTONS[3].value = state.rgbBrightness
	ALL_BUTTONS[4].value = state.rgbSpeed

	-- Clear visible buttons
	visibleButtons = {}

	-- Always add the Mode button
	table.insert(visibleButtons, ALL_BUTTONS[1])
	visibleButtons[1].selected = true

	-- Add Brightness second if it should be visible
	if isBrightnessVisible() then
		local brightnessBtn = ALL_BUTTONS[3]
		brightnessBtn.selected = false
		table.insert(visibleButtons, brightnessBtn)
	end

	-- Add Color third if it should be visible
	if isColorVisible() then
		local colorBtn = ALL_BUTTONS[2]
		colorBtn.selected = false
		table.insert(visibleButtons, colorBtn)
	end

	-- Add Speed last if it should be visible
	if isSpeedVisible() then
		local speedBtn = ALL_BUTTONS[4]
		speedBtn.selected = false
		table.insert(visibleButtons, speedBtn)
	end
end

function rgb.load()
	updateButtonStates()
end

function rgb.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("rgb lighting")

	love.graphics.setFont(state.fonts.body)

	-- Calculate start Y position for the list
	local startY = header.getContentStartY()

	local scrollPosition = list.getScrollPosition()

	local result = list.draw({
		items = visibleButtons,
		startY = startY,
		itemHeight = button.calculateHeight(),
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = state.screenHeight,
		drawItemFunc = function(item, _index, y)
			if item.colorKey then
				local colorValue = state.getColorValue(item.colorKey)
				button.drawWithColorPreview(
					item.text,
					item.selected,
					0,
					y,
					state.screenWidth,
					colorValue,
					false,
					fonts.loaded.monoBody
				)
			elseif item.options then
				-- For items with multiple options
				local currentValue = item.options[item.currentOption]
				button.drawWithIndicators(item.text, 0, y, item.selected, false, state.screenWidth, currentValue)
			elseif item.min ~= nil and item.max ~= nil then
				-- For numeric ranges
				local currentValue = item.value or item.min
				button.drawWithIndicators(
					item.text,
					0,
					y,
					item.selected,
					false,
					state.screenWidth,
					tostring(currentValue)
				)
			elseif item.rgbLighting then
				button.drawWithTextPreview(item.text, 0, y, item.selected, state.screenWidth, state.rgbMode)
			else
				button.draw(item.text, 0, y, item.selected, state.screenWidth)
			end
		end,
	})

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Change value" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Save" },
	})
end

function rgb.update(_dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Handle B button to return to menu
	if virtualJoystick.isGamepadPressedWithDelay("b") and switchScreen then
		switchScreen(MENU_SCREEN)
		return
	end

	-- Use the enhanced list input handler for navigation and selection
	local result = list.handleInput({
		items = visibleButtons,
		virtualJoystick = virtualJoystick,

		-- Handle button selection (A button)
		handleItemSelect = function(btn)
			savedSelectedIndex = list.getSelectedIndex()

			if btn.colorKey and switchScreen then
				-- Open color picker for this color
				state.activeColorContext = btn.colorKey
				state.previousScreen = "rgb" -- Set previous screen to return to
				switchScreen(COLOR_PICKER_SCREEN)
			end
		end,

		-- Handle option cycling (left/right d-pad)
		handleItemOption = function(btn, direction)
			local changed = false

			if btn.options then
				-- Calculate new option index
				local newIndex = btn.currentOption + direction

				-- Wrap around if needed
				if newIndex < 1 then
					newIndex = #btn.options
				elseif newIndex > #btn.options then
					newIndex = 1
				end

				-- Update current option
				btn.currentOption = newIndex

				-- Update state with selected option
				state.rgbMode = btn.options[btn.currentOption]

				-- Update visible buttons based on new mode
				updateButtonStates()

				-- Apply RGB settings immediately
				if state.hasRGBSupport then
					rgbUtils.updateConfig()
				end
				changed = true
			elseif btn.min ~= nil and btn.max ~= nil then
				-- Handle brightness or speed adjustment
				local isSpeed = btn.text == "Speed"

				local newValue = btn.value + (direction * btn.step)

				-- Clamp to min/max
				if newValue < btn.min then
					newValue = btn.min
				elseif newValue > btn.max then
					newValue = btn.max
				end

				-- Update button value
				btn.value = newValue

				-- Update state
				if isSpeed then
					state.rgbSpeed = newValue
				else
					state.rgbBrightness = newValue
				end

				-- Apply RGB settings immediately
				if state.hasRGBSupport then
					rgbUtils.updateConfig()
				end
				changed = true
			end

			return changed
		end,
	})
end

function rgb.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function rgb.onEnter()
	-- Update button states based on current settings
	updateButtonStates()

	-- Reset list state and restore selection
	scrollPosition = list.onScreenEnter("rgb", visibleButtons, savedSelectedIndex)

	-- Apply RGB settings in case they were changed in the color picker
	if state.hasRGBSupport then
		rgbUtils.updateConfig()
	end
end

function rgb.onExit()
	-- Save the current selected index
	savedSelectedIndex = list.onScreenExit()

	-- No need to restore RGB settings here - let them persist while previewing
end

return rgb
