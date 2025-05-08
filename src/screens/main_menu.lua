--- Main menu screen
local love = require("love")
local state = require("state")
local controls = require("controls")
local rgbUtils = require("utils.rgb")

local errorHandler = require("error_handler")
local button = require("ui.button")
local background = require("ui.background")
local modal = require("ui.modal")
local themeCreator = require("theme_creator")
local fonts = require("ui.fonts")
local list = require("ui.list")
local scrollView = require("ui.scroll_view")
local header = require("ui.header")

local logger = require("utils.logger")

-- Module table to export public functions
local menu = {}

-- Image font size based on screen height
menu.IMAGE_FONT_SIZE = fonts.getImageFontSize(state.screenHeight)

-- Button state
menu.BUTTONS = {
	{ text = "Background Color", selected = true, colorKey = "background" },
	{ text = "Foreground Color", selected = false, colorKey = "foreground" },
	{ text = "RGB Lighting", selected = false, rgbLighting = true },
	{ text = "Font Family", selected = false, fontSelection = true },
	{ text = "Font Size", selected = false, fontSizeToggle = true },
	{ text = "Icons", selected = false, glyphsToggle = true },
	{ text = "Box Art Width", selected = false, boxArt = true },
	{ text = "Navigation Alignment", selected = false, navAlignToggle = true },
	{ text = "Create Theme", selected = false, isBottomButton = true },
}

-- Function to calculate button height
local function calculateButtonHeight()
	local font = love.graphics.getFont()
	return font:getHeight() + (button.BUTTON and button.BUTTON.VERTICAL_PADDING * 2)
end

-- Calculate margin dynamically based on button height plus initial fixed margin
local buttonBottomMargin = 6
menu.BUTTON_BOTTOM_MARGIN = controls.calculateHeight() + calculateButtonHeight() + buttonBottomMargin

-- Screen switching
local switchScreen = nil
local createdThemePath = nil
local modalState = "none" -- none, created, manual, automatic

-- Scrolling
local scrollPosition = 0
local visibleButtonCount = 0
local buttonCount = 0
local scrollBarWidth = scrollView.SCROLL_BAR_WIDTH

-- IO operation states (operation states)
local waitingState = "none" -- none, create_theme, install_theme
local waitingThemePath = nil

-- Modal input state tracking for handling press-and-hold
local modalInputState = {
	lastInputTime = 0,
	inputDelay = 0.25, -- Minimum delay between inputs when holding a button
	isFirstInput = true,
}

function menu.load()
	-- Count regular buttons
	buttonCount = 0
	for _, btn in ipairs(menu.BUTTONS) do
		if not btn.isBottomButton then
			buttonCount = buttonCount + 1
		end
	end

	list.resetScrollPosition()
end

function menu.draw()
	local startY = header.getHeight()

	background.draw()
	header.draw("MAIN MENU")

	-- Set the default body font for consistent sizing
	love.graphics.setFont(state.fonts.body)

	-- Separate regular buttons from bottom buttons
	local regularButtons = {}
	local bottomButtons = {}

	for _, btn in ipairs(menu.BUTTONS) do
		if btn.isBottomButton then
			table.insert(bottomButtons, btn)
		else
			table.insert(regularButtons, btn)
		end
	end

	-- Process buttons before drawing to add display values
	for _, btn in ipairs(regularButtons) do
		-- Add display values for buttons that need them
		if btn.fontSizeToggle then
			btn.valueText = state.fontSize
		elseif btn.glyphsToggle then
			btn.valueText = state.glyphs_enabled and "Enabled" or "Disabled"
		elseif btn.boxArt then
			-- Box art width should be displayed with special handling for 0
			btn.value = state.boxArtWidth == 0 and "Disabled" or tostring(state.boxArtWidth)
		elseif btn.navAlignToggle then
			btn.valueText = state.navigationAlignment
		end
	end

	-- Calculate the maximum available height for the list (space above the "Create Theme" button)
	local bottomY = state.screenHeight - menu.BUTTON_BOTTOM_MARGIN

	-- Draw regular buttons with list component
	local result = list.draw({
		items = regularButtons,
		startY = startY,
		itemHeight = button.calculateHeight(),
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = bottomY,
		scrollBarWidth = scrollBarWidth,
		drawItemFunc = function(item, _index, y)
			-- Draw the button based on its type
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
			elseif item.fontSelection then
				button.drawWithTextPreview(item.text, 0, y, item.selected, state.screenWidth, state.selectedFont)
			elseif item.fontSizeToggle then
				button.drawWithIndicators(
					item.text,
					0,
					y,
					item.selected,
					item.disabled,
					state.screenWidth,
					state.fontSize
				)
			elseif item.glyphsToggle then
				local displayText = state.glyphs_enabled and "Enabled" or "Disabled"
				button.drawWithIndicators(item.text, 0, y, item.selected, item.disabled, state.screenWidth, displayText)
			elseif item.boxArt then
				local boxArtText = state.boxArtWidth
				if boxArtText == 0 then
					boxArtText = "Disabled"
				end
				button.drawWithTextPreview(item.text, 0, y, item.selected, state.screenWidth, boxArtText)
			elseif item.rgbLighting then
				button.drawWithTextPreview(item.text, 0, y, item.selected, state.screenWidth, state.rgbMode)
			elseif item.navAlignToggle then
				button.drawWithIndicators(
					item.text,
					0,
					y,
					item.selected,
					item.disabled,
					state.screenWidth,
					state.navigationAlignment
				)
			else
				button.draw(item.text, 0, y, item.selected, state.screenWidth)
			end
		end,
	})

	-- Store the visibleCount from the result for use in scroll calculations
	visibleButtonCount = result.visibleCount

	-- Draw the "Create Theme" button separately with accented style
	-- Find the "Create Theme" button
	local createThemeButton = nil
	for _, btn in ipairs(bottomButtons) do
		if btn.text == "Create Theme" then
			createThemeButton = btn
			break
		end
	end

	if createThemeButton then
		local newBottomY = state.screenHeight - menu.BUTTON_BOTTOM_MARGIN
		local buttonWidth = state.screenWidth - 34
		button.drawAccented(
			createThemeButton.text,
			createThemeButton.selected,
			newBottomY,
			state.screenWidth,
			buttonWidth
		)
	end

	-- Draw modal if active
	if modal.isModalVisible() then
		modal.drawModal(state.screenWidth, state.screenHeight, state.fonts.body)
	end

	controls.draw({
		{ button = "start", text = "Settings" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Exit" },
	})
end

-- Handle theme creation process
local function handleThemeCreation()
	-- Create the theme after showing the modal
	createdThemePath = themeCreator.createTheme()

	-- Show success/error modal after theme is created
	if createdThemePath then
		modalState = "created"
		-- Replace the process modal with success modal for smooth transition
		modal.replaceModal("Created theme successfully.", {
			{ text = "Apply theme later", selected = false },
			{ text = "Apply theme now", selected = true },
		})
		-- Add input delay to prevent immediately processing inputs after modal appears
		state.resetInputTimer()
		state.forceInputDelay(0.5)
	else
		errorHandler.showErrorModal("Error creating theme")
	end

	return true -- Skip the rest of the update
end

-- Handle theme installation process
local function handleThemeInstallation()
	local waitingThemeName = waitingThemePath and string.match(waitingThemePath, "([^/]+)%.muxthm$")
	logger.debug("Waiting theme name: " .. waitingThemeName)
	local success = themeCreator.installTheme(waitingThemeName)

	waitingThemePath = nil

	rgbUtils.installFromTheme()

	-- Set flag to indicate theme was applied
	state.themeApplied = true

	-- Replace the process modal with success/failure modal for smooth transition
	modal.replaceModal(
		success and "Applied theme successfully." or "Failed to apply theme.",
		{ { text = "Close", selected = true } }
	)

	return true -- Skip the rest of the update
end

-- Toggle the selection state of modal buttons
local function toggleModalButtonSelection(modalButtons)
	for _, btn in ipairs(modalButtons) do
		btn.selected = not btn.selected
	end
	state.resetInputTimer()
end

-- Reset modal input state
local function resetModalInputState()
	modalInputState.lastInputTime = 0
	modalInputState.isFirstInput = true
end

-- Handle modal navigation and selection
local function handleModalNavigation(virtualJoystick, dt)
	local modalButtons = modal.getModalButtons()
	if #modalButtons == 0 then
		return -- Skip navigation for buttonless modals
	end

	-- Update last input time
	modalInputState.lastInputTime = modalInputState.lastInputTime + dt

	-- Handle navigation for modal buttons with input throttling
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		-- Allow immediate input for first press, then enforce delay for subsequent inputs
		if modalInputState.isFirstInput or modalInputState.lastInputTime >= modalInputState.inputDelay then
			toggleModalButtonSelection(modalButtons)
			modalInputState.lastInputTime = 0
			modalInputState.isFirstInput = false
		end
	else
		-- Reset first input flag when buttons are released
		if not (virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown")) then
			modalInputState.isFirstInput = true
		end
	end

	-- Handle selection in modals (A button)
	if virtualJoystick:isGamepadDown("a") then
		if modalState == "created" then
			for i, btn in ipairs(modalButtons) do
				if btn.selected then
					if i == 1 then -- Apply theme later button
						modal.hideModal()
						modalState = "none"
						resetModalInputState()
						state.forceInputDelay(0.3) -- Add delay when closing the modal
					else -- Apply theme now button
						-- Set the theme path for installation
						waitingThemePath = createdThemePath

						-- Replace current modal with "Applying theme..." modal for smooth transition
						modal.replaceWithProcessModal("Applying theme...")

						modalState = "none"
						resetModalInputState()
						state.resetInputTimer()

						-- Set waiting state to install theme after modal transitions
						waitingState = "install_theme"
						return
					end
					break
				end
			end
			state.resetInputTimer()
		elseif modalState == "manual" or modalState == "automatic" then
			modal.hideModal()
			modalState = "none"
			resetModalInputState()
			state.forceInputDelay(0.3) -- Add extra delay when closing the modal
		else
			-- Handle default modals
			for _, btn in ipairs(modalButtons) do
				if btn.selected and btn.text == "Exit" then
					love.event.quit()
				end
			end
			modal.hideModal()
			resetModalInputState()
			state.forceInputDelay(0.2) -- Add delay after handling default modals
		end
	end
end

-- Handle selection of a button
local function handleSelectedButton(btn)
	if btn.fontSelection then
		-- Redirect to font selection screen
		if switchScreen then
			switchScreen("font_family")
		end
	elseif btn.fontSizeToggle then
		-- Toggle font size between "Default", "Large", and "Extra Large"
		if state.fontSize == "Default" then
			state.fontSize = "Large"
		elseif state.fontSize == "Large" then
			state.fontSize = "Extra Large"
		else
			state.fontSize = "Default"
		end
		state.resetInputTimer()
	elseif btn.glyphsToggle then
		-- Toggle glyphs enabled state
		state.glyphs_enabled = not state.glyphs_enabled
		state.resetInputTimer()
	elseif btn.navAlignToggle then
		-- Toggle navigation alignment between "Left", "Center", and "Right"
		if state.navigationAlignment == "Left" then
			state.navigationAlignment = "Center"
		elseif state.navigationAlignment == "Center" then
			state.navigationAlignment = "Right"
		else
			state.navigationAlignment = "Left"
		end
		state.resetInputTimer()
	elseif btn.rgbLighting and switchScreen then
		-- RGB lighting screen
		switchScreen("rgb")
	elseif btn.boxArt and switchScreen then
		-- Box art settings screen
		switchScreen("box_art")
	elseif btn.colorKey and switchScreen then
		-- Any color selection button
		state.activeColorContext = btn.colorKey
		state.previousScreen = "main_menu" -- Set previous screen to return to
		switchScreen("color_picker")
	elseif btn.text == "Create Theme" then
		-- Show the process modal first
		modal.showProcessModal("Creating theme...")
		-- Set waiting state to create theme after modal fades in
		waitingState = "create_theme"
	end
end

function menu.update(dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Update modal animations
	modal.update(dt)

	-- Handle IO operations only when modal has fully faded in
	if waitingState == "create_theme" then
		if modal.isModalVisible() and modal.isProcessModal() and modal.isFullyFadedIn() then
			waitingState = "none"
			handleThemeCreation()
		end
		return
	elseif waitingState == "install_theme" then
		if modal.isModalVisible() and modal.isProcessModal() and modal.isFullyFadedIn() then
			waitingState = "none"
			handleThemeInstallation()
			logger.debug("Main menu handled theme installation")
		end
		return
	end

	if modal.isModalVisible() then
		-- Show controls for modals with buttons
		if #modal.getModalButtons() > 0 then
			controls.draw({ { button = "d_pad", text = "Navigate" }, { button = "a", text = "Select" } })
		end
		handleModalNavigation(virtualJoystick, dt)
		return -- Don't process other input while modal is shown
	end

	if not state.canProcessInput() then
		return
	end

	-- Check for debug screen button combination (D-pad Left + A)
	if virtualJoystick:isGamepadDown("dpleft") and virtualJoystick:isGamepadDown("a") and switchScreen then
		switchScreen("debug")
		state.resetInputTimer()
		state.forceInputDelay(0.3) -- Add delay when switching screens
		return
	end

	-- Split buttons into navigation groups
	local regularButtons = {}
	local bottomButtons = {}
	local navButtons = {} -- Combined navigation order

	-- Collect regular and bottom buttons separately
	for _, btn in ipairs(menu.BUTTONS) do
		if btn.isBottomButton then
			table.insert(bottomButtons, btn)
		else
			table.insert(regularButtons, btn)
		end
	end

	-- Build the navigation order (regular buttons first, then bottom buttons)
	for _, btn in ipairs(regularButtons) do
		table.insert(navButtons, btn)
	end
	for _, btn in ipairs(bottomButtons) do
		table.insert(navButtons, btn)
	end

	-- Handle D-pad navigation
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		local direction = virtualJoystick:isGamepadDown("dpup") and -1 or 1

		-- Use list navigation helper
		list.navigate(navButtons, direction)

		state.resetInputTimer()
	end

	-- Handle D-pad left/right for cycling through options
	if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
		local direction = virtualJoystick:isGamepadDown("dpleft") and -1 or 1

		-- Find the selected button
		for _, btn in ipairs(menu.BUTTONS) do
			if btn.selected then
				if btn.fontSizeToggle then
					-- Toggle font size
					if direction > 0 then
						-- Go forward
						if state.fontSize == "Default" then
							state.fontSize = "Large"
						elseif state.fontSize == "Large" then
							state.fontSize = "Extra Large"
						else
							state.fontSize = "Default"
						end
					else
						-- Go backward
						if state.fontSize == "Default" then
							state.fontSize = "Extra Large"
						elseif state.fontSize == "Extra Large" then
							state.fontSize = "Large"
						else
							state.fontSize = "Default"
						end
					end
					state.resetInputTimer()
				elseif btn.glyphsToggle then
					-- Toggle glyphs enabled
					state.glyphs_enabled = not state.glyphs_enabled
					state.resetInputTimer()
				elseif btn.navAlignToggle then
					-- Toggle navigation alignment
					if direction > 0 then
						-- Go forward
						if state.navigationAlignment == "Left" then
							state.navigationAlignment = "Center"
						elseif state.navigationAlignment == "Center" then
							state.navigationAlignment = "Right"
						else
							state.navigationAlignment = "Left"
						end
					else
						-- Go backward
						if state.navigationAlignment == "Left" then
							state.navigationAlignment = "Right"
						elseif state.navigationAlignment == "Right" then
							state.navigationAlignment = "Center"
						else
							state.navigationAlignment = "Left"
						end
					end
					state.resetInputTimer()
				end
				break
			end
		end
	end

	-- Handle B button (Exit)
	if virtualJoystick:isGamepadDown("b") then
		logger.debug("Main menu handling B button")
		-- Restore original RGB configuration if no theme was applied
		if not state.themeApplied then
			rgbUtils.restoreConfig()
		end
		love.event.quit()
		return
	end

	-- Handle Start button (Settings)
	if virtualJoystick:isGamepadDown("start") and switchScreen then
		switchScreen("settings")
		return
	end

	-- Handle A button (Select)
	if virtualJoystick:isGamepadDown("a") then
		-- Find which button is selected
		for _, btn in ipairs(menu.BUTTONS) do
			if btn.selected then
				handleSelectedButton(btn)
				break
			end
		end
	end

	-- Update scroll position based on selected button
	local selectedIndex = list.findSelectedIndex(regularButtons)
	if selectedIndex > 0 then -- When a regular button is selected
		scrollPosition = list.adjustScrollPosition({
			selectedIndex = selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleButtonCount,
		})
	else
		-- When focus is on bottom button, use last selected index for proper positioning
		local lastSelectedIndex = list.getLastSelectedIndex()

		-- Adjust scroll position based on the last selected index in the regular list
		-- This will be skipped if transitioning to the bottom button (no extra scroll)
		scrollPosition = list.adjustScrollPosition({
			selectedIndex = lastSelectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleButtonCount,
		})
	end
end

function menu.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- To perform when exiting the screen
function menu.onExit()
	themeCreator.cleanup()
	list.resetScrollPosition()
end

function menu.updateFontName()
	-- Display the selected font name
	local fontFamily = ""
	for _, font in ipairs(fonts.choices) do
		if fonts.isSelected(font.name, state.selectedFont) then
			fontFamily = font.name
			break
		end
	end
	return fontFamily
end

return menu
