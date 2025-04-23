--- Settings screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local input = require("input")
local presets = require("utils.presets")
local header = require("ui.header")
local background = require("ui.background")

-- Screen module
local settings = {}

-- Screen switching
local switchScreen = nil

-- Button constants
local BUTTONS = {
	{ text = "Save theme preset", selected = true },
	{ text = "Load theme preset", selected = false },
	{ text = "About", selected = false },
}

-- Button properties
local BUTTON = {
	HEIGHT = 50,
	WIDTH = 0, -- Will be calculated in load()
	PADDING = 20,
	START_Y = 20,
}

-- Modal state
local modalVisible = false
local modalMessage = ""
local modalButtons = {}
local modalMode = "none" -- none, save_success, load_success, error
local presetName = "preset1" -- Default preset name

-- Helper function to generate a unique preset name
local function generatePresetName()
	local currentTime = os.time()
	local dateString = os.date("%B %d, %Y %I:%M:%S%p", currentTime)
	return dateString
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

-- Show a modal with the given message and buttons
local function showModal(message, buttons)
	modalVisible = true
	modalMessage = message
	modalButtons = buttons or { { text = "Close", selected = true } }
end

-- Draw the modal overlay
local function drawModal()
	-- Semi-transparent background overlay
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.9)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)

	-- Calculate modal dimensions based on text
	local padding = 40
	local maxWidth = state.screenWidth * 0.9 -- Maximum width is 90% of screen width
	local minWidth = math.min(state.screenWidth * 0.8, maxWidth)
	local minHeight = state.screenHeight * 0.3

	-- Set font for text measurement
	love.graphics.setFont(state.fonts.body)

	-- Calculate available width for text
	local availableTextWidth = minWidth - (padding * 2)

	-- Get wrapped text info
	local _, lines = state.fonts.body:getWrap(modalMessage, availableTextWidth)
	local textHeight = #lines * state.fonts.body:getHeight()

	-- Calculate final modal dimensions
	local modalWidth = minWidth -- Always use the minimum width to ensure consistent wrapping
	local buttonHeight = 40

	-- Calculate extra height needed for buttons
	local buttonsExtraHeight = buttonHeight + padding
	local modalHeight = math.max(minHeight, textHeight + (padding * 2) + buttonsExtraHeight)

	local x = (state.screenWidth - modalWidth) / 2
	local y = (state.screenHeight - modalHeight) / 2

	-- Draw modal background
	love.graphics.setColor(colors.ui.background)
	love.graphics.rectangle("fill", x, y, modalWidth, modalHeight, 10)

	-- Draw modal border with surface color
	love.graphics.setColor(colors.ui.surface)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, modalWidth, modalHeight, 10)

	-- Draw message with wrapping
	love.graphics.setColor(colors.ui.foreground)
	local textY = y + padding
	love.graphics.printf(modalMessage, x + padding, textY, availableTextWidth, "center")

	-- Draw buttons
	local buttonWidth = math.min(200, modalWidth * 0.4) -- Width is either 200px or 40% of modal width
	local buttonY = y + modalHeight - buttonHeight - padding
	local spacing = 20
	local totalButtonsWidth = (#modalButtons * buttonWidth) + ((#modalButtons - 1) * spacing)
	local buttonX = x + (modalWidth - totalButtonsWidth) / 2 -- Position relative to modal

	for _, button in ipairs(modalButtons) do
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
	background.draw()

	-- Draw header with title
	header.draw("Settings")

	-- Draw buttons
	for i, button in ipairs(BUTTONS) do
		local y = header.HEIGHT + BUTTON.START_Y + (i - 1) * (BUTTON.HEIGHT + BUTTON.PADDING)
		drawButton(button, BUTTON.PADDING, y, button.selected)
	end

	-- Draw modal if visible
	if modalVisible then
		drawModal()
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

	-- Handle modal if visible
	if modalVisible then
		if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
			-- Toggle button selection
			for _, button in ipairs(modalButtons) do
				button.selected = not button.selected
			end
			state.resetInputTimer()
		end

		if virtualJoystick:isGamepadDown("a") then
			-- Handle button selection
			for _, button in ipairs(modalButtons) do
				if button.selected then
					if modalMode == "save_input" and button.text == "Save" then
						-- Save the preset
						local success = presets.savePreset(presetName)
						if success then
							modalMode = "save_success"
							showModal("Preset saved successfully!", { { text = "Close", selected = true } })
						else
							modalMode = "error"
							showModal("Failed to save preset.", { { text = "Close", selected = true } })
						end
					else
						-- Close the modal
						modalVisible = false
						modalMode = "none"
					end
					break
				end
			end
			state.resetInputTimer()
			return
		end

		-- Exit modal with B button
		if virtualJoystick:isGamepadDown("b") then
			modalVisible = false
			modalMode = "none"
			state.resetInputTimer()
			return
		end

		return -- Don't process other inputs while modal is visible
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
				if button.text == "Save theme preset" then
					presetName = generatePresetName()

					-- Show save preset modal
					modalMode = "save_input"
					showModal(
						"Save current theme settings as preset?",
						{ { text = "Cancel", selected = false }, { text = "Save", selected = true } }
					)
				elseif button.text == "Load theme preset" then
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
	-- Reset modal state
	modalVisible = false
	modalMode = "none"
end

return settings
