--- New Main Menu Screen
--- Uses the new component system for better maintainability
local love = require("love")

local controls = require("controls")
local errorHandler = require("error_handler")
local rgbUtils = require("utils.rgb")
local screens = require("screens")
local state = require("state")
local themeCreator = require("theme_creator")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List
local logger = require("utils.logger")
local Modal = require("ui.modal").Modal

local menu = {}

-- UI Components
local menuList = nil
local actionButton = nil
local input = nil
local modal = nil

-- Constants
local CONTROLS_HEIGHT = controls.calculateHeight()
local ACTION_BUTTON_HEIGHT = 40
local ACTION_BUTTON_SPACING = 12
local TOTAL_BOTTOM_AREA_HEIGHT = CONTROLS_HEIGHT + ACTION_BUTTON_HEIGHT + ACTION_BUTTON_SPACING

-- IO operation states
local waitingState = "none"
local waitingThemePath = nil
local createdThemePath = nil

-- Helper function to truncate long theme names for display
local function truncateThemeName(name)
	local MAX_NAME_LENGTH = 20
	if #name > MAX_NAME_LENGTH then
		return string.sub(name, 1, MAX_NAME_LENGTH - 3) .. "..."
	end
	return name
end

-- Create all the menu buttons
local function createMenuButtons()
	local buttons = {}

	-- Launch Screen Type button (first item)
	table.insert(
		buttons,
		Button:new({
			text = "Launch Screen Type",
			type = ButtonTypes.INDICATORS,
			options = { "List", "Grid" },
			currentOptionIndex = (state.launchScreenType == "Grid" and 2) or 1,
			screenWidth = state.screenWidth,
			context = "launchScreenType",
		})
	)

	-- Background Color button
	table.insert(
		buttons,
		Button:new({
			text = "Background Color",
			type = state.backgroundType == "Gradient" and ButtonTypes.GRADIENT or ButtonTypes.COLOR,
			hexColor = state.backgroundType ~= "Gradient" and state.getColorValue("background") or nil,
			startColor = state.backgroundType == "Gradient" and state.getColorValue("background") or nil,
			stopColor = state.backgroundType == "Gradient" and state.getColorValue("backgroundGradient") or nil,
			direction = state.backgroundGradientDirection or "Vertical",
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("background_color")
			end,
		})
	)

	-- Foreground Color button
	table.insert(
		buttons,
		Button:new({
			text = "Foreground Color",
			type = ButtonTypes.COLOR,
			hexColor = state.getColorValue("foreground"),
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				state.activeColorContext = "foreground"
				state.previousScreen = "main_menu"
				screens.switchTo("color_picker")
			end,
		})
	)

	-- RGB Lighting button (if supported)
	if state.hasRGBSupport then
		table.insert(
			buttons,
			Button:new({
				text = "RGB Lighting",
				type = ButtonTypes.TEXT_PREVIEW,
				previewText = state.rgbMode,
				screenWidth = state.screenWidth,
				onClick = function()
					screens.switchTo("rgb")
				end,
			})
		)
	end

	-- Font Family button
	table.insert(
		buttons,
		Button:new({
			text = "Font Family",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = fonts.getSelectedFont(),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("font_family")
			end,
		})
	)

	-- Font Size button
	table.insert(
		buttons,
		Button:new({
			text = "Font Size",
			type = ButtonTypes.INDICATORS,
			options = { "Default", "Large", "Extra Large" },
			currentOptionIndex = ({ ["Default"] = 1, ["Large"] = 2, ["Extra Large"] = 3 })[fonts.getFontSize()] or 1,
			screenWidth = state.screenWidth,
			context = "fontSize",
		})
	)

	-- Icons button
	table.insert(
		buttons,
		Button:new({
			text = "Icons",
			type = ButtonTypes.INDICATORS,
			options = { "Disabled", "Enabled" },
			currentOptionIndex = state.glyphs_enabled and 2 or 1,
			screenWidth = state.screenWidth,
			context = "glyphs",
		})
	)

	-- Header Alignment button
	table.insert(
		buttons,
		Button:new({
			text = "Header Alignment",
			type = ButtonTypes.INDICATORS,
			options = { "Auto", "Left", "Center", "Right" },
			currentOptionIndex = (state.headerTextAlignment or 0) + 1,
			screenWidth = state.screenWidth,
			context = "headerAlign",
		})
	)

	-- Header Text Alpha button
	table.insert(
		buttons,
		Button:new({
			text = "Header Text Alpha",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = string.format("%d%%", math.floor((state.headerTextAlpha / 255) * 100 + 0.5)),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("header_text_alpha")
			end,
		})
	)

	-- Box Art Width button
	table.insert(
		buttons,
		Button:new({
			text = "Box Art Width",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.boxArtWidth == 0 and "Disabled" or tostring(state.boxArtWidth),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("box_art")
			end,
		})
	)

	-- Navigation Alignment button
	table.insert(
		buttons,
		Button:new({
			text = "Navigation Alignment",
			type = ButtonTypes.INDICATORS,
			options = { "Left", "Center", "Right" },
			currentOptionIndex = ({ ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 })[state.navigationAlignment] or 2,
			screenWidth = state.screenWidth,
			context = "navAlign",
		})
	)

	-- Navigation Alpha button
	table.insert(
		buttons,
		Button:new({
			text = "Navigation Alpha",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.navigationAlpha and (state.navigationAlpha .. "%") or "50%",
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("navigation_alpha")
			end,
		})
	)

	-- Status Alignment button
	table.insert(
		buttons,
		Button:new({
			text = "Status Alignment",
			type = ButtonTypes.INDICATORS,
			options = { "Left", "Center", "Right" },
			currentOptionIndex = ({ ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 })[state.statusAlignment] or 1,
			screenWidth = state.screenWidth,
			context = "statusAlign",
		})
	)

	-- Time Alignment button
	table.insert(
		buttons,
		Button:new({
			text = "Time Alignment",
			type = ButtonTypes.INDICATORS,
			options = { "Auto", "Left", "Center", "Right" },
			currentOptionIndex = ({ ["Auto"] = 1, ["Left"] = 2, ["Center"] = 3, ["Right"] = 4 })[state.timeAlignment]
				or 1,
			screenWidth = state.screenWidth,
			context = "timeAlign",
		})
	)

	-- Theme Name button
	table.insert(
		buttons,
		Button:new({
			text = "Theme Name",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = truncateThemeName(state.themeName),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("virtual_keyboard", {
					returnScreen = "main_menu",
					title = "Theme Name",
				})
			end,
		})
	)

	return buttons
end

-- Create the action button (Create Theme)
local function createActionButton()
	return Button:new({
		text = "Create Theme",
		type = ButtonTypes.ACCENTED,
		screenWidth = state.screenWidth,
		height = ACTION_BUTTON_HEIGHT,
		onClick = function()
			waitingState = "show_create_modal"
		end,
	})
end

-- Handle option cycling for buttons with context
local function handleOptionCycle(button, direction)
	if not button.context then
		return false
	end

	local changed = button:cycleOption(direction)
	if not changed then
		return false
	end

	local newValue = button:getCurrentOption()

	-- Update state based on button context
	if button.context == "fontSize" then
		fonts.setFontSize(newValue)
	elseif button.context == "glyphs" then
		state.glyphs_enabled = (newValue == "Enabled")
	elseif button.context == "headerText" then
		state.headerTextEnabled = newValue
	elseif button.context == "headerAlign" then
		local alignmentMap = { ["Auto"] = 0, ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 }
		state.headerTextAlignment = alignmentMap[newValue] or 2
	elseif button.context == "navAlign" then
		state.navigationAlignment = newValue
	elseif button.context == "statusAlign" then
		state.statusAlignment = newValue
	elseif button.context == "timeAlign" then
		state.timeAlignment = newValue
	elseif button.context == "launchScreenType" then
		state.launchScreenType = newValue
	end

	return true
end

-- Handle theme creation process
local function handleThemeCreation()
	createdThemePath = themeCreator.createTheme()

	-- Show success/error modal after theme is created
	if createdThemePath then
		modal:show("Created theme successfully.", {
			{ text = "Apply theme later", selected = false },
			{ text = "Apply theme now", selected = true },
		})
		modalState = "created"
	else
		local errorMessage = errorHandler.getErrorMessage()
		local modalText = "Error creating theme: " .. (errorMessage or "Unknown error")
		modal:show(modalText, { { text = "Exit", selected = true } })
		modalState = "error"
	end
end

-- Handle theme installation process
local function handleThemeInstallation()
	local filename_only = waitingThemePath and waitingThemePath:match("([^/\\]+)%.[^%.]+$")
	if not filename_only then
		logger.error("No valid theme filename to install")
		modal:show("Failed to apply theme (no filename).", { { text = "Close", selected = true } })
		return
	end
	local success = themeCreator.installTheme(filename_only)
	waitingThemePath = nil
	rgbUtils.installFromTheme()
	state.themeApplied = true

	modal:show(
		success and "Applied theme successfully." or "Failed to apply theme.",
		{ { text = "Close", selected = true } }
	)
end

local modalState = "none"

function menu.load()
	-- Initialize new button component
	require("ui.button").init()

	-- Create input handler
	input = inputHandler.create()

	-- Create UI components
	local buttons = createMenuButtons()
	actionButton = createActionButton()

	-- Create the main list
	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - header.getContentStartY() - TOTAL_BOTTOM_AREA_HEIGHT,
		items = buttons,
		onItemSelect = function(item, _index)
			if item.onClick then
				item.onClick()
			end
		end,
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})

	-- Create modal component
	modal = Modal:new({
		font = fonts.loaded.body,
		onButtonPress = function(_index, button)
			if button and button.text == "Apply theme later" then
				modal:hide()
				modalState = "none"
			elseif button and button.text == "Apply theme now" then
				waitingThemePath = createdThemePath
				modal:show("Applying theme...")
				modalState = "none"
				waitingState = "install_theme"
			elseif button and button.text == "Exit" then
				love.event.quit()
				modal:hide()
			else
				modal:hide()
				modalState = "none"
			end
		end,
	})
end

function menu.draw()
	background.draw()
	header.draw("main menu")

	-- Set the default body font for consistent sizing
	love.graphics.setFont(fonts.loaded.body)

	-- Draw the main list
	if menuList then
		menuList:draw()
	end

	-- Draw the action button right above the controls
	if actionButton then
		actionButton.y = state.screenHeight - CONTROLS_HEIGHT - ACTION_BUTTON_HEIGHT - ACTION_BUTTON_SPACING
		actionButton:draw()
	end

	-- Draw modal if active
	if modal and modal:isVisible() then
		modal:draw(state.screenWidth, state.screenHeight, fonts.loaded.body)
	end

	controls.draw({
		{ button = "start", text = "Settings" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Exit" },
	})
end

function menu.update(dt)
	-- Handle IO operations
	if waitingState == "show_create_modal" then
		modal:show("Creating theme...")
		modalState = "creating"
		waitingState = "create_theme"
		return
	elseif waitingState == "create_theme" then
		waitingState = "none"
		handleThemeCreation()
		return
	elseif waitingState == "install_theme" then
		waitingState = "none"
		handleThemeInstallation()
		return
	end

	-- Handle modal input if visible
	if modal and modal:isVisible() then
		modal:handleInput(input)
		return
	end

	-- Check if action button has focus first - if it does, handle its input directly
	if actionButton and actionButton.focused then
		-- Check for up navigation before letting button handle input
		if input.isPressed("dpup") then
			-- Move focus to last item in list
			if menuList then
				actionButton:setFocused(false)
				menuList:setSelectedIndex(#menuList.items)
			end
			return
		elseif input.isPressed("dpdown") then
			-- Move focus to first item in list
			if menuList then
				actionButton:setFocused(false)
				menuList:setSelectedIndex(1)
			end
			return
		end

		local handled = actionButton:handleInput(input)
		if handled then
			return
		end
	end

	-- Handle list input
	local listHandled = false
	if menuList then
		listHandled = menuList:handleInput(input)
	end

	-- If list signals end, move focus to action button
	if listHandled == "end" then
		if actionButton then
			actionButton:setFocused(true)
		end
		if menuList then
			menuList:setSelectedIndex(0)
		end
		return
	-- If list signals start, move focus to action button
	elseif listHandled == "start" then
		if actionButton then
			actionButton:setFocused(true)
		end
		if menuList then
			menuList:setSelectedIndex(0)
		end
		return
	else
		-- Only unfocus actionButton if menuList is focused (selectedIndex > 0)
		if actionButton and menuList and menuList.selectedIndex > 0 then
			actionButton:setFocused(false)
		end
	end

	-- Handle B button press for exit
	if input.isPressed("b") and (not modal or not modal:isVisible()) then
		love.event.quit()
	end

	-- Handle Start button press for settings
	if input.isPressed("start") and (not modal or not modal:isVisible()) then
		screens.switchTo("settings")
	end

	-- Update components
	if menuList then
		menuList:update(dt)
	end
	if actionButton then
		actionButton:update(dt)
	end
end

function menu.onExit() end

function menu.onEnter(data)
	-- Rebuild the UI components with current state
	local buttons = createMenuButtons()
	actionButton = createActionButton()

	if menuList then
		menuList:setItems(buttons)
	end

	-- Check for returned data from virtual_keyboard
	if data and type(data) == "table" and data.inputValue then
		if data.returnScreen == "main_menu" and data.title == "Theme Name" then
			local cleanThemeName = data.inputValue:gsub("^%s*(.-)%s*$", "%1")
			state.themeName = "Aesthetic"
			if cleanThemeName ~= "" then
				state.themeName = cleanThemeName
			end

			-- Update the theme name button
			local themeNameButton = nil
			for _, button in ipairs(menuList.items) do
				if button.text == "Theme Name" then
					themeNameButton = button
					break
				end
			end

			if themeNameButton then
				themeNameButton:setPreviewText(truncateThemeName(state.themeName))
			end
		end
	end
end

return menu
