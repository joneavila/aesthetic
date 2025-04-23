--- Main menu screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local rgbUtils = require("utils.rgb")

local errorHandler = require("error_handler")
local buttonUI = require("ui.button")
local modal = require("ui.modal")
local themeCreator = require("theme_creator")
local fontDefs = require("ui.font_defs")
local scrollView = require("ui.scroll_view")
local textOverlay = require("ui.text_overlay")

local UI_CONSTANTS = require("ui.constants")

-- Initialize errorHandler with UI reference
errorHandler.setUI(buttonUI)

-- Module table to export public functions
local menu = {}

-- Menu constants
-- Screen identifiers
menu.COLOR_PICKER_SCREEN = "color_picker"
menu.ABOUT_SCREEN = "about"
menu.FONT_SCREEN = "font"
menu.RGB_SCREEN = "rgb"

-- Image font size based on screen height
menu.IMAGE_FONT_SIZE = fontDefs.getImageFontSize()

-- Error display time
menu.ERROR_DISPLAY_TIME_SECONDS = 5

-- Button dimensions and position
menu.BUTTON = {
	WIDTH = nil, -- Will be calculated in load()
	HEIGHT = UI_CONSTANTS.BUTTON.HEIGHT,
	PADDING = UI_CONSTANTS.BUTTON.PADDING,
	CORNER_RADIUS = UI_CONSTANTS.BUTTON.CORNER_RADIUS,
	SELECTED_OUTLINE_WIDTH = UI_CONSTANTS.BUTTON.SELECTED_OUTLINE_WIDTH,
	COLOR_DISPLAY_SIZE = UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE,
	START_Y = nil, -- Will be calculated in load()
	HELP_BUTTON_SIZE = 40,
	BOTTOM_MARGIN = UI_CONSTANTS.BUTTON.BOTTOM_MARGIN,
}

menu.BOTTOM_PADDING = controls.HEIGHT

-- Button state
menu.BUTTONS = {
	{
		text = "Background color",
		selected = true,
		colorKey = "background",
	},
	{
		text = "Foreground color",
		selected = false,
		colorKey = "foreground",
	},
	{
		text = "RGB lighting",
		selected = false,
		rgbLighting = true,
	},
	{
		text = "Font family",
		selected = false,
		fontSelection = true,
	},
	{
		text = "Font size",
		selected = false,
		fontSizeToggle = true,
	},
	{
		text = "Icons",
		selected = false,
		glyphsToggle = true,
	},
	{
		text = "Box art width",
		selected = false,
		boxArt = true,
	},
	{
		text = "Create theme",
		selected = false,
		isBottomButton = true,
	},
}

-- Modal buttons
menu.MODAL_BUTTONS = UI_CONSTANTS.MODAL_BUTTONS

-- Screen switching
local switchScreen = nil
local createdThemePath = nil
local modalState = "none" -- none, created, manual, automatic

-- Scrolling
local scrollPosition = 0
local visibleButtonCount = 0
local totalRegularButtonCount = 0
local scrollBarWidth = UI_CONSTANTS.SCROLL_BAR_WIDTH

-- IO operation states
local waitingState = "none" -- none, create_theme, install_theme
local waitingThemePath = nil
-- Using a state system ensures IO operations happen in the next update loop, preventing UI freezes during operations

function menu.load()
	-- Count total regular buttons (non-bottom buttons)
	totalRegularButtonCount = 0
	for _, button in ipairs(menu.BUTTONS) do
		if not button.isBottomButton then
			totalRegularButtonCount = totalRegularButtonCount + 1
		end
	end

	-- Calculate how many buttons can be displayed at once
	local availableHeight = state.screenHeight - menu.BUTTON.BOTTOM_MARGIN - menu.BUTTON.PADDING
	visibleButtonCount = math.floor(availableHeight / (menu.BUTTON.HEIGHT + menu.BUTTON.PADDING))

	-- Ensure at least some buttons are visible
	visibleButtonCount = math.max(3, visibleButtonCount)

	-- Determine if scroll bar is needed
	local needsScrollBar = totalRegularButtonCount > visibleButtonCount

	-- Adjust button width based on whether scrollbar is needed
	if needsScrollBar then
		-- If scrollbar is needed, account for scrollbar width
		menu.BUTTON.WIDTH = state.screenWidth - (menu.BUTTON.PADDING + scrollBarWidth)
	else
		-- If scrollbar is not needed, buttons can extend to edge minus padding
		menu.BUTTON.WIDTH = state.screenWidth - menu.BUTTON.PADDING
	end

	-- Set the button width in the UI module as well
	buttonUI.setWidth(menu.BUTTON.WIDTH)

	menu.BUTTON.START_Y = menu.BUTTON.PADDING

	-- Initialize font selection based on state
	for _, font in ipairs(fontDefs.FONTS) do
		font.selected = (font.name == state.selectedFont)
	end
end

-- Function to display a full-screen "Working..." overlay
function menu.displayWaitOverlay()
	textOverlay.draw({
		text = "Working...",
		screenWidth = state.screenWidth,
		screenHeight = state.screenHeight,
	})
end

function menu.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	-- Draw buttons using scrollView component
	scrollView.draw({
		contentCount = totalRegularButtonCount,
		visibleCount = visibleButtonCount,
		scrollPosition = scrollPosition,
		startY = menu.BUTTON.START_Y,
		contentHeight = menu.BUTTON.HEIGHT,
		contentPadding = menu.BUTTON.PADDING,
		screenWidth = state.screenWidth,
		scrollBarWidth = scrollBarWidth,
		contentDrawFunc = function()
			local regularButtonCount = 0
			local visibleRegularButtonCount = 0

			for _, button in ipairs(menu.BUTTONS) do
				-- Skip buttons that are outside the visible range
				if not button.isBottomButton then
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

				local y = button.isBottomButton and state.screenHeight - menu.BUTTON.BOTTOM_MARGIN
					or menu.BUTTON.START_Y
						+ (visibleRegularButtonCount - 1) * (menu.BUTTON.HEIGHT + menu.BUTTON.PADDING)

				local x = 0

				-- Special handling for "Create theme" button
				if button.text == "Create theme" then
					buttonUI.drawAccented(button, y, state.screenWidth)
				else
					-- Draw buttons based on their type
					if button.colorKey then
						-- Color selection buttons
						local colorInfo = {
							hexColor = state.getColorValue(button.colorKey),
							monoBodyFont = state.fonts.monoBody,
						}
						buttonUI.drawWithColor(
							button,
							x,
							y,
							button.selected,
							state.screenWidth,
							state.fonts.body,
							colorInfo
						)
					elseif button.fontSelection then
						-- Font selection button
						buttonUI.drawWithRightText(
							button,
							x,
							y,
							button.selected,
							state.screenWidth,
							state.fonts.body,
							state.selectedFont
						)
					elseif button.fontSizeToggle then
						-- Font size button
						buttonUI.drawWithRightText(
							button,
							x,
							y,
							button.selected,
							state.screenWidth,
							state.fonts.body,
							state.fontSize
						)
					elseif button.glyphsToggle then
						-- Icons/glyphs button
						local statusText = state.glyphs_enabled and "Enabled" or "Disabled"
						buttonUI.drawWithRightText(
							button,
							x,
							y,
							button.selected,
							state.screenWidth,
							state.fonts.body,
							statusText
						)
					elseif button.boxArt then
						-- Box art width button
						local boxArtText = state.boxArtWidth
						if boxArtText == "Disabled" then
							boxArtText = "0 (Disabled)"
						end
						buttonUI.drawWithRightText(
							button,
							x,
							y,
							button.selected,
							state.screenWidth,
							state.fonts.body,
							boxArtText
						)
					elseif button.rgbLighting then
						-- RGB lighting button
						local statusText = state.rgbMode
						-- Do not display the brightness level if mode is set to "Off"
						if state.rgbMode ~= "Off" then
							statusText = statusText .. " (" .. state.rgbBrightness .. ")"
						end
						buttonUI.drawWithRightText(
							button,
							x,
							y,
							button.selected,
							state.screenWidth,
							state.fonts.body,
							statusText
						)
					else
						-- Regular button with no right content
						buttonUI.draw(button, x, y, button.selected, state.screenWidth, state.fonts.body)
					end
				end

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
		menu.displayWaitOverlay()
	end

	controls.draw({
		{ button = "d_pad", text = "Navigate" },
		{ button = "a", text = "Select" },
		{ button = "start", text = "Settings" },
		{ button = "b", text = "Exit" },
	})
end

function menu.update(dt)
	-- Update error timer
	errorHandler.update(dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Handle IO operations that were queued in the previous frame
	if waitingState == "create_theme" then
		-- Execute theme creation
		createdThemePath = themeCreator.createTheme()
		waitingState = "none"

		if createdThemePath then
			-- Show success modal with options
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
			-- Show error modal
			errorHandler.showErrorModal("Error creating theme")
		end
		return -- Skip the rest of the update to avoid input processing
	elseif waitingState == "install_theme" then
		-- Execute theme installation
		local waitingThemeName = waitingThemePath and string.match(waitingThemePath, "([^/]+)%.muxthm$")
		local success = themeCreator.installTheme(waitingThemeName)
		waitingState = "none"
		waitingThemePath = nil

		-- After theme is installed, apply RGB settings from theme
		rgbUtils.installFromTheme()

		modal.showModal(
			success and "Applied theme successfully." or "Failed to apply theme.",
			{ { text = "Close", selected = true } }
		)
		return -- Skip the rest of the update to avoid input processing
	end

	if modal.isModalVisible() then
		-- Show controls for modals
		controls.draw({ { button = "d_pad", text = "Navigate" }, { button = "a", text = "Select" } })

		local modalButtons = modal.getModalButtons()

		-- Handle modal navigation and selection based on modal state
		if modalState == "created" then
			-- Handle navigation for the theme creation success modal
			if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
				for _, button in ipairs(modalButtons) do
					button.selected = not button.selected
				end
				state.resetInputTimer()
			end

			-- Handle selection for the theme creation success modal
			if virtualJoystick:isGamepadDown("a") then
				for i, button in ipairs(modalButtons) do
					if button.selected then
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
			end
		elseif modalState == "manual" or modalState == "automatic" then
			-- Handle selection for the final modal (Close button)
			if virtualJoystick:isGamepadDown("a") then
				modal.hideModal()
				modalState = "none"
				-- If installation was successful, switch to the themes screen
				if createdThemePath then
					switchScreen("themes", createdThemePath)
				end
				-- Add a small delay to avoid immediate input after closing
				state.forceInputDelay(0.2) -- Add extra delay when closing the modal
			end
		else
			-- Handle navigation for default modals
			if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
				for _, button in ipairs(modalButtons) do
					button.selected = not button.selected
				end
				state.resetInputTimer()
			end

			-- Handle selection for default modals
			if virtualJoystick:isGamepadDown("a") then
				for _, button in ipairs(modalButtons) do
					if button.selected then
						if button.text == "Exit" then
							os.exit(0)
						end
					end
				end
				modal.hideModal()
			end
		end

		return -- Don't process other input while modal is shown
	end

	if not state.canProcessInput() then
		return
	end

	local moved = false

	-- Get ordered list of buttons for navigation
	local navButtons = {}

	-- Add all buttons in navigation order
	for _, button in ipairs(menu.BUTTONS) do
		if not button.isBottomButton then
			table.insert(navButtons, button)
		end
	end

	-- Add bottom buttons last
	for _, button in ipairs(menu.BUTTONS) do
		if button.isBottomButton then
			table.insert(navButtons, button)
		end
	end

	-- Handle D-pad
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		local direction = virtualJoystick:isGamepadDown("dpup") and -1 or 1

		for i, button in ipairs(navButtons) do
			if button.selected then
				button.selected = false
				local nextIndex

				if direction == -1 then -- up
					nextIndex = i > 1 and i - 1 or #navButtons
				else -- down
					nextIndex = i < #navButtons and i + 1 or 1
				end

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
		state.resetInputTimer()
		state.forceInputDelay(0.2) -- Add extra delay when switching screens
		return
	end

	-- Reset input timer if moved
	if moved then
		state.resetInputTimer()
	end

	-- Handle A button (Select)
	if virtualJoystick:isGamepadDown("a") then
		-- Find which button is selected
		for _, button in ipairs(menu.BUTTONS) do
			if button.selected then
				if button.fontSelection then
					-- Redirect to font selection screen
					if switchScreen then
						switchScreen("font_family")
						state.resetInputTimer()
						state.forceInputDelay(0.2) -- Add extra delay when switching screens
					end
				elseif button.fontSizeToggle then
					-- Toggle font size between "Default", "Large", and "Extra Large"
					if state.fontSize == "Default" then
						state.fontSize = "Large"
					elseif state.fontSize == "Large" then
						state.fontSize = "Extra Large"
					else
						state.fontSize = "Default"
					end
					state.resetInputTimer()
				elseif button.glyphsToggle then
					-- Toggle glyphs enabled state
					state.glyphs_enabled = not state.glyphs_enabled
					state.resetInputTimer()
				elseif button.rgbLighting and switchScreen then
					-- RGB lighting screen
					switchScreen("rgb")
					state.resetInputTimer()
					state.forceInputDelay(0.2) -- Add extra delay when switching screens
				elseif button.boxArt and switchScreen then
					-- Box art settings screen
					switchScreen("box_art")
					state.resetInputTimer()
					state.forceInputDelay(0.2) -- Add extra delay when switching screens
				elseif button.colorKey and switchScreen then
					-- Any color selection button
					state.activeColorContext = button.colorKey
					state.previousScreen = "menu" -- Set previous screen to return to
					switchScreen("color_picker")
					state.resetInputTimer()
					state.forceInputDelay(0.2) -- Add extra delay when switching screens
				elseif button.text == "Create theme" then
					-- Queue theme creation for next frame
					waitingState = "create_theme"
					-- Deferring theme creation to the next frame allows the wait overlay to be displayed first
				end
				break
			end
		end
	end

	-- Update scroll position based on selected button
	local selectedButtonIndex = nil
	for i, button in ipairs(navButtons) do
		if button.selected and not button.isBottomButton then
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
	-- Assume colorKey is already a hex code (Case 1: From HSV or hex color picker)
	local colorValue = colorKey

	if colorKey:sub(1, 1) ~= "#" then
		-- Case 2:From palette picker, needs conversion to hex
		colorValue = colors.toHex(colorKey)
	end

	if not colorValue then
		errorHandler.setError("Failed to set color value: " .. colorKey)
	end

	-- Store in the centralized context using the setter
	state.setColorValue(buttonType, colorValue)
end

function menu.onExit()
	-- Clean up working directory when leaving menu screen
	themeCreator.cleanup()
end

return menu
