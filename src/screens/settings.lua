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
local logger = require("utils.logger")
local manage_themes = require("screens.manage_themes")

-- Screen module
local settings = {}

-- Screen switching
local switchScreen = nil

-- Button constants
local BUTTONS = {
	-- { text = "Save theme preset", selected = true }, -- Disabled until the feature is more complete
	{ text = "Load Theme Preset", selected = true },
	{ text = "Manage Themes", selected = false },
	{ text = "About", selected = false },
}

-- Last selected index for persistence
local lastSelectedIndex = 1

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
	-- Reset scroll position
	list.resetScrollPosition()

	-- Ensure initial button selection state
	for i, btn in ipairs(BUTTONS) do
		btn.selected = (i == 1)
	end
end

function settings.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function settings.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("settings")

	-- Calculate start Y position for the list
	local startY = header.getContentStartY()

	-- Set font for consistent sizing
	love.graphics.setFont(state.fonts.body)

	-- Draw the buttons using our list component
	list.draw({
		items = BUTTONS,
		startY = startY,
		itemHeight = button.calculateHeight(),
		scrollPosition = list.getScrollPosition(),
		screenWidth = state.screenWidth,
		screenHeight = state.screenHeight,
		drawItemFunc = function(item, _index, y)
			-- Settings has simple buttons, so just use the standard drawing
			button.draw(item.text, 0, y, item.selected, state.screenWidth)
		end,
	})

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

	-- Handle modal if visible
	if modal.isModalVisible() then
		if virtualJoystick.isGamepadPressedWithDelay("dpup") or virtualJoystick.isGamepadPressedWithDelay("dpdown") then
			-- Toggle button selection
			local modalButtons = modal.getModalButtons()
			for _, btn in ipairs(modalButtons) do
				btn.selected = not btn.selected
			end
			modal.setModalButtons(modalButtons)
		end

		if virtualJoystick.isGamepadPressedWithDelay("a") then
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
			return
		end

		-- Exit modal with B button
		if virtualJoystick.isGamepadPressedWithDelay("b") then
			modal.hideModal()
			modalMode = "none"
			return
		end

		return -- Don't process other inputs while modal is visible
	end

	-- Return to menu with B button
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		if switchScreen then
			switchScreen("main_menu")
		end
		return
	end

	-- Use the enhanced list input handler for navigation and selection
	local result = list.handleInput({
		items = BUTTONS,
		virtualJoystick = virtualJoystick,

		-- Handle button selection (A button)
		handleItemSelect = function(btn)
			lastSelectedIndex = list.getSelectedIndex()

			if btn.text == "Load Theme Preset" then
				-- Navigate to the load preset screen
				if switchScreen then
					switchScreen("load_preset")
				end
			elseif btn.text == "Manage Themes" then
				if switchScreen then
					switchScreen("manage_themes")
				end
			elseif btn.text == "About" then
				-- Navigate to the about screen
				if switchScreen then
					switchScreen("about")
				end
			end
		end,
	})
end

-- Handle entry to this screen
function settings.onEnter()
	-- Reset modal state
	modal.hideModal()
	modalMode = "none"

	-- Reset list state and restore selection
	list.onScreenEnter("settings", BUTTONS, lastSelectedIndex)
end

-- Handle cleanup when leaving this screen
function settings.onExit()
	-- Reset modal state
	modal.hideModal()
	modalMode = "none"

	-- Save the current selected index
	lastSelectedIndex = list.onScreenExit()
end

return settings
