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
end

-- Reset modal input state
local function resetModalInputState()
	modalInputState.isFirstInput = true
end

-- Handle modal navigation and selection
local function handleModalNavigation(virtualJoystick, dt)
	local modalButtons = modal.getModalButtons()
	if #modalButtons == 0 then
		return -- Skip navigation for buttonless modals
	end

	-- Handle navigation for modal buttons
	if virtualJoystick.isGamepadPressedWithDelay("dpup") or virtualJoystick.isGamepadPressedWithDelay("dpdown") then
		toggleModalButtonSelection(modalButtons)
		modalInputState.isFirstInput = false
	else
		-- Reset first input flag when buttons are released
		if
			not (
				virtualJoystick.isGamepadPressedWithDelay("dpup") or virtualJoystick.isGamepadPressedWithDelay("dpdown")
			)
		then
			modalInputState.isFirstInput = true
		end
	end

	-- Handle selection in modals (A button)
	if virtualJoystick.isGamepadPressedWithDelay("a") then
		if modalState == "created" then
			for i, btn in ipairs(modalButtons) do
				if btn.selected then
					if i == 1 then -- Apply theme later button
						modal.hideModal()
						modalState = "none"
						resetModalInputState()
					else -- Apply theme now button
						-- Set the theme path for installation
						waitingThemePath = createdThemePath

						-- Replace current modal with "Applying theme..." modal for smooth transition
						modal.replaceWithProcessModal("Applying theme...")

						modalState = "none"
						resetModalInputState()

						-- Set waiting state to install theme after modal transitions
						waitingState = "install_theme"
						return
					end
					break
				end
			end
		elseif modalState == "manual" or modalState == "automatic" then
			modal.hideModal()
			modalState = "none"
			resetModalInputState()
		else
			-- Handle default modals
			for _, btn in ipairs(modalButtons) do
				if btn.selected and btn.text == "Exit" then
					love.event.quit()
				end
			end
			modal.hideModal()
			resetModalInputState()
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
		-- Do nothing on button press, cycling handled by D-pad left/right
	elseif btn.glyphsToggle then
		-- Toggle glyphs enabled state
		state.glyphs_enabled = not state.glyphs_enabled
	elseif btn.navAlignToggle then
		-- Do nothing on button press, cycling handled by D-pad left/right
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
		if #modal.getModalButtons() > 0 then
			controls.draw({ { button = "d_pad", text = "Navigate" }, { button = "a", text = "Select" } })
		end
		handleModalNavigation(virtualJoystick, dt)
		return
	end

	-- Handle debug screen
	if virtualJoystick.isButtonCombinationPressed({ "guide", "y" }) and switchScreen then
		switchScreen("debug")
		return
	end

	local regularButtons = {}
	local bottomButtons = {}
	local navButtons = {}

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
	if virtualJoystick.isGamepadPressedWithDelay("dpup") then
		list.navigate(navButtons, -1)
	elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
		list.navigate(navButtons, 1)
	end

	-- Handle cycling through options
	local pressedLeft = virtualJoystick.isGamepadPressedWithDelay("dpleft")
	local pressedRight = virtualJoystick.isGamepadPressedWithDelay("dpright")

	if pressedLeft or pressedRight then
		logger.debug("dpleft or dpright")
		local direction = pressedLeft and -1 or 1
		logger.debug("direction: " .. direction)
		for _, btn in ipairs(menu.BUTTONS) do
			if btn.selected then
				if btn.fontSizeToggle then
					-- Font size cycles through three values
					if direction > 0 then -- Right direction
						if state.fontSize == "Default" then
							state.fontSize = "Large"
						elseif state.fontSize == "Large" then
							state.fontSize = "Extra Large"
						else
							state.fontSize = "Default"
						end
					else -- Left direction
						if state.fontSize == "Default" then
							state.fontSize = "Extra Large"
						elseif state.fontSize == "Extra Large" then
							state.fontSize = "Large"
						else
							state.fontSize = "Default"
						end
					end
				elseif btn.glyphsToggle then
					-- Glyphs toggle doesn't need direction - it's just a boolean toggle
					state.glyphs_enabled = not state.glyphs_enabled
				elseif btn.navAlignToggle then
					-- Navigation alignment cycles through three values
					if direction > 0 then -- Right direction
						if state.navigationAlignment == "Left" then
							state.navigationAlignment = "Center"
						elseif state.navigationAlignment == "Center" then
							state.navigationAlignment = "Right"
						else
							state.navigationAlignment = "Left"
						end
					else -- Left direction
						if state.navigationAlignment == "Left" then
							state.navigationAlignment = "Right"
						elseif state.navigationAlignment == "Right" then
							state.navigationAlignment = "Center"
						else
							state.navigationAlignment = "Left"
						end
					end
				end
				break
			end
		end
	end

	-- Handle exit
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		logger.debug("Main menu handling B button")
		if not state.themeApplied then
			rgbUtils.restoreConfig()
		end
		love.event.quit()
		return
	end

	-- Handle settings screen
	if virtualJoystick.isGamepadPressedWithDelay("start") and switchScreen then
		switchScreen("settings")
		return
	end

	-- Handle select
	if virtualJoystick.isGamepadPressedWithDelay("a") then
		for _, btn in ipairs(menu.BUTTONS) do
			if btn.selected then
				handleSelectedButton(btn)
				break
			end
		end
	end

	-- Update scroll position based on selected button
	local selectedIndex = list.findSelectedIndex(regularButtons)
	if selectedIndex > 0 then
		scrollPosition = list.adjustScrollPosition({
			selectedIndex = selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleButtonCount,
		})
	else
		-- When focus is on bottom button, use last selected index for proper positioning
		local lastSelectedIndex = list.getLastSelectedIndex()
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
