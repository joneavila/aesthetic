--- Main menu screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")

local constants = require("screen.menu.constants")
local ui = require("screen.menu.ui")
local errorHandler = require("screen.menu.error_handler")
local themeCreator = require("screen.menu.theme_creator")

-- Module table to export public functions
local menu = {}

-- Screen switching
local switchScreen = nil

function menu.load()
	constants.BUTTON.WIDTH = state.screenWidth - (constants.BUTTON.PADDING * 2)
	constants.BUTTON.START_Y = constants.BUTTON.PADDING

	-- Initialize font selection based on state
	for _, font in ipairs(constants.FONTS) do
		font.selected = (font.name == state.selectedFont)
	end
end

function menu.draw()
	-- Set background
	love.graphics.setColor(colors.bg)
	love.graphics.clear()

	-- Draw all buttons based on their type
	local regularButtonCount = 0

	for _, button in ipairs(constants.BUTTONS) do
		local y = button.isBottomButton and state.screenHeight - constants.BUTTON.BOTTOM_MARGIN
			or constants.BUTTON.START_Y + regularButtonCount * (constants.BUTTON.HEIGHT + constants.BUTTON.PADDING)

		ui.drawButton(button, constants.BUTTON.PADDING, y, button.selected)

		if not button.isBottomButton then
			regularButtonCount = regularButtonCount + 1
		end
	end

	-- Draw error message if present
	ui.drawError()

	-- Draw popup if active
	if ui.isPopupVisible() then
		ui.drawPopup()
	end

	controls.draw({
		{ icon = "d_pad.png", text = "Navigate" },
		{ icon = "a.png", text = "Select" },
		{ icon = "y.png", text = "About" },
		{ icon = "b.png", text = "Exit" },
	})
end

function menu.update(dt)
	-- Update error timer
	errorHandler.update(dt)
	local virtualJoystick = require("input").virtualJoystick

	if ui.isPopupVisible() then
		if state.canProcessInput() then
			-- Handle navigation
			if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
				for _, button in ipairs(constants.POPUP_BUTTONS) do
					button.selected = not button.selected
				end
				state.resetInputTimer()
			end

			-- Handle selection
			if virtualJoystick:isGamepadDown("a") then
				for _, button in ipairs(constants.POPUP_BUTTONS) do
					if button.selected then
						if button.text == "Exit" then
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
	elseif virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
		local direction = virtualJoystick:isGamepadDown("dpleft") and -1 or 1

		-- Check if a font selection button is selected
		for _, button in ipairs(constants.BUTTONS) do
			if button.selected and button.fontSelection then
				-- Find the currently selected font
				local currentIndex = 1
				for i, font in ipairs(constants.FONTS) do
					if font.selected then
						currentIndex = i
						font.selected = false
						break
					end
				end

				-- Calculate the next font index based on direction
				local nextIndex = currentIndex + direction
				if nextIndex < 1 then
					nextIndex = #constants.FONTS
				elseif nextIndex > #constants.FONTS then
					nextIndex = 1
				end

				-- Select the new font
				constants.FONTS[nextIndex].selected = true
				state.selectedFont = constants.FONTS[nextIndex].name
				moved = true
				break
			end
		end
	end

	-- Handle B button (Exit)
	if virtualJoystick:isGamepadDown("b") then
		love.event.quit()
		return
	end

	-- Handle Y button (About)
	if virtualJoystick:isGamepadDown("y") and switchScreen then
		switchScreen(constants.ABOUT_SCREEN)
		state.resetInputTimer()
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
					-- Font selection button - cycle to next font
					local currentIndex = 1
					for i, font in ipairs(constants.FONTS) do
						if font.selected then
							currentIndex = i
							font.selected = false
							break
						end
					end

					-- Move to next font
					local nextIndex = currentIndex + 1
					if nextIndex > #constants.FONTS then
						nextIndex = 1
					end

					-- Select the new font
					constants.FONTS[nextIndex].selected = true
					state.selectedFont = constants.FONTS[nextIndex].name
					state.resetInputTimer()
				elseif button.colorKey and switchScreen then
					-- Any color selection button
					state.lastSelectedColorButton = button.colorKey
					switchScreen(constants.COLORPICKERPALETTE_SCREEN)
					state.resetInputTimer()
				elseif button.text == "Create theme" then
					-- Start theme creation
					local success = themeCreator.createTheme()

					-- Show result popup
					ui.showPopup(
						success
								and "Success! After exiting, apply your theme via Configuration > Customisation > muOS Themes."
							or "Error creating theme."
					)
				end
				break
			end
		end
	end
end

function menu.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function menu.setSelectedColor(buttonType, colorKey)
	if state.colors[buttonType] then
		state.colors[buttonType] = colorKey
	end
end

function menu.onExit()
	-- Clean up working directory when leaving menu screen
	themeCreator.cleanup()
end

return menu
