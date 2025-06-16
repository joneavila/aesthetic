--- New Main Menu Screen
--- Uses the new component system for better maintainability
local love = require("love")

local controls = require("control_hints").ControlHints
local errorHandler = require("error_handler")
local screens = require("screens")
local state = require("state")
local themeCreator = require("theme_creator")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local Container = require("ui.layouts.container").Container
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local InputManager = require("ui.controllers.input_manager")
local List = require("ui.components.list").List
local Modal = require("ui.components.modal").Modal
local FocusManager = require("ui.controllers.focus_manager")

local logger = require("utils.logger")
local rgbUtils = require("utils.rgb")

local menu = {}

-- UI Components
local menuList = nil
local actionButton = nil
local input = nil
local modal = nil
local headerInstance = Header:new({ title = "Main Menu" })
local controlHintsInstance = controls:new({})
local rootContainer = nil
local focusManager = nil

-- Constants
local CONTROLS_HEIGHT = controls.calculateHeight()
local ACTION_BUTTON_HEIGHT = 50
local ACTION_BUTTON_SPACING = 8
local TOTAL_BOTTOM_AREA_HEIGHT = CONTROLS_HEIGHT + ACTION_BUTTON_HEIGHT + ACTION_BUTTON_SPACING

-- IO operation states
local waitingState = "none"
local waitingThemePath = nil
local createdThemePath = nil

-- Coroutine handling
local activeCoroutine = nil

-- Fixed modal width (80% of screen width)
local function getFixedModalWidth()
	return math.floor(state.screenWidth * 0.8)
end

-- Helper function to truncate long theme names for display
local function truncateThemeName(name)
	local MAX_NAME_LENGTH = 20
	if #name > MAX_NAME_LENGTH then
		return string.sub(name, 1, MAX_NAME_LENGTH - 3) .. "..."
	end
	return name
end

-- Helper function to format header opacity value consistently
local function formatHeaderOpacity(alphaValue)
	local percent = math.floor((alphaValue / 255) * 100 + 0.5)
	if percent == 0 then
		return "0% (Hidden)"
	else
		return percent .. "%"
	end
end

-- Create all the menu buttons
local function createMenuButtons()
	local buttons = {}

	-- Home screen layout button
	table.insert(
		buttons,
		Button:new({
			text = "Home Screen Layout",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.homeScreenLayout,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("home_screen_layout")
			end,
		})
	)

	-- Background button
	table.insert(
		buttons,
		Button:new({
			text = "Background",
			type = state.backgroundType == "Gradient" and ButtonTypes.GRADIENT or ButtonTypes.COLOR,
			hexColor = state.backgroundType ~= "Gradient" and state.getColorValue("background") or nil,
			startColor = state.backgroundType == "Gradient" and state.getColorValue("background") or nil,
			stopColor = state.backgroundType == "Gradient" and state.getColorValue("backgroundGradient") or nil,
			direction = state.backgroundGradientDirection or "Vertical",
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("background")
			end,
		})
	)

	-- Foreground button
	table.insert(
		buttons,
		Button:new({
			text = "Foreground",
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

	-- Battery button
	table.insert(
		buttons,
		Button:new({
			text = "Battery",
			type = ButtonTypes.DUAL_COLOR,
			color1Hex = state.getColorValue("batteryActive"),
			color2Hex = state.getColorValue("batteryLow"),
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("battery")
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
					screens.switchTo("rgb_lighting")
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
			previewText = state.fontFamily,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("font_family")
			end,
		})
	)

	-- Icons button
	table.insert(
		buttons,
		Button:new({
			text = "Icons",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.glyphsEnabled and "Enabled" or "Disabled",
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("icons")
			end,
		})
	)

	-- Navigation button
	local function getNavigationPreviewText()
		local opacity = state.navigationOpacity and (state.navigationOpacity .. "%") or "100%"
		if state.navigationOpacity == 0 then
			return "Hidden"
		end

		local alignment = state.navigationAlignment or "Left"
		return alignment .. " (" .. opacity .. ")"
	end

	table.insert(
		buttons,
		Button:new({
			text = "Navigation",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = getNavigationPreviewText(),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("navigation")
			end,
		})
	)

	-- Header button
	local function getHeaderPreviewText()
		local percent = math.floor((state.headerOpacity / 255) * 100 + 0.5)
		if percent == 0 then
			return "Hidden"
		end

		local alignmentMap = { [0] = "Auto", [1] = "Left", [2] = "Center", [3] = "Right" }
		local alignment = alignmentMap[state.headerAlignment] or "Center"
		local opacity = formatHeaderOpacity(state.headerOpacity)
		return alignment .. " (" .. opacity .. ")"
	end

	table.insert(
		buttons,
		Button:new({
			text = "Header",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = getHeaderPreviewText(),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("header")
			end,
		})
	)

	-- Datetime button
	local function getDateTimePreviewText()
		local percent = math.floor((state.datetimeOpacity / 255) * 100 + 0.5)
		if percent == 0 then
			return "Hidden"
		end

		local alignment = state.timeAlignment or "Left"
		local opacity = percent .. "%"
		return alignment .. " (" .. opacity .. ")"
	end

	table.insert(
		buttons,
		Button:new({
			text = "Time",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = getDateTimePreviewText(),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("datetime")
			end,
		})
	)

	-- Status button
	table.insert(
		buttons,
		Button:new({
			text = "Status",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.statusAlignment,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("status")
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
				screens.switchTo("box_art_width")
			end,
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

	return true
end

-- Handle theme creation process using coroutines
local function handleThemeCreation()
	if not activeCoroutine then
		-- Start the coroutine
		activeCoroutine = themeCreator.createThemeCoroutine()

		-- Show initial modal with main message and set fixed size
		modal:show("Creating Theme")
		if getFixedModalWidth() > 0 then
			modal:setFixedWidth(getFixedModalWidth())
		end
	end

	-- Resume the coroutine
	local ok, isSuccess, pathOrError = coroutine.resume(activeCoroutine)

	if not ok then
		-- Coroutine error
		activeCoroutine = nil
		waitingState = "none"
		local errorMessage = errorHandler.getError() or pathOrError or "Unknown error"
		local modalText = "Error creating theme: " .. errorMessage
		modal:show(modalText, { { text = "Exit", selected = true } })
		return
	end

	if coroutine.status(activeCoroutine) == "dead" then
		-- Coroutine completed
		activeCoroutine = nil
		waitingState = "none"

		if isSuccess and type(pathOrError) == "string" then
			createdThemePath = pathOrError
			modal:show("Created theme successfully.", {
				{ text = "Apply theme later", selected = false },
				{ text = "Apply theme now", selected = true },
			})
		else
			-- Failure
			local errorMessage = errorHandler.getError() or pathOrError or "Unknown error"
			local modalText = "Error creating theme: " .. errorMessage
			modal:show(modalText, { { text = "Exit", selected = true } })
		end
	else
		-- Coroutine yielded with progress message
		if type(isSuccess) == "string" then
			modal:updateProgress(isSuccess)
		end
	end
end

-- Handle theme installation process using coroutines
local function handleThemeInstallation()
	if not activeCoroutine then
		local filename_only = waitingThemePath and waitingThemePath:match("([^/\\]+)%.[^%.]+$")
		if not filename_only then
			modal:show("Failed to apply theme (no valid filename).", { { text = "Close", selected = true } })
			waitingState = "none"
			return
		end

		-- Start the coroutine
		activeCoroutine = themeCreator.installThemeCoroutine(filename_only)
		-- Show initial modal with main message and set fixed size
		modal:show("Applying Theme")
		if getFixedModalWidth() > 0 then
			modal:setFixedWidth(getFixedModalWidth())
		end
	end

	-- Resume the coroutine
	local success, result, _ = coroutine.resume(activeCoroutine)

	if not success then
		-- Coroutine error
		activeCoroutine = nil
		waitingState = "none"
		waitingThemePath = nil
		local errorMessage = errorHandler.getError() or result or "Unknown error"
		modal:show("Failed to apply theme: " .. errorMessage, { { text = "Close", selected = true } })
		return
	end

	if coroutine.status(activeCoroutine) == "dead" then
		-- Coroutine completed
		activeCoroutine = nil
		waitingState = "none"
		waitingThemePath = nil
		rgbUtils.installFromTheme()
		state.themeApplied = true

		modal:show(
			result and "Applied theme successfully."
				or ("Failed to apply theme: " .. (errorHandler.getError() or "Unknown error")),
			{ { text = "Close", selected = true } }
		)
	else
		-- Coroutine yielded with progress message
		if type(result) == "string" then
			modal:updateProgress(result)
		end
	end
end

function menu.draw()
	background.draw()

	-- Draw all UI via root container
	if rootContainer then
		rootContainer:draw()
	end

	-- Draw modal if active (overlays UI)
	-- if modal and modal:isVisible() then
	-- 	modal:draw(state.screenWidth, state.screenHeight, fonts.loaded.body)
	-- end
end

function menu.update(dt)
	if focusManager then
		focusManager:update(dt)
	end

	-- Handle IO operations
	if waitingState == "show_create_modal" then
		waitingState = "create_theme"
		return
	elseif waitingState == "create_theme" then
		handleThemeCreation()
		return
	elseif waitingState == "install_theme" then
		handleThemeInstallation()
		return
	end

	-- Update modal animation
	modal:update(dt)

	-- Update all UI via root container
	rootContainer:update(dt)

	-- Focus navigation
	local navDir = InputManager.getNavigationDirection()
	if focusManager then
		focusManager:handleInput(navDir, input)
	end

	-- Handle confirm/select (A button) input
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CONFIRM) then
		if focusManager then
			local focused = focusManager:getFocused()
			if focused == menuList then
				local selectedItem = menuList:getSelectedItem()
				if selectedItem and menuList.onItemSelect then
					menuList.onItemSelect(selectedItem, menuList.selectedIndex)
				end
			elseif focused == actionButton then
				if actionButton.onClick then
					actionButton.onClick(actionButton)
				end
			end
		end
	end

	-- Handle B button to exit application
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CANCEL) then
		love.event.quit()
	end
end

-- Store the current focus state when exiting
local lastFocusState = { actionButtonFocused = false, selectedIndex = 1 }

function menu.onExit()
	-- Remember the current focus state
	if focusManager then
		local focused = focusManager:getFocused()
		lastFocusState.actionButtonFocused = (focused == actionButton)
	end
	if menuList then
		lastFocusState.selectedIndex = menuList.selectedIndex or 1
	end
end

function menu.onEnter(data)
	-- Create modal component
	modal = Modal:new({
		font = fonts.loaded.body,
		onButtonPress = function(_index, button)
			if button and button.text == "Apply theme later" then
				modal:hide()
			elseif button and button.text == "Apply theme now" then
				if type(createdThemePath) == "string" and createdThemePath ~= "" then
					waitingThemePath = createdThemePath
					modal:show("Applying theme...")
					waitingState = "install_theme"
				else
					modal:show("No theme path to apply.", { { text = "Close", selected = true } })
				end
			elseif button and button.text == "Exit" then
				love.event.quit()
				modal:hide()
			else
				modal:hide()
			end
		end,
	})

	-- Create UI components with current state
	local buttons = createMenuButtons()
	actionButton = createActionButton()

	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - TOTAL_BOTTOM_AREA_HEIGHT - 8,
		items = buttons,
		onItemSelect = function(item, _index)
			if item.onClick then
				item.onClick()
			end
		end,
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})

	-- Focus manager setup
	focusManager = FocusManager:new()
	focusManager:registerComponent(menuList)
	focusManager:registerComponent(actionButton)

	-- Restore focus state properly
	if lastFocusState.actionButtonFocused then
		focusManager:setFocused(actionButton)
		menuList:setSelectedIndex(0)
	else
		focusManager:setFocused(menuList)
		local validIndex = math.min(math.max(lastFocusState.selectedIndex, 1), #buttons)
		menuList:setSelectedIndex(validIndex)
	end

	-- Control hints setup
	controlHintsInstance:setControlsList({
		{ button = "start", text = "Settings" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Exit" },
	})
	controlHintsInstance.y = state.screenHeight - CONTROLS_HEIGHT
	controlHintsInstance.x = 0
	controlHintsInstance.width = state.screenWidth
	controlHintsInstance.height = CONTROLS_HEIGHT

	-- Action button position
	actionButton.y = state.screenHeight - CONTROLS_HEIGHT - ACTION_BUTTON_HEIGHT - ACTION_BUTTON_SPACING
	actionButton.x = 0
	actionButton.width = state.screenWidth

	-- Header position
	headerInstance.x = 0
	headerInstance.y = 0
	headerInstance.width = state.screenWidth

	-- Create root container and add children
	rootContainer = Container:new({
		x = 0,
		y = 0,
		width = state.screenWidth,
		height = state.screenHeight,
		backgroundColor = nil, -- background is drawn separately
	})
	rootContainer:clearChildren() -- For when returning to main menu
	rootContainer:addChild(headerInstance)
	rootContainer:addChild(menuList)
	rootContainer:addChild(actionButton)
	rootContainer:addChild(controlHintsInstance)

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

	-- Update buttons' preview text
	for _, button in ipairs(menuList.items) do
		if button.text == "Home Screen Layout" then
			button:setPreviewText(state.homeScreenLayout)
		elseif button.text == "Icons" then
			button:setPreviewText(state.glyphsEnabled and "Enabled" or "Disabled")
		elseif button.text == "Navigation" then
			local opacity = state.navigationOpacity and (state.navigationOpacity .. "%") or "100%"
			if state.navigationOpacity == 0 then
				button:setPreviewText("Hidden")
			else
				local alignment = state.navigationAlignment or "Left"
				button:setPreviewText(alignment .. " (" .. opacity .. ")")
			end
		elseif button.text == "Time" then
			local percent = math.floor((state.datetimeOpacity / 255) * 100 + 0.5)
			if percent == 0 then
				button:setPreviewText("Hidden")
			else
				local alignment = state.timeAlignment or "Left"
				local opacity = percent .. "%"
				button:setPreviewText(alignment .. " (" .. opacity .. ")")
			end
		elseif button.text == "Header" then
			local percent = math.floor((state.headerOpacity / 255) * 100 + 0.5)
			if percent == 0 then
				button:setPreviewText("Hidden")
			else
				local alignmentMap = { [0] = "Auto", [1] = "Left", [2] = "Center", [3] = "Right" }
				local alignment = alignmentMap[state.headerAlignment] or "Center"
				local opacity = formatHeaderOpacity(state.headerOpacity)
				button:setPreviewText(alignment .. " (" .. opacity .. ")")
			end
		elseif button.text == "Status" then
			button:setPreviewText(state.statusAlignment)
		elseif button.text == "Battery" then
			button.color1Hex = state.getColorValue("batteryActive")
			button.color2Hex = state.getColorValue("batteryLow")
		end
	end
end

return menu
