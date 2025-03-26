--- Menu UI drawing functions
local love = require("love")
local colors = require("colors")
local state = require("state")
local colorUtils = require("utils.color")

local constants = require("screen.menu.constants")
local errorHandler = require("screen.menu.error_handler")

-- Module table to export public functions
local ui = {}

-- Popup state variables
local showPopup = false
local popupMessage = ""
local popupButtons = {}
local popupVerticalButtons = false

-- Function to draw a button
function ui.drawButton(button, x, y, isSelected)
	-- Determine button width based on type
	local buttonWidth = state.screenWidth

	-- Draw button background only when selected (hovered)
	if isSelected then
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle("fill", 0, y, buttonWidth, constants.BUTTON.HEIGHT, 0)
	end

	-- Draw button text with different color when selected
	love.graphics.setFont(state.fonts.body)
	local textHeight = state.fonts.body:getHeight()

	love.graphics.setColor(colors.ui.foreground)

	love.graphics.print(button.text, x + 20, y + (constants.BUTTON.HEIGHT - textHeight) / 2)

	-- If this is a color selection button
	if button.colorKey then
		-- Get the color from state
		local hexColor = state.colors[button.colorKey]

		-- Only draw color display if we have a valid color
		if hexColor then
			-- Draw color square on the right side of the button
			local colorX = state.screenWidth - constants.BUTTON.COLOR_DISPLAY_SIZE - 20
			local colorY = y + (constants.BUTTON.HEIGHT - constants.BUTTON.COLOR_DISPLAY_SIZE) / 2

			local r, g, b = colorUtils.hexToRgb(hexColor)

			-- Draw color square
			love.graphics.setColor(r, g, b, 1)
			love.graphics.rectangle(
				"fill",
				colorX,
				colorY,
				constants.BUTTON.COLOR_DISPLAY_SIZE,
				constants.BUTTON.COLOR_DISPLAY_SIZE,
				4
			)

			-- Draw border around color square
			love.graphics.setColor(colors.ui.foreground)
			love.graphics.setLineWidth(1)
			love.graphics.rectangle(
				"line",
				colorX,
				colorY,
				constants.BUTTON.COLOR_DISPLAY_SIZE,
				constants.BUTTON.COLOR_DISPLAY_SIZE,
				4
			)

			-- Draw color hex code
			love.graphics.setColor(colors.ui.foreground)
			local hexCode = state.colors[button.colorKey]

			-- Use monospace font for hex codes
			if button.colorKey == "background" or button.colorKey == "foreground" then
				love.graphics.setFont(state.fonts.monoBody)
			end

			local hexWidth = love.graphics.getFont():getWidth(hexCode)
			love.graphics.print(
				hexCode,
				colorX - hexWidth - 10,
				y + (constants.BUTTON.HEIGHT - love.graphics.getFont():getHeight()) / 2
			)

			-- Reset to body font after printing hex code
			if button.colorKey == "background" or button.colorKey == "foreground" then
				love.graphics.setFont(state.fonts.body)
			end
		end
	-- If this is a font selection button
	elseif button.fontSelection then
		-- Get the selected font name from state
		local selectedFontName = state.selectedFont

		-- Calculate the right edge position
		local rightEdge = state.screenWidth - 20

		-- Use the appropriate font for measurement and display
		if selectedFontName == "Inter" then
			love.graphics.setFont(state.fonts.body)
		elseif selectedFontName == "Cascadia Code" then
			love.graphics.setFont(state.fonts.monoBody)
		elseif selectedFontName == "Retro Pixel" then
			love.graphics.setFont(state.fonts.retroPixel)
		else
			love.graphics.setFont(state.fonts.nunito)
		end

		-- Calculate font name width for positioning
		local fontNameWidth = love.graphics.getFont():getWidth(selectedFontName)

		-- Position the font name at the right edge
		local fontNameX = rightEdge - fontNameWidth
		local fontNameY = y + (constants.BUTTON.HEIGHT - love.graphics.getFont():getHeight()) / 2

		love.graphics.setColor(colors.ui.foreground)

		-- Draw font name
		love.graphics.print(selectedFontName, fontNameX, fontNameY)

		-- Reset font
		love.graphics.setFont(state.fonts.body)
	end
end

-- Popup drawing function
function ui.drawPopup()
	-- Draw semi-transparent background
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.8)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)

	-- Calculate popup dimensions based on text
	local padding = 40
	local maxWidth = state.screenWidth * 0.9 -- Maximum width is 90% of screen width
	-- Minimum width is 80% of screen width, but not more than maxWidth
	local minWidth = math.min(state.screenWidth * 0.8, maxWidth)
	local minHeight = state.screenHeight * 0.3

	-- Set font for text measurement
	love.graphics.setFont(state.fonts.body)

	-- Calculate available width for text
	local availableTextWidth = minWidth - (padding * 2)

	-- Get wrapped text info
	local _, lines = state.fonts.body:getWrap(popupMessage, availableTextWidth)
	local textHeight = #lines * state.fonts.body:getHeight()

	-- Calculate final popup dimensions
	local popupWidth = minWidth -- Always use the minimum width to ensure consistent wrapping
	local buttonHeight = 40
	local buttonSpacing = 20

	-- Calculate extra height needed for buttons based on layout
	local buttonsExtraHeight = buttonHeight + padding
	if popupVerticalButtons then
		buttonsExtraHeight = (#popupButtons * buttonHeight) + ((#popupButtons - 1) * buttonSpacing) + padding
	end
	local popupHeight = math.max(minHeight, textHeight + (padding * 2) + buttonsExtraHeight)

	local x = (state.screenWidth - popupWidth) / 2
	local y = (state.screenHeight - popupHeight) / 2

	-- Draw popup background
	love.graphics.setColor(colors.ui.background)
	love.graphics.rectangle("fill", x, y, popupWidth, popupHeight, 10)

	-- Draw popup border
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, popupWidth, popupHeight, 10)

	-- Draw message with wrapping
	local textY = y + padding
	love.graphics.printf(popupMessage, x + padding, textY, availableTextWidth, "center")

	-- Draw buttons
	local buttonWidth = 300

	if popupVerticalButtons then
		-- Draw buttons vertically stacked
		local buttonX = (state.screenWidth - buttonWidth) / 2
		local startButtonY = y + padding + textHeight + padding

		for i, button in ipairs(popupButtons) do
			local buttonY = startButtonY + ((i - 1) * (buttonHeight + buttonSpacing))

			-- Draw button background
			if button.selected then
				love.graphics.setColor(colors.ui.surface)
			else
				love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 0.1)
			end
			love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

			-- Draw button border
			love.graphics.setColor(
				colors.ui.foreground[1],
				colors.ui.foreground[2],
				colors.ui.foreground[3],
				button.selected and 1 or 0.5
			)
			love.graphics.setLineWidth(button.selected and 3 or 1)
			love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5)

			-- Draw button text
			love.graphics.setColor(colors.ui.foreground)
			love.graphics.printf(
				button.text,
				buttonX,
				buttonY + (buttonHeight - state.fonts.body:getHeight()) / 2,
				buttonWidth,
				"center"
			)
		end
	else
		-- Draw buttons horizontally
		local buttonY = y + popupHeight - buttonHeight - padding
		local spacing = 20
		local totalButtonsWidth = (#popupButtons * buttonWidth) + ((#popupButtons - 1) * spacing)
		local buttonX = (state.screenWidth - totalButtonsWidth) / 2

		for _, button in ipairs(popupButtons) do
			-- Draw button background
			if button.selected then
				love.graphics.setColor(colors.ui.surface)
			else
				love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 0.1)
			end
			love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

			-- Draw button border
			love.graphics.setColor(
				colors.ui.foreground[1],
				colors.ui.foreground[2],
				colors.ui.foreground[3],
				button.selected and 1 or 0.5
			)
			love.graphics.setLineWidth(button.selected and 3 or 1)
			love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5)

			-- Draw button text
			love.graphics.setColor(colors.ui.foreground)
			love.graphics.printf(
				button.text,
				buttonX,
				buttonY + (buttonHeight - state.fonts.body:getHeight()) / 2,
				buttonWidth,
				"center"
			)

			buttonX = buttonX + buttonWidth + spacing
		end
	end
end

-- Draw error message if present
function ui.drawError()
	local errorMessage = errorHandler.getErrorMessage()
	if errorMessage then
		love.graphics.push()

		-- Use a smaller font
		local smallFont = love.graphics.newFont(14)
		love.graphics.setFont(smallFont)

		-- Calculate dimensions for error box
		local padding = 10
		local maxWidth = state.screenWidth - (padding * 2)

		-- Wrap the text
		local wrappedText = love.graphics.newText(smallFont)
		wrappedText:setf(errorMessage, maxWidth, "left")
		local textHeight = wrappedText:getHeight()

		-- Draw semi-transparent background
		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.rectangle("fill", padding, padding, maxWidth, textHeight + (padding * 2))

		-- Draw error text
		love.graphics.setColor(1, 0.3, 0.3, 1) -- Red-ish color
		love.graphics.draw(wrappedText, padding * 2, padding * 2)

		love.graphics.pop()
	end
end

-- Show popup with message
function ui.showPopup(message, buttons, verticalButtons)
	showPopup = true
	popupMessage = message
	popupButtons = buttons or constants.POPUP_BUTTONS
	popupVerticalButtons = verticalButtons or false
end

-- Hide popup
function ui.hidePopup()
	showPopup = false
end

-- Check if popup is visible
function ui.isPopupVisible()
	return showPopup
end

-- Get popup message
function ui.getPopupMessage()
	return popupMessage
end

-- Get popup buttons
function ui.getPopupButtons()
	return popupButtons
end

-- Set popup buttons
function ui.setPopupButtons(buttons)
	popupButtons = buttons
end

return ui
