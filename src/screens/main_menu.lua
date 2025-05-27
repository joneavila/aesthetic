--- Main menu screen
local love = require("love")

local controls = require("controls")
local errorHandler = require("error_handler")
local rgbUtils = require("utils.rgb")
local screens = require("screens")
local state = require("state")
local themeCreator = require("theme_creator")

local background = require("ui.background")
local button = require("ui.button")
local fonts = require("ui.fonts")
local header = require("ui.header")
local list = require("ui.list")
local logger = require("utils.logger")
local modal = require("ui.modal")

local menu = {}

-- Button state
local BUTTONS = {}
local lastSelectedIndex = 1

local TOTAL_BOTTOM_AREA_HEIGHT = controls.calculateHeight() + button.getHeight() + 6

-- Scrolling
local scrollPosition = 0
local visibleButtonCount = 0

-- IO operation states (operation states)
local waitingState = "none" -- none, create_theme, install_theme
local waitingThemePath = nil

local createdThemePath = nil
local modalState = "none" -- none, created, manual, automatic

-- Function to truncate long theme names for display
local function truncateThemeName(name)
	local MAX_NAME_LENGTH = 20
	if #name > MAX_NAME_LENGTH then
		return string.sub(name, 1, MAX_NAME_LENGTH - 3) .. "..."
	end
	return name
end

--- Create buttons from configuration
local function buildButtonsList()
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
				screens.switchTo("background_color")
			end,
		},
		{
			text = "Foreground Color",
			type = button.TYPES.COLOR,
			colorKey = "foreground",
			hexColor = state.getColorValue("foreground"),
			monoFont = fonts.loaded.monoBody,
			action = function()
				state.activeColorContext = "foreground"
				state.previousScreen = "main_menu"
				screens.switchTo("color_picker")
			end,
		},
		{
			text = "Font Family",
			type = button.TYPES.TEXT_PREVIEW,
			previewText = state.selectedFont,
			action = function()
				screens.switchTo("font_family")
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
			previewText = state.boxArtWidth == 0 and "Disabled" or tostring(state.boxArtWidth),
			action = function()
				screens.switchTo("box_art")
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
			previewText = state.navigationAlpha and (state.navigationAlpha .. "%") or "50%",
			action = function()
				screens.switchTo("navigation_alpha")
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
			previewText = truncateThemeName(state.themeName),
			action = function()
				screens.switchTo("virtual_keyboard", {
					returnScreen = "main_menu",
					title = "Theme Name",
				})
			end,
		},
		-- This is the only bottom button
		{
			text = "Create Theme",
			type = button.TYPES.ACCENTED,
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
				screens.switchTo("rgb")
			end,
		})
	end

	BUTTONS = button.createList(configs)

	-- Add screen width to all buttons
	for _, btn in ipairs(BUTTONS) do
		btn.screenWidth = state.screenWidth
	end

	-- Restore selection
	local idx = lastSelectedIndex or 1
	if idx < 1 or idx > #BUTTONS then
		idx = 1
	end
	for i, btn in ipairs(BUTTONS) do
		button.setSelected(btn, i == idx)
	end
end

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

	-- Find the single bottom button
	local actionButton = nil
	local regularButtons = {}

	for _, btn in ipairs(BUTTONS) do
		-- Check if this is the 'Create Theme' button based on its text
		if btn.text == "Create Theme" and btn.type == button.TYPES.ACCENTED then
			actionButton = btn
		else
			table.insert(regularButtons, btn)
		end
	end

	-- Calculate the maximum available height for the list (space above the bottom button)
	local bottomY = state.screenHeight - TOTAL_BOTTOM_AREA_HEIGHT

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

	-- Draw the bottom button separately
	actionButton.y = state.screenHeight - TOTAL_BOTTOM_AREA_HEIGHT
	button.draw(actionButton)

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
	createdThemePath = themeCreator.createTheme()

	-- Show success/error modal after theme is created
	if createdThemePath then
		modalState = "created"
		modal.showModal("Created theme successfully.", {
			{ text = "Apply theme later", selected = false },
			{ text = "Apply theme now", selected = true },
		})
	else
		local errorMessage = errorHandler.getErrorMessage()
		local modalText = "Error creating theme: " .. (errorMessage or "Unknown error")
		logger.error("Showing error modal: " .. modalText)
		modal.showModal(modalText, { { text = "Exit", selected = true } })
	end
end

-- Handle theme installation process
local function handleThemeInstallation()
	-- Extract the filename without extension from the full path
	local filename_only = waitingThemePath:match("([^/\\]+)%.[^%.]+$")
	local success = themeCreator.installTheme(filename_only)
	waitingThemePath = nil
	rgbUtils.installFromTheme()
	state.themeApplied = true

	-- Replace modal with success/failure modal
	modal.showModal(
		success and "Applied theme successfully." or "Failed to apply theme.",
		{ { text = "Close", selected = true } }
	)
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
		for _, btn in ipairs(modalButtons) do
			btn.selected = not btn.selected
		end
	end

	-- Handle selection in modals (A button)
	if virtualJoystick.isGamepadPressedWithDelay("a") then
		if modalState == "created" then
			for i, btn in ipairs(modalButtons) do
				if btn.selected then
					if i == 1 then -- "Apply theme later" button
						modal.hideModal()
						modalState = "none"
					else -- "Apply theme now" button
						-- Set the theme path for installation
						waitingThemePath = createdThemePath

						-- Replace current modal with "Applying theme..." modal
						modal.showModal("Applying theme...")

						modalState = "none"
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

	-- Handle IO operations
	if waitingState == "create_theme" then
		waitingState = "none"
		handleThemeCreation()
		return
	elseif waitingState == "install_theme" then
		waitingState = "none"
		handleThemeInstallation()
		return
	end

	-- Handle modal input if it is visible
	if modal.isModalVisible() then
		handleModalNavigation(virtualJoystick, dt)
		return
	end

	local result = list.handleInput({
		items = BUTTONS,
		scrollPosition = scrollPosition,
		visibleCount = visibleButtonCount,
		virtualJoystick = virtualJoystick,

		-- Handle button selection (A button)
		handleItemSelect = function(btn)
			lastSelectedIndex = list.getSelectedIndex()
			if btn.action then
				btn.action(btn) -- Call the action function defined in the button config
			end
		end,

		-- Handle option cycling (left/right d-pad)
		handleItemOption = function(btn, direction)
			return handleButtonOptionCycle(btn, direction) -- Use the new handler
		end,
	})

	-- Handle B button press for exit if no modal is visible
	if virtualJoystick.isGamepadPressedWithDelay("b") and not modal.isModalVisible() then
		love.event.quit()
	end

	-- Handle Start button press for settings
	if virtualJoystick.isGamepadPressedWithDelay("start") and not modal.isModalVisible() then
		screens.switchTo("settings")
	end

	-- Update scroll position if changed
	if result.scrollPositionChanged then
		scrollPosition = result.scrollPosition
	end
end

-- To perform when exiting the screen
function menu.onExit()
	lastSelectedIndex = list.onScreenExit()
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
	scrollPosition = list.onScreenEnter("main_menu", BUTTONS, lastSelectedIndex)

	-- Check for returned data from virtual_keyboard
	if data and type(data) == "table" and data.inputValue then
		-- When returning from theme name input
		if data.returnScreen == "main_menu" and data.title == "Theme Name" then
			local cleanThemeName = data.inputValue:gsub("^%s*(.-)%s*$", "%1")
			-- Update theme name if not empty, else resets to default
			state.themeName = "Aesthetic"
			if cleanThemeName ~= "" then
				state.themeName = cleanThemeName
			end
			-- Find the theme name button and update its preview text
			for _, btn in ipairs(BUTTONS) do
				if btn.context == "themeName" then
					button.setValueText(btn, truncateThemeName(state.themeName))
					break
				end
			end
		end
	end
end

return menu
