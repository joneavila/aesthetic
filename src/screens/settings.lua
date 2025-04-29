--- Settings screen
local love = require("love")
local state = require("state")
local controls = require("controls")
local input = require("input")
local presets = require("utils.presets")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local modal = require("ui.modal")
local button = require("ui.button")

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

-- Scrolling variables
local scrollPosition = 0
local visibleCount = 0

-- Modal state tracking
local modalMode = "none" -- none, save_success, load_success, error, save_input
local presetName = nil

-- Helper function to generate a unique preset name
local function generatePresetName()
	local currentTime = os.time()
	local dateString = os.date("%B %d, %Y %I:%M:%S%p", currentTime)
	return dateString
end

function settings.load()
	-- Nothing to initialize for buttons as list component handles sizing
end

function settings.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function settings.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("Settings")

	-- Calculate starting Y position for the list
	local startY = header.getHeight() + button.BUTTON.PADDING

	-- Set font for consistent sizing
	love.graphics.setFont(state.fonts.body)

	-- Draw the buttons using our list component
	local result = list.draw({
		items = BUTTONS,
		startY = startY,
		itemHeight = button.BUTTON.HEIGHT,
		itemPadding = button.BUTTON.PADDING,
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = state.screenHeight,
		drawItemFunc = function(item, _index, y)
			-- Settings has simple buttons, so just use the standard drawing
			button.draw(item.text, 0, y, item.selected, state.screenWidth)
		end,
	})

	-- Store the visible count for navigation
	visibleCount = result.visibleCount

	-- Draw modal if visible (now handled by modal component)
	if modal.isModalVisible() then
		modal.drawModal(state.screenWidth, state.screenHeight, state.fonts.body)
	end

	-- Draw controls at bottom of screen
	controls.draw({
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
	if modal.isModalVisible() then
		if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
			-- Toggle button selection
			local modalButtons = modal.getModalButtons()
			for _, btn in ipairs(modalButtons) do
				btn.selected = not btn.selected
			end
			modal.setModalButtons(modalButtons)
			state.resetInputTimer()
		end

		if virtualJoystick:isGamepadDown("a") then
			-- Handle button selection
			local modalButtons = modal.getModalButtons()
			for _, btn in ipairs(modalButtons) do
				if btn.selected then
					if modalMode == "save_input" and btn.text == "Save" then
						-- Save the preset
						local success = presets.savePreset(presetName)
						if success then
							modalMode = "save_success"
							modal.showModal("Preset saved successfully!", { { text = "Close", selected = true } })
						else
							modalMode = "error"
							modal.showModal("Failed to save preset.", { { text = "Close", selected = true } })
						end
					else
						-- Close the modal
						modal.hideModal()
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
			modal.hideModal()
			modalMode = "none"
			state.resetInputTimer()
			return
		end

		return -- Don't process other inputs while modal is visible
	end

	-- Handle D-pad navigation
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

	-- Handle button selection (A button)
	if virtualJoystick:isGamepadDown("a") then
		for _, btn in ipairs(BUTTONS) do
			if btn.selected then
				if btn.text == "Save theme preset" then
					presetName = generatePresetName()

					-- Show save preset modal
					modalMode = "save_input"
					modal.showModal(
						"Save current theme settings as preset?",
						{ { text = "Cancel", selected = false }, { text = "Save", selected = true } }
					)
				elseif btn.text == "Load theme preset" then
					-- Navigate to the load preset screen
					if switchScreen then
						switchScreen("load_preset")
						state.resetInputTimer()
						state.forceInputDelay(0.2) -- Add extra delay when switching screens
					end
				elseif btn.text == "About" then
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
			switchScreen("main_menu")
		end
		state.resetInputTimer()
	end
end

-- Handle cleanup when leaving this screen
function settings.onExit()
	-- Reset modal state
	modal.hideModal()
	modalMode = "none"
end

return settings
