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
local header = require("ui.header")

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

-- Button state
menu.BUTTONS = {}
menu.lastSelectedIndex = 1

-- Calculate margin dynamically
local buttonBottomMargin = 6
menu.BUTTON_BOTTOM_MARGIN = controls.calculateHeight() + button.getHeight() + buttonBottomMargin

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

-- ============================================================================
-- BUTTON CONFIGURATION
-- ============================================================================

--- Get current value for a button based on state
--- @param buttonType string Button identifier
--- @return string Current value
local function getCurrentValue(buttonType)
	if buttonType == "fontSize" then
		return state.fontSize
	elseif buttonType == "glyphs" then
		return state.glyphs_enabled and "Enabled" or "Disabled"
	elseif buttonType == "headerText" then
		return state.headerTextEnabled
	elseif buttonType == "headerAlign" then
		local alignmentMap = { [0] = "Auto", [1] = "Left", [2] = "Center", [3] = "Right" }
		return alignmentMap[state.headerTextAlignment] or "Center"
	elseif buttonType == "boxArt" then
		return state.boxArtWidth == 0 and "Disabled" or tostring(state.boxArtWidth)
	elseif buttonType == "navAlign" then
		return state.navigationAlignment
	elseif buttonType == "navAlpha" then
		return state.navigationAlpha and (state.navigationAlpha .. "%") or "50%"
	elseif buttonType == "statusAlign" then
		return state.statusAlignment
	elseif buttonType == "timeAlign" then
		return state.timeAlignment
	elseif buttonType == "themeName" then
		return truncateThemeName(state.themeName)
	elseif buttonType == "rgbMode" then
		return state.rgbMode
	end
	return ""
end

--- Build the buttons configuration
--- @return table Array of button configurations
local function buildButtonsConfig()
	local configs = {
		{
			text = "Background Color",
			type = state.backgroundType == "Gradient" and button.TYPES.GRADIENT or button.TYPES.COLOR,
			colorKey = "background",
			hexColor = state.backgroundType ~= "Gradient" and state.getColorValue("background") or nil,
			startColor = state.backgroundType == "Gradient" and state.getColorValue("background") or nil,
			stopColor = state.backgroundType == "Gradient" and state.getColorValue("backgroundGradient") or nil,
			direction = state.backgroundGradientDirection or "Vertical",
			monoFont = fonts.loaded.monoBody,
			action = function()
				if switchScreen then
					switchScreen("background_color")
				end
			end,
		},
		{
			text = "Foreground Color",
			type = button.TYPES.COLOR,
			colorKey = "foreground",
			hexColor = state.getColorValue("foreground"),
			monoFont = fonts.loaded.monoBody,
			action = function()
				if switchScreen then
					state.activeColorContext = "foreground"
					state.previousScreen = "main_menu"
					switchScreen("color_picker")
				end
			end,
		},
		{
			text = "Font Family",
			type = button.TYPES.TEXT_PREVIEW,
			previewText = state.selectedFont,
			action = function()
				if switchScreen then
					switchScreen("font_family")
				end
			end,
		},
		{
			text = "Font Size",
			type = button.TYPES.INDICATORS,
			options = { "Default", "Large", "Extra Large" },
			currentOptionIndex = ({ ["Default"] = 1, ["Large"] = 2, ["Extra Large"] = 3 })[state.fontSize] or 1,
			context = "fontSize",
		},
		{
			text = "Icons",
			type = button.TYPES.INDICATORS,
			options = { "Disabled", "Enabled" },
			currentOptionIndex = state.glyphs_enabled and 2 or 1,
			context = "glyphs",
		},
		{
			text = "Headers",
			type = button.TYPES.INDICATORS,
			options = { "Disabled", "Enabled" },
			currentOptionIndex = state.headerTextEnabled == "Enabled" and 2 or 1,
			context = "headerText",
		},
		{
			text = "Header Alignment",
			type = button.TYPES.INDICATORS,
			options = { "Auto", "Left", "Center", "Right" },
			currentOptionIndex = (state.headerTextAlignment or 0) + 1,
			context = "headerAlign",
		},
		{
			text = "Box Art Width",
			type = button.TYPES.TEXT_PREVIEW,
			previewText = getCurrentValue("boxArt"),
			action = function()
				if switchScreen then
					switchScreen("box_art")
				end
			end,
		},
		{
			text = "Navigation Alignment",
			type = button.TYPES.INDICATORS,
			options = { "Left", "Center", "Right" },
			currentOptionIndex = ({ ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 })[state.navigationAlignment] or 2,
			context = "navAlign",
		},
		{
			text = "Navigation Alpha",
			type = button.TYPES.TEXT_PREVIEW,
			previewText = getCurrentValue("navAlpha"),
			action = function()
				if switchScreen then
					switchScreen("navigation_alpha")
				end
			end,
		},
		{
			text = "Status Alignment",
			type = button.TYPES.INDICATORS,
			options = { "Left", "Center", "Right" },
			currentOptionIndex = ({ ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 })[state.statusAlignment] or 1,
			context = "statusAlign",
		},
		{
			text = "Time Alignment",
			type = button.TYPES.INDICATORS,
			options = { "Auto", "Left", "Center", "Right" },
			currentOptionIndex = ({ ["Auto"] = 1, ["Left"] = 2, ["Center"] = 3, ["Right"] = 4 })[state.timeAlignment]
				or 1,
			context = "timeAlign",
		},
		{
			text = "Theme Name",
			type = button.TYPES.TEXT_PREVIEW,
			previewText = getCurrentValue("themeName"),
			action = function()
				if switchScreen then
					switchScreen("virtual_keyboard", {
						returnScreen = "main_menu",
						title = "Theme Name",
					})
				end
			end,
		},
		{
			text = "Create Theme",
			type = button.TYPES.ACCENTED,
			isBottomButton = true,
			action = function()
				modal.showModal("Creating theme...")
				waitingState = "create_theme"
			end,
		},
	}

	-- Add RGB Lighting button only if supported
	if state.hasRGBSupport then
		table.insert(configs, 3, {
			text = "RGB Lighting",
			type = button.TYPES.TEXT_PREVIEW,
			previewText = state.rgbMode,
			action = function()
				if switchScreen then
					switchScreen("rgb")
				end
			end,
		})
	end

	return configs
end

--- Create buttons from configuration
local function buildButtonsList()
	local configs = buildButtonsConfig()
	menu.BUTTONS = button.createList(configs)

	-- Add screen width to all buttons
	for _, btn in ipairs(menu.BUTTONS) do
		btn.screenWidth = state.screenWidth
	end

	-- Restore selection
	local idx = menu.lastSelectedIndex or 1
	if idx < 1 or idx > #menu.BUTTONS then
		idx = 1
	end
	for i, btn in ipairs(menu.BUTTONS) do
		button.setSelected(btn, i == idx)
	end

	-- Count regular buttons
	buttonCount = 0
	for _, btn in ipairs(menu.BUTTONS) do
		if not btn.isBottomButton then
			buttonCount = buttonCount + 1
		end
	end
end

-- ============================================================================
-- BUTTON ACTION HANDLERS
-- ============================================================================

--- Handle cycling options for buttons with multiple values
--- @param btn table Button object
--- @param direction number 1 for next, -1 for previous
--- @return boolean True if value changed
local function handleButtonOptionCycle(btn, direction)
	if not btn.context then
		return false
	end

	local changed = button.cycleOption(btn, direction)
	if not changed then
		return false
	end

	local newValue = button.getCurrentOption(btn)

	-- Update state based on button context
	if btn.context == "fontSize" then
		state.fontSize = newValue
	elseif btn.context == "glyphs" then
		state.glyphs_enabled = (newValue == "Enabled")
	elseif btn.context == "headerText" then
		state.headerTextEnabled = newValue
	elseif btn.context == "headerAlign" then
		local alignmentMap = { ["Auto"] = 0, ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 }
		state.headerTextAlignment = alignmentMap[newValue] or 2
	elseif btn.context == "navAlign" then
		state.navigationAlignment = newValue
	elseif btn.context == "statusAlign" then
		state.statusAlignment = newValue
	elseif btn.context == "timeAlign" then
		local alignmentMap = { ["Auto"] = 1, ["Left"] = 2, ["Center"] = 3, ["Right"] = 4 }
		state.timeAlignment = newValue
	end

	return changed
end

-- ============================================================================
-- SCREEN FUNCTIONS
-- ============================================================================

function menu.load()
	button.load()
	buildButtonsList()
end

function menu.draw()
	local startY = header.getContentStartY()

	background.draw()
	header.draw("main menu")

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

	-- Calculate the maximum available height for the list (space above the "Create Theme" button)
	local bottomY = state.screenHeight - menu.BUTTON_BOTTOM_MARGIN

	-- Draw regular buttons with list component
	local result = list.draw({
		items = regularButtons,
		startY = startY,
		itemHeight = button.getHeight(),
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = bottomY,
		drawItemFunc = function(item, _index, y)
			-- Set button's y position for drawing in the list context
			item.listY = y
			button.draw(item)
		end,
	})

	-- Store the visibleCount from the result for use in scroll calculations
	visibleButtonCount = result.visibleCount

	-- Draw the bottom buttons separately
	for _, btn in ipairs(bottomButtons) do
		-- Set the y position for bottom buttons
		btn.y = state.screenHeight - menu.BUTTON_BOTTOM_MARGIN
		button.draw(btn)
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
		-- Replace the process modal with success modal
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
	local success = themeCreator.installTheme(waitingThemePath)

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

-- Handle modal navigation and selection
local function handleModalNavigation(virtualJoystick, dt)
	local modalButtons = modal.getModalButtons()
	if #modalButtons == 0 then
		return -- Skip navigation for buttonless modals
	end

	-- Handle navigation for modal buttons
	-- Toggle selection on D-pad up/down press when there are buttons
	if virtualJoystick.isGamepadPressedWithDelay("dpup") or virtualJoystick.isGamepadPressedWithDelay("dpdown") then
		toggleModalButtonSelection(modalButtons)
	end

	-- Handle selection in modals (A button)
	if virtualJoystick.isGamepadPressedWithDelay("a") then
		if modalState == "created" then
			for i, btn in ipairs(modalButtons) do
				if btn.selected then
					if i == 1 then -- Apply theme later button
						modal.hideModal()
						modalState = "none"
					else -- Apply theme now button
						-- Set the theme path for installation
						waitingThemePath = createdThemePath

						-- Replace current modal with "Applying theme..." modal for smooth transition
						modal.replaceModal("Applying theme...")

						modalState = "none"

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
		else
			-- Handle default modals
			for _, btn in ipairs(modalButtons) do
				if btn.selected then
					if btn.text == "Exit" then
						love.event.quit()
					end
					-- For Close button, just close the modal and continue
				end
			end
			modal.hideModal()
		end
	end
end

-- Handle input
function menu.update(dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Handle IO operations only when modal has fully faded in
	if waitingState == "create_theme" then
		if modal.isModalVisible() then
			waitingState = "none"
			handleThemeCreation()
		end
		return
	elseif waitingState == "install_theme" then
		if modal.isModalVisible() then
			waitingState = "none"
			handleThemeInstallation()
		end
		return
	end

	if modal.isModalVisible() then
		-- Determine controls to draw based on modal state
		local controlsToShow = {}

		-- If there are buttons, always show select
		if #modal.getModalButtons() > 0 then
			table.insert(controlsToShow, { button = "a", text = "Select" })
		end

		table.insert(controlsToShow, { button = "d_pad", text = "Scroll" })

		controls.draw(controlsToShow)

		handleModalNavigation(virtualJoystick, dt)
		return
	end

	-- Handle debug screen
	if virtualJoystick.isButtonCombinationPressed({ "guide", "y" }) and switchScreen then
		switchScreen("debug")
		return
	end

	-- Use the enhanced list input handler for all navigation and selection
	local result = list.handleInput({
		items = menu.BUTTONS, -- Use the created button objects directly
		scrollPosition = scrollPosition,
		visibleCount = visibleButtonCount,
		virtualJoystick = virtualJoystick,

		-- Handle button selection (A button)
		handleItemSelect = function(btn)
			menu.lastSelectedIndex = list.getSelectedIndex()
			if btn.action then
				btn.action(btn) -- Call the action function defined in the button config
			end
		end,

		-- Handle option cycling (left/right d-pad)
		handleItemOption = function(btn, direction)
			return handleButtonOptionCycle(btn, direction) -- Use the new handler
		end,
	})

	-- Update scroll position if changed
	if result.scrollPositionChanged then
		scrollPosition = result.scrollPosition
	end
end

function menu.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- To perform when exiting the screen
function menu.onExit()
	menu.lastSelectedIndex = list.onScreenExit()
	themeCreator.cleanup()
end

function menu.updateFontName()
	-- Display the selected font name
	local fontFamily = ""
	for _, font in ipairs(fonts.themeDefinitions) do
		if font.name == state.selectedFont then
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

	-- Check for returned data from virtual_keyboard
	if data and type(data) == "table" and data.inputValue then
		-- When returning from theme name input
		if data.returnScreen == "main_menu" and data.title == "Theme Name" then
			-- Trim whitespace
			local trimmedName = data.inputValue:gsub("^%s*(.-)%s*$", "%1")
			-- Only update if not empty
			if trimmedName ~= "" then
				state.themeName = trimmedName
				-- Find the theme name button and update its preview text
				for _, btn in ipairs(menu.BUTTONS) do
					if btn.context == "themeName" then
						button.setValueText(btn, truncateThemeName(state.themeName))
						break
					end
				end
			else
				state.themeName = "Aesthetic" -- Reset to default
				-- Find the theme name button and update its preview text
				for _, btn in ipairs(menu.BUTTONS) do
					if btn.context == "themeName" then
						button.setValueText(btn, truncateThemeName(state.themeName))
						break
					end
				end
			end
		end
	end
end

return menu
