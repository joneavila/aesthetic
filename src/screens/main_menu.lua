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
local scrollable = require("ui.scrollable")
local header = require("ui.header")

local logger = require("utils.logger")

-- Module table to export public functions
local menu = {}

-- Function to truncate long theme names for display
local function truncateThemeName(name)
	local MAX_NAME_LENGTH = 20 -- Adjust this value as needed
	if #name > MAX_NAME_LENGTH then
		return string.sub(name, 1, MAX_NAME_LENGTH - 3) .. "..."
	end
	return name
end

-- Image font size based on screen dimensions using fonts.calculateFontSize (base 28, min 16, max 60) for image font
-- scaling
menu.IMAGE_FONT_SIZE = fonts.calculateFontSize(state.screenWidth, state.screenHeight, 28, 16, 60)

-- Button state
menu.BUTTONS = {}
menu.lastSelectedIndex = 1

-- Add input cooldown to prevent immediate button press after screen transition
menu.inputCooldownTimer = 0
menu.INPUT_COOLDOWN_DURATION = 0.3 -- seconds

-- Function to build buttons list on enter
local function buildButtonsList()
	menu.BUTTONS = {
		{ text = "Background Color", selected = false, colorKey = "background" },
		{ text = "Foreground Color", selected = false, colorKey = "foreground" },
		{ text = "Font Family", selected = false, fontSelection = true },
		{ text = "Font Size", selected = false, fontSizeToggle = true },
		{ text = "Icons", selected = false, glyphsToggle = true },
		{ text = "Headers", selected = false, headerTextToggle = true },
		{ text = "Box Art Width", selected = false, boxArt = true },
		{ text = "Navigation Alignment", selected = false, navAlignToggle = true },
		{ text = "Navigation Alpha", selected = false, navAlpha = true },
		{ text = "Status Alignment", selected = false, statusAlignToggle = true },
		{ text = "Time Alignment", selected = false, timeAlignToggle = true },
		{ text = "Theme Name", selected = false, themeName = true },
		{ text = "Create Theme", selected = false, isBottomButton = true },
	}

	-- Add RGB Lighting button only if supported
	if state.hasRGBSupport then
		table.insert(menu.BUTTONS, 3, { text = "RGB Lighting", selected = false, rgbLighting = true })
	end

	-- Restore selection
	local idx = menu.lastSelectedIndex or 1
	if idx < 1 or idx > #menu.BUTTONS then
		idx = 1
	end
	for i, btn in ipairs(menu.BUTTONS) do
		btn.selected = (i == idx)
	end
end

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

-- IO operation states (operation states)
local waitingState = "none" -- none, create_theme, install_theme
local waitingThemePath = nil

-- Modal input state tracking for handling press-and-hold
local modalInputState = {
	isFirstInput = true,
}

function menu.load()
	logger.debug("Main menu load started")

	buildButtonsList()

	-- Count regular buttons
	buttonCount = 0
	for _, btn in ipairs(menu.BUTTONS) do
		if not btn.isBottomButton then
			buttonCount = buttonCount + 1
		end
	end
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
		elseif btn.headerTextToggle then
			btn.valueText = state.headerTextEnabled
		elseif btn.boxArt then
			-- Box art width should be displayed with special handling for 0
			btn.value = state.boxArtWidth == 0 and "Disabled" or tostring(state.boxArtWidth)
		elseif btn.navAlignToggle then
			btn.valueText = state.navigationAlignment
		elseif btn.navAlpha then
			-- Navigation alpha displays the percentage
			btn.valueText = state.navigationAlpha and (state.navigationAlpha .. "%") or "50%"
		elseif btn.themeName then
			-- Truncate theme name for display if it is too long
			btn.valueText = truncateThemeName(state.themeName)
		elseif btn.statusAlignToggle then
			btn.valueText = state.statusAlignment
		elseif btn.timeAlignToggle then
			btn.valueText = state.timeAlignment
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
			elseif item.headerTextToggle then
				button.drawWithIndicators(
					item.text,
					0,
					y,
					item.selected,
					item.disabled,
					state.screenWidth,
					state.headerTextEnabled
				)
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
			elseif item.navAlpha then
				local alphaText = state.navigationAlpha and (state.navigationAlpha .. "%") or "50%"
				button.drawWithTextPreview(item.text, 0, y, item.selected, state.screenWidth, alphaText)
			elseif item.themeName then
				button.drawWithTextPreview(
					item.text,
					0,
					y,
					item.selected,
					state.screenWidth,
					truncateThemeName(state.themeName)
				)
			elseif item.statusAlignToggle then
				button.drawWithTextPreview(item.text, 0, y, item.selected, state.screenWidth, state.statusAlignment)
			elseif item.timeAlignToggle then
				button.drawWithIndicators(
					item.text,
					0,
					y,
					item.selected,
					item.disabled,
					state.screenWidth,
					state.timeAlignment
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
	logger.debug("Handling theme creation")
	-- Create the theme after showing the modal
	createdThemePath = themeCreator.createTheme()

	-- Show success/error modal after theme is created
	if createdThemePath then
		logger.debug("Theme created successfully at: " .. createdThemePath)
		modalState = "created"
		-- Replace the process modal with success modal
		modal.replaceModal("Created theme successfully.", {
			{ text = "Apply theme later", selected = false },
			{ text = "Apply theme now", selected = true },
		})
	else
		logger.error("Theme creation failed")
		errorHandler.showErrorModal("Error creating theme")
	end

	return true -- Skip the rest of the update
end

-- Handle theme installation process
local function handleThemeInstallation()
	local waitingThemeName = waitingThemePath and string.match(waitingThemePath, "([^/]+)%.muxthm$")
	logger.debug("Installing theme: " .. (waitingThemeName or "nil"))
	local success = themeCreator.installTheme(waitingThemeName)

	waitingThemePath = nil

	rgbUtils.installFromTheme()

	-- Set flag to indicate theme was applied
	state.themeApplied = true

	-- Replace the process modal with success/failure modal
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
	-- For scrollable modals, don't toggle buttons on up/down as those are used for scrolling
	if
		not modal.isScrollableModal()
		and (virtualJoystick.isGamepadPressedWithDelay("dpup") or virtualJoystick.isGamepadPressedWithDelay("dpdown"))
	then
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
				if btn.selected and btn.text == "Exit" or btn.text == "Close" then
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
	elseif btn.headerTextToggle then
		-- Header text toggle cycles between Enabled and Disabled
		if state.headerTextEnabled == "Enabled" then
			state.headerTextEnabled = "Disabled"
		else
			state.headerTextEnabled = "Enabled"
		end
	elseif btn.navAlignToggle then
		-- Do nothing on button press, cycling handled by D-pad left/right
	elseif btn.navAlpha and switchScreen then
		-- Navigation alpha screen
		switchScreen("navigation_alpha")
	elseif btn.statusAlignToggle and switchScreen then
		switchScreen("status_align")
	elseif btn.rgbLighting and switchScreen then
		-- RGB lighting screen
		switchScreen("rgb")
	elseif btn.boxArt and switchScreen then
		-- Box art settings screen
		switchScreen("box_art")
	elseif btn.themeName and switchScreen then
		-- Theme name setting screen
		-- The value is not pre-populated, i.e. begin with empty value
		switchScreen("virtual_keyboard", {
			returnScreen = "main_menu",
			title = "Theme Name",
		})
	elseif btn.colorKey and btn.text == "Background Color" and switchScreen then
		-- Background color gets special handling for solid/gradient options
		switchScreen("background_color")
	elseif btn.colorKey and switchScreen then
		-- Any other color selection button
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

-- Handle input
function menu.update(dt)
	local virtualJoystick = require("input").virtualJoystick
	local logger = require("utils.logger")

	-- Update modal animations
	modal.update(dt)

	-- Update cooldown timer
	if menu.inputCooldownTimer > 0 then
		menu.inputCooldownTimer = menu.inputCooldownTimer - dt
		return -- Skip input handling during cooldown
	end

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
		-- Add ability to scroll error modals with D-pad up/down
		if modal.isScrollableModal() then
			if virtualJoystick.isGamepadPressedWithDelay("dpup") then
				modal.scroll(-20) -- Scroll up
			elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
				modal.scroll(20) -- Scroll down
			end

			-- Show scroll controls in the control hints area
			controls.draw({
				{ button = "a", text = "Select" },
				{ button = "d_pad", text = "Scroll" },
			})
		elseif #modal.getModalButtons() > 0 then
			controls.draw({ { button = "a", text = "Select" } })
		end

		handleModalNavigation(virtualJoystick, dt)
		return
	end

	-- Handle debug screen
	if virtualJoystick.isButtonCombinationPressed({ "guide", "y" }) and switchScreen then
		-- switchScreen("debug") -- Original debug screen
		switchScreen("virtual_keyboard", { returnScreen = "main_menu", title = "Keyboard Test" }) -- Temporary for keyboard testing
		return
	end

	-- Prepare buttons for navigation
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

	-- Use the enhanced list input handler for all navigation and selection
	local result = list.handleInput({
		items = navButtons,
		scrollPosition = scrollPosition,
		visibleCount = visibleButtonCount,
		virtualJoystick = virtualJoystick,

		-- Handle button selection (A button)
		handleItemSelect = function(btn)
			menu.lastSelectedIndex = list.getSelectedIndex()
			handleSelectedButton(btn)
		end,

		-- Handle option cycling (left/right d-pad)
		handleItemOption = function(btn, direction)
			local changed = false

			if btn.fontSizeToggle then
				-- Font size cycles through three values
				local options = { "Default", "Large", "Extra Large" }
				changed = list.cycleItemOption(btn, direction, "valueText", options)
				state.fontSize = btn.valueText
			elseif btn.glyphsToggle then
				-- Glyphs toggle doesn't need direction - it's just a boolean toggle
				state.glyphs_enabled = not state.glyphs_enabled
				changed = true
			elseif btn.headerTextToggle then
				-- Header text toggle cycles between Enabled and Disabled
				local options = { "Enabled", "Disabled" }
				changed = list.cycleItemOption(btn, direction, "valueText", options)
				state.headerTextEnabled = btn.valueText
			elseif btn.navAlignToggle then
				-- Navigation alignment cycles through three values
				local options = { "Left", "Center", "Right" }
				changed = list.cycleItemOption(btn, direction, "valueText", options)
				state.navigationAlignment = btn.valueText
			elseif btn.timeAlignToggle then
				-- Time alignment cycles through four values
				local options = { "Auto", "Left", "Center", "Right" }
				changed = list.cycleItemOption(btn, direction, "valueText", options)
				state.timeAlignment = btn.valueText
			end

			return changed
		end,
	})

	-- Update scroll position if changed
	if result.scrollPositionChanged then
		scrollPosition = result.scrollPosition
		logger.debug("Updated scroll position to: " .. scrollPosition)
	end
end

function menu.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- To perform when exiting the screen
function menu.onExit()
	-- Store the current selected index before leaving using the centralized function
	menu.lastSelectedIndex = list.onScreenExit()
	themeCreator.cleanup()
end

function menu.updateFontName()
	-- Display the selected font name
	local fontFamily = ""
	for _, font in ipairs(fonts.themeDefinitions) do
		if fonts.isSelected(font.name, state.selectedFont) then
			fontFamily = font.name
			break
		end
	end
	return fontFamily
end

function menu.onEnter(data)
	buildButtonsList()

	-- Reset list state and restore selection using the centralized function
	scrollPosition = list.onScreenEnter("main_menu", menu.BUTTONS, menu.lastSelectedIndex)

	-- Set input cooldown when entering screen
	if data and type(data) == "table" and data.preventImmediateInput then
		-- Longer cooldown when explicitly requested
		menu.inputCooldownTimer = menu.INPUT_COOLDOWN_DURATION * 1.5
	else
		-- Regular cooldown on normal entry
		menu.inputCooldownTimer = menu.INPUT_COOLDOWN_DURATION
	end

	-- Check for returned data from virtual_keyboard
	if data and type(data) == "table" and data.inputValue then
		-- When returning from theme name input
		if data.returnScreen == "main_menu" and data.title == "Theme Name" then
			-- Trim whitespace
			local trimmedName = data.inputValue:gsub("^%s*(.-)%s*$", "%1")
			-- Only update if not empty
			if trimmedName ~= "" then
				state.themeName = trimmedName
			else
				state.themeName = "Aesthetic" -- Reset to default
			end
		end
	end
end

return menu
