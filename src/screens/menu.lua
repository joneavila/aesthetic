--- Main menu screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local rgbUtils = require("utils.rgb")

local errorHandler = require("error_handler")
local button = require("ui.button")
local background = require("ui.background")
local modal = require("ui.modal")
local themeCreator = require("theme_creator")
local fontDefs = require("ui.font_defs")
local scrollView = require("ui.scroll_view")
local textOverlay = require("ui.text_overlay")

local UI_CONSTANTS = require("ui.constants")

-- Module table to export public functions
local menu = {}

-- Image font size based on screen height
menu.IMAGE_FONT_SIZE = fontDefs.getImageFontSize()

-- Button state
menu.BUTTONS = {
	{ text = "Background color", selected = true, colorKey = "background" },
	{ text = "Foreground color", selected = false, colorKey = "foreground" },
	{ text = "RGB lighting", selected = false, rgbLighting = true },
	{ text = "Font family", selected = false, fontSelection = true },
	{ text = "Font size", selected = false, fontSizeToggle = true },
	{ text = "Icons", selected = false, glyphsToggle = true },
	{ text = "Box art width", selected = false, boxArt = true },
	{ text = "Create theme", selected = false, isBottomButton = true },
}

menu.BOTTOM_PADDING = controls.HEIGHT

-- Screen switching
local switchScreen = nil
local createdThemePath = nil
local modalState = "none" -- none, created, manual, automatic

-- Scrolling
local scrollPosition = 0
local visibleButtonCount = 0
local buttonCount = 0
local scrollBarWidth = UI_CONSTANTS.SCROLL_BAR_WIDTH

-- IO operation states
local waitingState = "none" -- none, create_theme, install_theme
local waitingThemePath = nil
-- Using a state system ensures IO operations happen in the next update loop, preventing UI freezes during operations

-- Helper function to get button display value based on type
local function getButtonValue(btn)
	if btn.fontSelection then
		return state.selectedFont
	elseif btn.fontSizeToggle then
		return state.fontSize
	elseif btn.glyphsToggle then
		return state.glyphs_enabled and "Enabled" or "Disabled"
	elseif btn.boxArt then
		local boxArtText = state.boxArtWidth
		if boxArtText == "Disabled" then
			boxArtText = "0 (Disabled)"
		end
		return boxArtText
	elseif btn.rgbLighting then
		local statusText = state.rgbMode
		if state.rgbMode ~= "Off" then
			statusText = statusText .. " (" .. state.rgbBrightness .. ")"
		end
		return statusText
	end
	return nil
end

-- Helper function to draw a button based on its type
local function drawButton(btn, x, y)
	if btn.text == "Create theme" then
		button.drawAccented(btn.text, btn.selected, y, state.screenWidth)
	elseif btn.colorKey then
		button.drawWithColorPreview(btn.text, btn.selected, x, y, state.screenWidth, state.getColorValue(btn.colorKey))
	elseif btn.fontSelection or btn.fontSizeToggle or btn.glyphsToggle or btn.boxArt or btn.rgbLighting then
		button.drawWithTextPreview(btn.text, x, y, btn.selected, state.screenWidth, getButtonValue(btn))
	else
		button.draw(btn, x, y, btn.selected, state.screenWidth)
	end
end

function menu.load()
	-- Count regular buttons and calculate visible buttons
	buttonCount = 0
	for _, btn in ipairs(menu.BUTTONS) do
		if not btn.isBottomButton then
			buttonCount = buttonCount + 1
		end
	end

	local availableHeight = state.screenHeight - UI_CONSTANTS.BUTTON.BOTTOM_MARGIN - UI_CONSTANTS.BUTTON.PADDING
	visibleButtonCount =
		math.max(3, math.floor(availableHeight / (UI_CONSTANTS.BUTTON.HEIGHT + UI_CONSTANTS.BUTTON.PADDING)))

	-- Set button width based on whether scrollbar is needed
	local needsScrollBar = buttonCount > visibleButtonCount
	UI_CONSTANTS.BUTTON.WIDTH = state.screenWidth
		- UI_CONSTANTS.BUTTON.PADDING
		- (needsScrollBar and scrollBarWidth or 0)
	button.setWidth(UI_CONSTANTS.BUTTON.WIDTH)

	-- Initialize font selection based on state
	for _, font in ipairs(fontDefs.FONTS) do
		font.selected = (font.name == state.selectedFont)
	end
end

function menu.draw()
	local startY = UI_CONSTANTS.BUTTON.PADDING

	background.draw()

	-- Draw buttons using scrollView component
	scrollView.draw({
		contentCount = buttonCount,
		visibleCount = visibleButtonCount,
		scrollPosition = scrollPosition,
		startY = startY,
		contentHeight = UI_CONSTANTS.BUTTON.HEIGHT,
		contentPadding = UI_CONSTANTS.BUTTON.PADDING,
		screenWidth = state.screenWidth,
		scrollBarWidth = scrollBarWidth,
		contentDrawFunc = function()
			local regularButtonCount = 0
			local visibleRegularButtonCount = 0

			for _, btn in ipairs(menu.BUTTONS) do
				-- Skip buttons that are outside the visible range
				if not btn.isBottomButton then
					regularButtonCount = regularButtonCount + 1

					-- Skip if button is scrolled out of view
					if
						regularButtonCount <= scrollPosition
						or regularButtonCount > scrollPosition + visibleButtonCount
					then
						goto continue
					end

					visibleRegularButtonCount = visibleRegularButtonCount + 1
				end

				local y = btn.isBottomButton and state.screenHeight - UI_CONSTANTS.BUTTON.BOTTOM_MARGIN
					or startY
						+ (visibleRegularButtonCount - 1) * (UI_CONSTANTS.BUTTON.HEIGHT + UI_CONSTANTS.BUTTON.PADDING)

				drawButton(btn, 0, y)

				::continue::
			end
		end,
	})

	-- Draw modal if active
	if modal.isModalVisible() then
		modal.drawModal()
	end

	-- Draw wait overlay if in waiting state
	if waitingState ~= "none" then
		textOverlay.draw({
			text = "Working...",
			screenWidth = state.screenWidth,
			screenHeight = state.screenHeight,
		})
	end

	controls.draw({
		{ button = "d_pad", text = "Navigate" },
		{ button = "a", text = "Select" },
		{ button = "start", text = "Settings" },
		{ button = "b", text = "Exit" },
	})
end

-- Handle theme creation process
local function handleThemeCreation()
	createdThemePath = themeCreator.createTheme()
	waitingState = "none"

	if createdThemePath then
		modalState = "created"
		modal.showModal(
			"Created theme successfully.",
			{
				{ text = "Apply theme later", selected = false },
				{ text = "Apply theme now", selected = true },
			},
			true -- Use vertical buttons
		)
	else
		errorHandler.showErrorModal("Error creating theme")
	end
	return true -- Skip the rest of the update
end

-- Handle theme installation process
local function handleThemeInstallation()
	local waitingThemeName = waitingThemePath and string.match(waitingThemePath, "([^/]+)%.muxthm$")
	local success = themeCreator.installTheme(waitingThemeName)
	waitingState = "none"
	waitingThemePath = nil

	rgbUtils.installFromTheme()

	modal.showModal(
		success and "Applied theme successfully." or "Failed to apply theme.",
		{ { text = "Close", selected = true } }
	)
	return true -- Skip the rest of the update
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
	elseif btn.rgbLighting and switchScreen then
		-- RGB lighting screen
		switchScreen("rgb")
	elseif btn.boxArt and switchScreen then
		-- Box art settings screen
		switchScreen("box_art")
	elseif btn.colorKey and switchScreen then
		-- Any color selection button
		state.activeColorContext = btn.colorKey
		state.previousScreen = "menu" -- Set previous screen to return to
		switchScreen("color_picker")
	elseif btn.text == "Create theme" then
		-- Queue theme creation for next frame
		waitingState = "create_theme"
		-- Deferring theme creation to the next frame allows the wait overlay to be displayed first
	end
end

-- Toggle the selection state of modal buttons
local function toggleModalButtonSelection(modalButtons)
	for _, btn in ipairs(modalButtons) do
		btn.selected = not btn.selected
	end
	state.resetInputTimer()
end

-- Handle modal navigation and selection
local function handleModalNavigation(virtualJoystick)
	local modalButtons = modal.getModalButtons()

	-- Handle left/right navigation for modal buttons
	if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
		toggleModalButtonSelection(modalButtons)
	end

	-- Handle selection in modals
	if virtualJoystick:isGamepadDown("a") then
		if modalState == "created" then
			for i, btn in ipairs(modalButtons) do
				if btn.selected then
					if i == 1 then -- Exit button
						os.exit(0)
					else -- Open theme button
						modalState = "manual"
						modal.showModal(
							"Apply theme manually via Configuration > Customisation > muOS Themes.",
							{ { text = "Close", selected = true } }
						)
					end
					break
				end
			end
			state.resetInputTimer()
		elseif modalState == "manual" or modalState == "automatic" then
			modal.hideModal()
			modalState = "none"
			-- If installation was successful, switch to the themes screen
			if createdThemePath then
				switchScreen("themes", createdThemePath)
			end
			-- Add a small delay to avoid immediate input after closing
			state.forceInputDelay(0.2) -- Add extra delay when closing the modal
		else
			-- Handle default modals
			for _, btn in ipairs(modalButtons) do
				if btn.selected and btn.text == "Exit" then
					os.exit(0)
				end
			end
			modal.hideModal()
		end
	end
end

function menu.update(_dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Handle IO operations that were queued in the previous frame
	if waitingState == "create_theme" then
		return handleThemeCreation()
	elseif waitingState == "install_theme" then
		return handleThemeInstallation()
	end

	if modal.isModalVisible() then
		-- Show controls for modals
		controls.draw({ { button = "d_pad", text = "Navigate" }, { button = "a", text = "Select" } })
		handleModalNavigation(virtualJoystick)
		return -- Don't process other input while modal is shown
	end

	if not state.canProcessInput() then
		return
	end

	local moved = false

	-- Get ordered list of buttons for navigation
	local navButtons = {}

	-- Add buttons in navigation order (non-bottom buttons first, then bottom buttons)
	for _, btn in ipairs(menu.BUTTONS) do
		if not btn.isBottomButton then
			table.insert(navButtons, btn)
		end
	end
	for _, btn in ipairs(menu.BUTTONS) do
		if btn.isBottomButton then
			table.insert(navButtons, btn)
		end
	end

	-- Handle D-pad
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		local direction = virtualJoystick:isGamepadDown("dpup") and -1 or 1

		for i, btn in ipairs(navButtons) do
			if btn.selected then
				btn.selected = false
				local nextIndex = direction == -1 and (i > 1 and i - 1 or #navButtons)
					or (i < #navButtons and i + 1 or 1)
				navButtons[nextIndex].selected = true
				moved = true
				break
			end
		end
	end

	-- Handle B button (Exit)
	if virtualJoystick:isGamepadDown("b") then
		-- Restore original RGB configuration if no theme was applied
		rgbUtils.restoreConfig()
		love.event.quit()
		return
	end

	-- Handle Start button (Settings)
	if virtualJoystick:isGamepadDown("start") and switchScreen then
		switchScreen("settings")
		return
	end

	-- Reset input timer if moved
	if moved then
		state.resetInputTimer()
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
	local selectedButtonIndex = nil
	for i, btn in ipairs(navButtons) do
		if btn.selected and not btn.isBottomButton then
			selectedButtonIndex = i
			break
		end
	end

	if selectedButtonIndex and not navButtons[selectedButtonIndex].isBottomButton then
		scrollPosition = scrollView.adjustScrollPosition({
			selectedIndex = selectedButtonIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleButtonCount,
		})
	end
end

function menu.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function menu.setSelectedColor(buttonType, colorKey)
	-- Convert color value to hex if needed
	local colorValue = colorKey:sub(1, 1) ~= "#" and colors.toHex(colorKey) or colorKey
	if not colorValue then
		errorHandler.setError("Failed to set color value: " .. colorKey)
	end
	state.setColorValue(buttonType, colorValue)
end

function menu.onExit()
	-- Clean up working directory when leaving menu screen
	themeCreator.cleanup()
end

return menu
