--- RGB lighting settings screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local colorUtils = require("utils.color")
local rgbUtils = require("utils.rgb")
local ui_button = require("ui.button")
local header = require("ui.header")
local background = require("ui.background")

-- Module table to export public functions
local rgb = {}

-- Screen switching
local switchScreen = nil
local MENU_SCREEN = "menu"
local COLOR_PICKER_SCREEN = "color_picker"

-- Constants for styling
local HEADER_HEIGHT = 50

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

-- Button dimensions and position
local BUTTON = {
	WIDTH = nil, -- Will be calculated in load()
	HEIGHT = 50,
	PADDING = 20,
	START_Y = nil, -- Will be calculated in load()
	COLOR_DISPLAY_SIZE = 30,
}

-- Buttons in this screen
local BUTTONS = {
	{
		text = "Mode",
		selected = true,
		value = state.rgbMode,
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
		value = state.rgbBrightness,
		min = 1,
		max = 10,
		step = 1,
	},
	{
		text = "Speed",
		selected = false,
		value = state.rgbSpeed,
		min = 1,
		max = 10,
		step = 1,
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

function rgb.load()
	BUTTON.WIDTH = state.screenWidth - (BUTTON.PADDING * 2)
	BUTTON.START_Y = BUTTON.PADDING

	-- Set the correct current option index based on state.rgbMode
	for i, option in ipairs(RGB_MODES) do
		if option == state.rgbMode then
			BUTTONS[1].currentOption = i
			break
		end
	end
end

function rgb.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("RGB lighting")

	-- Set font to body font to match menu.lua
	love.graphics.setFont(state.fonts.body)

	-- Draw each button
	for i, button in ipairs(BUTTONS) do
		local y = HEADER_HEIGHT + BUTTON.START_Y + (i - 1) * (BUTTON.HEIGHT + BUTTON.PADDING)

		-- Check if button should be disabled
		local disabled = (button.text == "Color" and isColorDisabled())
			or (button.text == "Speed" and isSpeedDisabled())
			or (button.text == "Brightness" and isBrightnessDisabled())

		-- Set disabled state in button data for UI components
		button.disabled = disabled

		-- Draw current option value on the right side for Mode button
		if button.options then
			local currentValue = button.options[button.currentOption]
			ui_button.drawWithTriangles(
				button,
				0,
				y,
				button.selected,
				state.screenWidth,
				state.fonts.body,
				currentValue
			)

		-- Draw color preview for Color button
		elseif button.colorKey then
			local colorValue = state.getColorValue(button.colorKey)
			local previewSize = BUTTON.COLOR_DISPLAY_SIZE
			local previewX = state.screenWidth - BUTTON.PADDING - previewSize
			local previewY = y + (BUTTON.HEIGHT - previewSize) / 2

			-- Draw button background
			if button.selected then
				love.graphics.setColor(
					colors.ui.surface[1],
					colors.ui.surface[2],
					colors.ui.surface[3],
					disabled and 0.5 or 1
				)
				love.graphics.rectangle("fill", 0, y, state.screenWidth, BUTTON.HEIGHT)
			end

			-- Draw button text
			love.graphics.setColor(
				colors.ui.foreground[1],
				colors.ui.foreground[2],
				colors.ui.foreground[3],
				disabled and 0.5 or 1
			)
			love.graphics.print(button.text, BUTTON.PADDING, y + (BUTTON.HEIGHT - state.fonts.body:getHeight()) / 2)

			-- Draw hex code
			love.graphics.setFont(state.fonts.monoBody)
			local hexCode = colorValue
			local hexWidth = state.fonts.monoBody:getWidth(hexCode)
			love.graphics.print(
				hexCode,
				previewX - hexWidth - 10,
				y + (BUTTON.HEIGHT - state.fonts.monoBody:getHeight()) / 2
			)
			love.graphics.setFont(state.fonts.body)

			-- Draw color preview
			local r, g, b = colorUtils.hexToRgb(colorValue)
			love.graphics.setColor(r, g, b, disabled and 0.5 or 1)
			love.graphics.rectangle("fill", previewX, previewY, previewSize, previewSize, 5)

			-- Draw outline
			love.graphics.setColor(
				colors.ui.foreground[1],
				colors.ui.foreground[2],
				colors.ui.foreground[3],
				disabled and 0.5 or 1
			)
			love.graphics.setLineWidth(1)
			love.graphics.rectangle("line", previewX, previewY, previewSize, previewSize, 5)

		-- Draw brightness/speed value with triangles
		elseif button.min ~= nil and button.max ~= nil then
			local currentValue = button.text == "Brightness" and state.rgbBrightness or state.rgbSpeed
			local valueText = tostring(currentValue)
			ui_button.drawWithTriangles(button, 0, y, button.selected, state.screenWidth, state.fonts.body, valueText)
		end
	end

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Navigate / Change value" },
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

		-- Find currently selected button
		local currentIndex = 1
		for i, button in ipairs(BUTTONS) do
			if button.selected then
				currentIndex = i
				button.selected = false
				break
			end
		end

		-- Calculate new index with wrapping
		local newIndex = currentIndex + direction
		if newIndex < 1 then
			newIndex = #BUTTONS
		elseif newIndex > #BUTTONS then
			newIndex = 1
		end

		-- Select new button
		BUTTONS[newIndex].selected = true
		state.resetInputTimer()
	end

	-- Handle left/right to change option values
	if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
		local direction = virtualJoystick:isGamepadDown("dpleft") and -1 or 1

		for _, button in ipairs(BUTTONS) do
			if button.selected then
				if button.options then
					-- Calculate new option index
					local newIndex = button.currentOption + direction

					-- Wrap around if needed
					if newIndex < 1 then
						newIndex = #button.options
					elseif newIndex > #button.options then
						newIndex = 1
					end

					-- Update current option
					button.currentOption = newIndex

					-- Update state with selected option
					state.rgbMode = button.options[button.currentOption]

					-- Apply RGB settings immediately
					rgbUtils.updateConfig()

					state.resetInputTimer()
					break
				elseif button.min ~= nil and button.max ~= nil then
					-- Handle brightness or speed adjustment
					local isSpeed = button.text == "Speed"
					local isBrightness = button.text == "Brightness"

					-- Skip if speed is disabled
					if (isSpeed and isSpeedDisabled()) or (isBrightness and isBrightnessDisabled()) then
						break
					end

					local currentValue = isSpeed and state.rgbSpeed or state.rgbBrightness
					local newValue = currentValue + (direction * button.step)

					-- Clamp to min/max
					if newValue < button.min then
						newValue = button.min
					elseif newValue > button.max then
						newValue = button.max
					end

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
		for _, button in ipairs(BUTTONS) do
			if button.selected and button.colorKey and switchScreen and not isColorDisabled() then
				-- Open color picker for this color, but only if not disabled
				state.activeColorContext = button.colorKey
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
	-- Set the correct current option index based on state.rgbMode
	for i, option in ipairs(RGB_MODES) do
		if option == state.rgbMode then
			BUTTONS[1].currentOption = i
			break
		end
	end

	-- Apply RGB settings in case they were changed in the color picker
	rgbUtils.updateConfig()
end

function rgb.onExit()
	-- Called when leaving this screen
	-- No need to restore RGB settings here - let them persist while previewing
end

return rgb
