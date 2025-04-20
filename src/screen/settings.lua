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

-- Button constants
local BUTTONS = {
	{ text = "Save preset", selected = true },
	{ text = "Load preset", selected = false },
}

-- Button properties
local BUTTON = {
	HEIGHT = 60,
	WIDTH = 0, -- Will be calculated in load()
	PADDING = 20,
	START_Y = 100,
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
	local font = love.graphics.getFont()
	local cornerRadius = 8

	if selected then
		-- Selected state: accent background, background text
		love.graphics.setColor(colors.ui.accent)
		love.graphics.rectangle("fill", x, y, BUTTON.WIDTH, BUTTON.HEIGHT, cornerRadius)

		-- Draw text
		love.graphics.setColor(colors.ui.background)
		love.graphics.print(button.text, x + BUTTON.PADDING, y + (BUTTON.HEIGHT - font:getHeight()) / 2)
	else
		-- Unselected state: background with surface outline
		love.graphics.setColor(colors.ui.background)
		love.graphics.rectangle("fill", x, y, BUTTON.WIDTH, BUTTON.HEIGHT, cornerRadius)

		-- Draw outline
		love.graphics.setColor(colors.ui.surface)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", x, y, BUTTON.WIDTH, BUTTON.HEIGHT, cornerRadius)

		-- Draw text
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(button.text, x + BUTTON.PADDING, y + (BUTTON.HEIGHT - font:getHeight()) / 2)
	end
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
	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)

	-- Popup container
	local popupWidth = math.min(state.screenWidth * 0.8, 600)
	local popupHeight = 200
	local popupX = (state.screenWidth - popupWidth) / 2
	local popupY = (state.screenHeight - popupHeight) / 2

	-- Popup background
	love.graphics.setColor(colors.ui.background)
	love.graphics.rectangle("fill", popupX, popupY, popupWidth, popupHeight, 12)

	-- Popup border
	love.graphics.setColor(colors.ui.accent)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", popupX, popupY, popupWidth, popupHeight, 12)

	-- Popup message
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(state.fonts.body)

	-- Center the message text
	local messageWidth = state.fonts.body:getWidth(popupMessage)
	local messageX = popupX + (popupWidth - messageWidth) / 2
	love.graphics.print(popupMessage, messageX, popupY + 40)

	-- Popup buttons
	local buttonWidth = popupWidth * 0.4
	local buttonHeight = 50
	local buttonY = popupY + popupHeight - buttonHeight - 20

	-- Calculate button positions based on how many buttons we have
	local buttonSpacing = 20
	local totalButtonsWidth = (#popupButtons * buttonWidth) + ((#popupButtons - 1) * buttonSpacing)
	local startX = popupX + (popupWidth - totalButtonsWidth) / 2

	for i, button in ipairs(popupButtons) do
		local buttonX = startX + (i - 1) * (buttonWidth + buttonSpacing)

		-- Draw button background
		if button.selected then
			love.graphics.setColor(colors.ui.accent)
			love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 8)
			love.graphics.setColor(colors.ui.background)
		else
			love.graphics.setColor(colors.ui.surface)
			love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 8)
			love.graphics.setColor(colors.ui.foreground)
		end

		-- Draw button text
		local textWidth = state.fonts.body:getWidth(button.text)
		local textX = buttonX + (buttonWidth - textWidth) / 2
		local textY = buttonY + (buttonHeight - state.fonts.body:getHeight()) / 2
		love.graphics.print(button.text, textX, textY)
	end
end

function settings.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	-- Draw heading
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(state.fonts.header)
	local headingText = "Settings"
	local headingX = BUTTON.PADDING
	local headingY = BUTTON.PADDING
	love.graphics.print(headingText, headingX, headingY)

	-- Draw buttons
	for i, button in ipairs(BUTTONS) do
		local y = BUTTON.START_Y + (i - 1) * (BUTTON.HEIGHT + BUTTON.PADDING)
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
