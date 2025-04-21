--- Main menu screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local rgbUtils = require("utils.rgb")

local constants = require("screen.menu.constants")
local errorHandler = require("screen.menu.error_handler")
local ui = require("screen.menu.ui")
local themeCreator = require("screen.menu.theme_creator")

-- Initialize errorHandler with UI reference
errorHandler.setUI(ui)

-- Module table to export public functions
local menu = {}

-- Screen switching
local switchScreen = nil
local createdThemePath = nil
local popupState = "none" -- none, created, manual, automatic

-- Scrolling
local scrollPosition = 0
local visibleButtonCount = 0
local totalRegularButtonCount = 0
local scrollBarWidth = 10

-- IO operation states
local waitingState = "none" -- none, create_theme, install_theme
local waitingThemePath = nil
-- Using a state system ensures IO operations happen in the next update loop, preventing UI freezes during operations

function menu.load()
	-- Count total regular buttons (non-bottom buttons)
	totalRegularButtonCount = 0
	for _, button in ipairs(constants.BUTTONS) do
		if not button.isBottomButton then
			totalRegularButtonCount = totalRegularButtonCount + 1
		end
	end

	-- Calculate how many buttons can be displayed at once
	local availableHeight = state.screenHeight - constants.BUTTON.BOTTOM_MARGIN - constants.BUTTON.PADDING
	visibleButtonCount = math.floor(availableHeight / (constants.BUTTON.HEIGHT + constants.BUTTON.PADDING))

	-- Ensure at least some buttons are visible
	visibleButtonCount = math.max(3, visibleButtonCount)

	-- Determine if scroll bar is needed
	local needsScrollBar = totalRegularButtonCount > visibleButtonCount

	-- Adjust button width based on whether scrollbar is needed
	if needsScrollBar then
		-- If scrollbar is needed, account for scrollbar width
		constants.BUTTON.WIDTH = state.screenWidth - (constants.BUTTON.PADDING + scrollBarWidth)
	else
		-- If scrollbar is not needed, buttons can extend to edge minus padding
		constants.BUTTON.WIDTH = state.screenWidth - constants.BUTTON.PADDING
	end

	constants.BUTTON.START_Y = constants.BUTTON.PADDING

	-- Initialize font selection based on state
	for _, font in ipairs(constants.FONTS) do
		font.selected = (font.name == state.selectedFont)
	end
end

-- Function to display a full-screen "Working..." overlay
function menu.displayWaitOverlay()
	-- Semi-transparent background
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.95)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)

	-- Text
	love.graphics.setColor(colors.ui.foreground)
	local font = love.graphics.getFont()
	local text = "Working..."
	local textWidth = font:getWidth(text)
	local textHeight = font:getHeight()

	-- Center the text on screen
	local x = (state.screenWidth - textWidth) / 2
	local y = (state.screenHeight - textHeight) / 2

	love.graphics.print(text, x, y)
end

function menu.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	-- Draw all buttons based on their type
	local regularButtonCount = 0
	local visibleRegularButtonCount = 0

	for _, button in ipairs(constants.BUTTONS) do
		-- Skip buttons that are outside the visible range
		if not button.isBottomButton then
			regularButtonCount = regularButtonCount + 1

			-- Skip if button is scrolled out of view
			if regularButtonCount <= scrollPosition or regularButtonCount > scrollPosition + visibleButtonCount then
				goto continue
			end

			visibleRegularButtonCount = visibleRegularButtonCount + 1
		end

		local y = button.isBottomButton and state.screenHeight - constants.BUTTON.BOTTOM_MARGIN
			or constants.BUTTON.START_Y
				+ (visibleRegularButtonCount - 1) * (constants.BUTTON.HEIGHT + constants.BUTTON.PADDING)

		local x = 0

		-- Special handling for "Create theme" button
		if button.text == "Create theme" then
			-- Calculate centered position with padding
			local padding = 180
			local font = love.graphics.getFont()
			local textWidth = font:getWidth(button.text)
			local buttonWidth = textWidth + (padding * 2)
			local buttonX = (state.screenWidth - buttonWidth) / 2
			local cornerRadius = 8

			if button.selected then
				-- Selected state: accent background, background text, background outline
				love.graphics.setColor(colors.ui.accent)
				love.graphics.rectangle("fill", buttonX, y, buttonWidth, constants.BUTTON.HEIGHT, cornerRadius)

				-- Draw outline
				love.graphics.setColor(colors.ui.background)
				love.graphics.setLineWidth(2)
				love.graphics.rectangle("line", buttonX, y, buttonWidth, constants.BUTTON.HEIGHT, cornerRadius)

				-- Draw text
				love.graphics.setColor(colors.ui.background)
				love.graphics.print(
					button.text,
					buttonX + padding,
					y + (constants.BUTTON.HEIGHT - font:getHeight()) / 2
				)
			else
				-- Unselected state: background with surface outline
				love.graphics.setColor(colors.ui.background)
				love.graphics.rectangle("fill", buttonX, y, buttonWidth, constants.BUTTON.HEIGHT, cornerRadius)

				-- Draw outline
				love.graphics.setColor(colors.ui.surface)
				love.graphics.setLineWidth(2)
				love.graphics.rectangle("line", buttonX, y, buttonWidth, constants.BUTTON.HEIGHT, cornerRadius)

				-- Draw text
				love.graphics.setColor(colors.ui.foreground)
				love.graphics.print(
					button.text,
					buttonX + padding,
					y + (constants.BUTTON.HEIGHT - font:getHeight()) / 2
				)
			end
		else
			-- Draw other buttons normally
			ui.drawButton(button, x, y, button.selected)
		end

		::continue::
	end

	-- Draw scroll bar if needed
	if totalRegularButtonCount > visibleButtonCount then
		-- Calculate the visible area height
		local scrollAreaHeight = visibleButtonCount * (constants.BUTTON.HEIGHT + constants.BUTTON.PADDING)
			- constants.BUTTON.PADDING

		-- Calculate scroll bar height and position
		local scrollBarHeight = (visibleButtonCount / totalRegularButtonCount) * scrollAreaHeight

		-- Calculate maximum scroll position to keep handle in bounds
		local maxScrollY = scrollAreaHeight - scrollBarHeight
		local scrollPercentage = scrollPosition / (totalRegularButtonCount - visibleButtonCount)
		local scrollBarY = constants.BUTTON.START_Y + (scrollPercentage * maxScrollY)

		-- Ensure the scrollbar handle stays within the visible area
		scrollBarY = math.min(scrollBarY, constants.BUTTON.START_Y + maxScrollY)

		-- Draw scroll bar background - position it flush with right edge
		love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 0.3)
		love.graphics.rectangle(
			"fill",
			state.screenWidth - scrollBarWidth,
			constants.BUTTON.START_Y,
			scrollBarWidth,
			scrollAreaHeight,
			4 -- Add corner radius of 4px for the scrollbar background
		)

		-- Draw scroll bar handle - position it flush with right edge
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle(
			"fill",
			state.screenWidth - scrollBarWidth,
			scrollBarY,
			scrollBarWidth,
			scrollBarHeight,
			4 -- Add corner radius of 4px for the scrollbar handle
		)
	end

	-- Draw popup if active
	if ui.isPopupVisible() then
		ui.drawPopup()
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
			-- Show success popup with options
			popupState = "created"
			ui.showPopup(
				"Created theme successfully.",
				{
					{ text = "Apply theme later", selected = false },
					{ text = "Apply theme now", selected = true },
				},
				true -- Use vertical buttons
			)
		else
			-- Show error popup
			errorHandler.showErrorPopup("Error creating theme")
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

		ui.showPopup(
			success and "Applied theme successfully." or "Failed to apply theme.",
			{ { text = "Close", selected = true } }
		)
		return -- Skip the rest of the update to avoid input processing
	end

	if ui.isPopupVisible() then
		if state.canProcessInput() then
			local popupButtons = ui.getPopupButtons()

			-- Handle popup navigation and selection based on popup state
			if popupState == "created" then
				-- Handle navigation for the theme creation success popup
				if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
					for _, button in ipairs(popupButtons) do
						button.selected = not button.selected
					end
					state.resetInputTimer()
				end

				-- Handle selection for the theme creation success popup
				if virtualJoystick:isGamepadDown("a") then
					for i, button in ipairs(popupButtons) do
						if button.selected then
							if i == 1 then
								-- Manual option selected
								popupState = "manual"
								ui.showPopup(
									"Apply theme manually via Configuration > Customisation > muOS Themes.",
									{ { text = "Close", selected = true } }
								)
							else
								-- Automatic option selected
								popupState = "automatic"
								-- Queue theme installation for next frame
								waitingState = "install_theme"
								waitingThemePath = createdThemePath
								-- Mark theme as applied so RGB settings aren't restored
								state.themeApplied = true
							end
							break
						end
					end
					state.resetInputTimer()
				end
			elseif popupState == "manual" or popupState == "automatic" then
				-- Handle selection for the final popup (Close button)
				if virtualJoystick:isGamepadDown("a") then
					ui.hidePopup()
					popupState = "none"
					createdThemePath = nil
					state.resetInputTimer()
					state.forceInputDelay(0.2) -- Add extra delay when closing the popup
				end
			else
				-- Handle navigation for default popups
				if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
					for _, button in ipairs(popupButtons) do
						button.selected = not button.selected
					end
					state.resetInputTimer()
				end

				-- Handle selection for default popups
				if virtualJoystick:isGamepadDown("a") then
					for _, button in ipairs(popupButtons) do
						if button.selected then
							if button.text == "Exit" then
								-- Restore original RGB configuration if no theme was applied
								rgbUtils.restoreConfig()
								love.event.quit()
							else
								ui.hidePopup()
							end
							break
						end
					end
					state.resetInputTimer()
				end
			end
		end
		return -- Don't process other input while popup is shown
	end

	if not state.canProcessInput() then
		return
	end

	local moved = false

	-- Get ordered list of buttons for navigation
	local navButtons = {}

	-- Add all buttons in navigation order
	for _, button in ipairs(constants.BUTTONS) do
		if not button.isBottomButton then
			table.insert(navButtons, button)
		end
	end

	-- Add bottom buttons last
	for _, button in ipairs(constants.BUTTONS) do
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
		for _, button in ipairs(constants.BUTTONS) do
			if button.selected then
				if button.fontSelection then
					-- Redirect to font selection screen
					if switchScreen then
						switchScreen("font")
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
		-- Adjust scroll position if the selected button is outside the visible area
		local buttonIndex = 0
		for _, button in ipairs(constants.BUTTONS) do
			if not button.isBottomButton then
				buttonIndex = buttonIndex + 1
				if button.selected then
					-- Ensure the selected button is visible
					if buttonIndex <= scrollPosition then
						scrollPosition = buttonIndex - 1
					elseif buttonIndex > scrollPosition + visibleButtonCount then
						scrollPosition = buttonIndex - visibleButtonCount
					end
					break
				end
			end
		end
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
