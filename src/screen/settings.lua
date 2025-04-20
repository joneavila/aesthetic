--- Settings screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local input = require("input")
local presets = require("utils.presets")
local rgbUtils = require("utils.rgb")

-- Screen module
local settings = {}

-- Screen switching
local switchScreen = nil

-- Constants for styling
local HEADER_HEIGHT = 50
local HEADER_PADDING = 20

-- Button constants
local BUTTONS = {
	{ text = "Save preset", selected = true },
	{ text = "Load preset", selected = false },
	{ text = "About", selected = false },
}

-- Button properties
local BUTTON = {
	HEIGHT = 50,
	WIDTH = 0, -- Will be calculated in load()
	PADDING = 20,
	START_Y = 20,
}

-- Popup state
local popupVisible = false
local popupMessage = ""
local popupButtons = {}
local popupMode = "none" -- none, save_success, load_success, error
local presetName = "preset1" -- Default preset name

-- Helper function to generate a unique preset name
local function generatePresetName()
	-- Get list of existing presets
	local existingPresets = presets.listPresets()

	-- Find the highest preset number
	local highestNumber = 0
	for _, name in ipairs(existingPresets) do
		-- Extract number from preset name (if it follows the "Preset N" format)
		local number = name:match("^Preset%s*(%d+)$")
		if number then
			number = tonumber(number)
			if number and number > highestNumber then
				highestNumber = number
			end
		end
	end

	-- Generate a new name with the next number
	return "Preset " .. (highestNumber + 1)
end

function settings.load()
	-- Calculate button width based on screen dimensions
	BUTTON.WIDTH = state.screenWidth - (BUTTON.PADDING * 2)
end

function settings.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- Draw a button with the given properties
local function drawButton(button, x, y, selected)
	-- Define consistent padding for text
	local leftPadding = 20
	local rightPadding = 20

	-- For selected buttons, draw the background to the edge
	local drawWidth = BUTTON.WIDTH

	if selected then
		-- Selected state: Background extends to full width
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle("fill", 0, y, state.screenWidth, BUTTON.HEIGHT, 0)
	end

	-- Draw button text
	love.graphics.setFont(state.fonts.body)
	local textHeight = state.fonts.body:getHeight()

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.print(button.text, x + leftPadding, y + (BUTTON.HEIGHT - textHeight) / 2)
end

-- Show a popup with the given message and buttons
local function showPopup(message, buttons)
	popupVisible = true
	popupMessage = message
	popupButtons = buttons or { { text = "Close", selected = true } }
end

-- Draw the popup overlay
local function drawPopup()
	-- Semi-transparent background overlay
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.9)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)

	-- Calculate popup dimensions based on text
	local padding = 40
	local maxWidth = state.screenWidth * 0.9 -- Maximum width is 90% of screen width
	local minWidth = math.min(state.screenWidth * 0.8, maxWidth)
	local minHeight = state.screenHeight * 0.3

	-- Set font for text measurement
	love.graphics.setFont(state.fonts.body)

	-- Calculate available width for text
	local availableTextWidth = minWidth - (padding * 2)

	-- Get wrapped text info
	local _, lines = state.fonts.body:getWrap(popupMessage, availableTextWidth)
	local textHeight = #lines * state.fonts.body:getHeight()

	-- Calculate final popup dimensions
	local popupWidth = minWidth -- Always use the minimum width to ensure consistent wrapping
	local buttonHeight = 40
	local buttonSpacing = 20

	-- Calculate extra height needed for buttons
	local buttonsExtraHeight = buttonHeight + padding
	local popupHeight = math.max(minHeight, textHeight + (padding * 2) + buttonsExtraHeight)

	local x = (state.screenWidth - popupWidth) / 2
	local y = (state.screenHeight - popupHeight) / 2

	-- Draw popup background
	love.graphics.setColor(colors.ui.background)
	love.graphics.rectangle("fill", x, y, popupWidth, popupHeight, 10)

	-- Draw popup border with surface color
	love.graphics.setColor(colors.ui.surface)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, popupWidth, popupHeight, 10)

	-- Draw message with wrapping
	love.graphics.setColor(colors.ui.foreground)
	local textY = y + padding
	love.graphics.printf(popupMessage, x + padding, textY, availableTextWidth, "center")

	-- Draw buttons
	local buttonWidth = math.min(200, popupWidth * 0.4) -- Width is either 200px or 40% of popup width
	local buttonY = y + popupHeight - buttonHeight - padding
	local spacing = 20
	local totalButtonsWidth = (#popupButtons * buttonWidth) + ((#popupButtons - 1) * spacing)
	local buttonX = x + (popupWidth - totalButtonsWidth) / 2 -- Position relative to popup

	for _, button in ipairs(popupButtons) do
		local isSelected = button.selected

		-- Draw button background
		love.graphics.setColor(isSelected and colors.ui.surface or colors.ui.background)
		love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

		-- Draw button outline
		love.graphics.setLineWidth(isSelected and 4 or 2)
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5)

		-- Draw button text
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.printf(
			button.text,
			buttonX,
			buttonY + (buttonHeight - state.fonts.body:getHeight()) / 2,
			buttonWidth,
			"center"
		)

		buttonX = buttonX + buttonWidth + spacing
	end
end

function settings.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	-- Draw header with title
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.95)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, HEADER_HEIGHT)

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(state.fonts.bodyBold)
	love.graphics.print("Settings", HEADER_PADDING, (HEADER_HEIGHT - state.fonts.bodyBold:getHeight()) / 2)

	-- Draw buttons
	for i, button in ipairs(BUTTONS) do
		local y = HEADER_HEIGHT + BUTTON.START_Y + (i - 1) * (BUTTON.HEIGHT + BUTTON.PADDING)
		drawButton(button, BUTTON.PADDING, y, button.selected)
	end

	-- Draw popup if visible
	if popupVisible then
		drawPopup()
	end

	-- Draw controls at bottom of screen
	controls.draw({
		{ button = "d_pad", text = "Navigate" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function settings.update(_dt)
	local virtualJoystick = input.virtualJoystick

	if not state.canProcessInput() then
		return
	end

	-- Handle popup if visible
	if popupVisible then
		if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
			-- Toggle button selection
			for _, button in ipairs(popupButtons) do
				button.selected = not button.selected
			end
			state.resetInputTimer()
		end

		if virtualJoystick:isGamepadDown("a") then
			-- Handle button selection
			for _, button in ipairs(popupButtons) do
				if button.selected then
					if popupMode == "save_input" and button.text == "Save" then
						-- Save the preset
						local success = presets.savePreset(presetName)
						if success then
							popupMode = "save_success"
							showPopup("Preset saved successfully!", { { text = "Close", selected = true } })
						else
							popupMode = "error"
							showPopup("Failed to save preset.", { { text = "Close", selected = true } })
						end
					else
						-- Close the popup
						popupVisible = false
						popupMode = "none"
					end
					break
				end
			end
			state.resetInputTimer()
			return
		end

		-- Exit popup with B button
		if virtualJoystick:isGamepadDown("b") then
			popupVisible = false
			popupMode = "none"
			state.resetInputTimer()
			return
		end

		return -- Don't process other inputs while popup is visible
	end

	-- Handle D-pad navigation
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		local direction = virtualJoystick:isGamepadDown("dpup") and -1 or 1
		local selectedIndex = 1

		-- Find currently selected button
		for i, button in ipairs(BUTTONS) do
			if button.selected then
				selectedIndex = i
				button.selected = false
				break
			end
		end

		-- Calculate new selected index with wrap-around
		selectedIndex = selectedIndex + direction
		if selectedIndex < 1 then
			selectedIndex = #BUTTONS
		elseif selectedIndex > #BUTTONS then
			selectedIndex = 1
		end

		-- Update button selection
		BUTTONS[selectedIndex].selected = true
		state.resetInputTimer()
	end

	-- Handle button selection (A button)
	if virtualJoystick:isGamepadDown("a") then
		for _, button in ipairs(BUTTONS) do
			if button.selected then
				if button.text == "Save preset" then
					presetName = generatePresetName()

					-- Show save preset popup
					popupMode = "save_input"
					showPopup(
						"Save current settings as preset?",
						{ { text = "Cancel", selected = false }, { text = "Save", selected = true } }
					)
				elseif button.text == "Load preset" then
					-- Navigate to the load preset screen
					if switchScreen then
						switchScreen("load_preset")
						state.resetInputTimer()
						state.forceInputDelay(0.2) -- Add extra delay when switching screens
					end
				elseif button.text == "About" then
					-- Navigate to the about screen
					if switchScreen then
						switchScreen("about")
						state.resetInputTimer()
						state.forceInputDelay(0.2) -- Add extra delay when switching screens
					end
				end
				break
			end
		end
		state.resetInputTimer()
	end

	-- Return to menu with B button
	if virtualJoystick:isGamepadDown("b") then
		if switchScreen then
			switchScreen("menu")
		end
		state.resetInputTimer()
	end
end

-- Handle cleanup when leaving this screen
function settings.onExit()
	-- Reset popup state
	popupVisible = false
	popupMode = "none"
end

return settings
