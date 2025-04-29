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

-- List handling variables
local scrollPosition = 0
local visibleCount = 0

-- Buttons in this screen
local BUTTONS = {
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

-- Helper function to check if RGB color should be disabled based on mode
local function isColorDisabled()
	local currentMode = state.rgbMode
	return currentMode == "Off" or currentMode == "Multi Rainbow" or currentMode == "Mono Rainbow"
end

-- Helper function to check if RGB speed should be disabled based on mode
local function isSpeedDisabled()
	local currentMode = state.rgbMode
	return currentMode == "Off"
		or currentMode == "Solid"
		or currentMode == "Fast Breathing"
		or currentMode == "Medium Breathing"
		or currentMode == "Slow Breathing"
end

-- Helper function to check if RGB brightness should be disabled based on mode
local function isBrightnessDisabled()
	local currentMode = state.rgbMode
	return currentMode == "Off"
end

-- Update UI state based on current state values
local function updateButtonStates()
	-- Set the correct current option index based on state.rgbMode
	for i, option in ipairs(RGB_MODES) do
		if option == state.rgbMode then
			BUTTONS[1].currentOption = i
			break
		end
	end

	-- Update brightness and speed values
	BUTTONS[3].value = state.rgbBrightness
	BUTTONS[4].value = state.rgbSpeed

	-- Update disabled states
	BUTTONS[2].disabled = isColorDisabled()
	BUTTONS[3].disabled = isBrightnessDisabled()
	BUTTONS[4].disabled = isSpeedDisabled()
end

function rgb.load()
	updateButtonStates()
end

function rgb.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("RGB lighting")

	love.graphics.setFont(state.fonts.body)

	-- Calculate start Y position for the list
	local startY = header.HEIGHT + button.BUTTON.PADDING

	-- Draw the list using our list component
	local result = list.draw({
		items = BUTTONS,
		startY = startY,
		itemHeight = button.BUTTON.HEIGHT,
		itemPadding = button.BUTTON.PADDING,
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
					item.disabled,
					fonts.loaded.monoBody
				)
			elseif item.options then
				-- For items with multiple options
				local currentValue = item.options[item.currentOption]
				button.drawWithIndicators(
					item.text,
					0,
					y,
					item.selected,
					item.disabled,
					state.screenWidth,
					currentValue
				)
			elseif item.min ~= nil and item.max ~= nil then
				-- For numeric ranges
				local currentValue = item.value or item.min
				button.drawWithIndicators(
					item.text,
					0,
					y,
					item.selected,
					item.disabled,
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

	visibleCount = result.visibleCount

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Change value" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function rgb.update(_dt)
	local virtualJoystick = require("input").virtualJoystick

	if not state.canProcessInput() then
		return
	end

	-- Handle navigation
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		local direction = virtualJoystick:isGamepadDown("dpup") and -1 or 1

		-- Use list navigation helper
		local selectedIndex = list.navigate(BUTTONS, direction)

		-- Update scroll position
		scrollPosition = list.adjustScrollPosition({
			selectedIndex = selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleCount,
		})

		state.resetInputTimer()
	end

	-- Handle left/right to change option values
	if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
		local direction = virtualJoystick:isGamepadDown("dpleft") and -1 or 1

		for _, btn in ipairs(BUTTONS) do
			if btn.selected then
				if btn.options and not btn.disabled then
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

					-- Update disabled states based on new mode
					updateButtonStates()

					-- Apply RGB settings immediately
					rgbUtils.updateConfig()

					state.resetInputTimer()
					break
				elseif btn.min ~= nil and btn.max ~= nil and not btn.disabled then
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
					rgbUtils.updateConfig()

					state.resetInputTimer()
					break
				end
			end
		end
	end

	-- Handle B button to return to menu
	if virtualJoystick:isGamepadDown("b") and switchScreen then
		switchScreen(MENU_SCREEN)
		state.resetInputTimer()
		state.forceInputDelay(0.2) -- Add extra delay when switching screens
	end

	-- Handle A button to go to color picker for RGB color
	if virtualJoystick:isGamepadDown("a") then
		for _, btn in ipairs(BUTTONS) do
			if btn.selected and btn.colorKey and switchScreen and not btn.disabled then
				-- Open color picker for this color
				state.activeColorContext = btn.colorKey
				state.previousScreen = "rgb" -- Set previous screen to return to
				switchScreen(COLOR_PICKER_SCREEN)
				state.resetInputTimer()
				state.forceInputDelay(0.2) -- Add extra delay when switching screens
			end
		end
	end
end

function rgb.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function rgb.onEnter()
	-- Update button states based on current settings
	updateButtonStates()

	-- Apply RGB settings in case they were changed in the color picker
	rgbUtils.updateConfig()
end

function rgb.onExit()
	-- Called when leaving this screen
	-- No need to restore RGB settings here - let them persist while previewing
end

return rgb
