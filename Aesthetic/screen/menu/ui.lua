--- Menu UI drawing functions
local love = require("love")
local colors = require("colors")
local state = require("state")

local constants = require("screen.menu.constants")
local errorHandler = require("screen.menu.error_handler")

-- Module table to export public functions
local ui = {}

-- Popup state variables
local showPopup = false
local popupMessage = ""

-- Function to draw a button
function ui.drawButton(button, x, y, isSelected)
	if button.isHelp then
		-- Draw help button as a circle
		local radius = constants.BUTTON.HELP_BUTTON_SIZE / 2

		-- Draw button background
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], isSelected and 0.3 or 0.2)
		love.graphics.circle("fill", x + radius, y + radius, radius)

		-- Draw button outline
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], isSelected and 1 or 0.5)
		love.graphics.setLineWidth(isSelected and constants.BUTTON.SELECTED_OUTLINE_WIDTH or 2)
		love.graphics.circle("line", x + radius, y + radius, radius)

		-- Draw question mark
		love.graphics.setFont(state.fonts.body)
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
		local textWidth = state.fonts.body:getWidth("?")
		local textHeight = state.fonts.body:getHeight()
		love.graphics.print("?", x + radius - textWidth / 2, y + radius - textHeight / 2)
		return
	end

	-- Draw button background
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 0.2)
	love.graphics.rectangle(
		"fill",
		x,
		y,
		constants.BUTTON.WIDTH,
		constants.BUTTON.HEIGHT,
		constants.BUTTON.CORNER_RADIUS
	)

	-- Draw button outline (thicker if selected)
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], isSelected and 1 or 0.5)
	love.graphics.setLineWidth(isSelected and constants.BUTTON.SELECTED_OUTLINE_WIDTH or 2)
	love.graphics.rectangle(
		"line",
		x,
		y,
		constants.BUTTON.WIDTH,
		constants.BUTTON.HEIGHT,
		constants.BUTTON.CORNER_RADIUS
	)

	-- Draw button text
	love.graphics.setFont(state.fonts.body)
	local textHeight = state.fonts.body:getHeight()
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
	love.graphics.print(button.text, x + 20, y + (constants.BUTTON.HEIGHT - textHeight) / 2)

	-- If this is a color selection button
	if button.colorKey then
		-- Get the color from state
		local selectedColor = state.colors[button.colorKey]

		-- Only draw color display if we have a valid color
		if selectedColor and colors[selectedColor] then
			-- Draw color square on the right side of the button
			local colorX = x + constants.BUTTON.WIDTH - constants.BUTTON.COLOR_DISPLAY_SIZE - 20
			local colorY = y + (constants.BUTTON.HEIGHT - constants.BUTTON.COLOR_DISPLAY_SIZE) / 2

			-- Draw color square
			love.graphics.setColor(colors[selectedColor][1], colors[selectedColor][2], colors[selectedColor][3], 1)
			love.graphics.rectangle(
				"fill",
				colorX,
				colorY,
				constants.BUTTON.COLOR_DISPLAY_SIZE,
				constants.BUTTON.COLOR_DISPLAY_SIZE,
				4
			)

			-- Draw border around color square
			love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
			love.graphics.setLineWidth(1)
			love.graphics.rectangle(
				"line",
				colorX,
				colorY,
				constants.BUTTON.COLOR_DISPLAY_SIZE,
				constants.BUTTON.COLOR_DISPLAY_SIZE,
				4
			)

			-- Draw color name
			local nameWidth = state.fonts.body:getWidth(colors.names[selectedColor])
			love.graphics.print(
				colors.names[selectedColor],
				colorX - nameWidth - 10,
				y + (constants.BUTTON.HEIGHT - textHeight) / 2
			)
		end
	-- If this is a font selection button
	elseif button.fontSelection then
		-- Get the selected font name from state
		local selectedFontName = state.selectedFont

		-- Calculate the right edge position
		local rightEdge = x + constants.BUTTON.WIDTH - 20

		-- Use the appropriate font for measurement and display
		if selectedFontName == "Inter" then
			love.graphics.setFont(state.fonts.body)
		else
			love.graphics.setFont(state.fonts.nunito)
		end

		-- Calculate font name width for positioning
		local fontNameWidth = love.graphics.getFont():getWidth(selectedFontName)

		-- Calculate positions for all elements
		local arrowWidth = 10
		local arrowSpacing = 15

		-- Fix: Add extra spacing to the right arrow to balance the visual gaps
		local rightArrowExtraSpacing = 8

		-- Position elements at the right edge
		local arrowY = y + (constants.BUTTON.HEIGHT / 2)

		-- Calculate total width needed
		local totalWidth = fontNameWidth + (2 * arrowSpacing) + rightArrowExtraSpacing + (2 * arrowWidth)

		-- Calculate starting position from right edge
		local startX = rightEdge - totalWidth

		-- Position each element with exact spacing
		local leftArrowX = startX
		local fontNameX = leftArrowX + arrowWidth + arrowSpacing
		local rightArrowX = fontNameX + fontNameWidth + arrowSpacing + rightArrowExtraSpacing

		local fontNameY = y + (constants.BUTTON.HEIGHT - love.graphics.getFont():getHeight()) / 2

		-- Draw left arrow
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
		love.graphics.polygon(
			"fill",
			leftArrowX,
			arrowY,
			leftArrowX + arrowWidth,
			arrowY - arrowWidth,
			leftArrowX + arrowWidth,
			arrowY + arrowWidth
		)

		-- Draw font name
		love.graphics.print(selectedFontName, fontNameX, fontNameY)

		-- Draw right arrow
		love.graphics.polygon(
			"fill",
			rightArrowX,
			arrowY,
			rightArrowX - arrowWidth,
			arrowY - arrowWidth,
			rightArrowX - arrowWidth,
			arrowY + arrowWidth
		)

		-- Reset font
		love.graphics.setFont(state.fonts.body)
	end
end

-- Popup drawing function
function ui.drawPopup()
	-- Draw semi-transparent background
	love.graphics.setColor(0, 0, 0, 0.8)
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
	local popupHeight = math.max(minHeight, textHeight + (padding * 4) + 50) -- Extra space for buttons

	local x = (state.screenWidth - popupWidth) / 2
	local y = (state.screenHeight - popupHeight) / 2

	-- Draw popup background
	love.graphics.setColor(colors.bg[1], colors.bg[2], colors.bg[3], 1)
	love.graphics.rectangle("fill", x, y, popupWidth, popupHeight, 10)

	-- Draw popup border
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, popupWidth, popupHeight, 10)

	-- Draw message with wrapping
	local textY = y + padding
	love.graphics.printf(popupMessage, x + padding, textY, availableTextWidth, "center")

	-- Draw buttons
	local buttonWidth = 150
	local buttonHeight = 40
	local buttonY = y + popupHeight - buttonHeight - padding
	local spacing = 20
	local totalButtonsWidth = (#constants.POPUP_BUTTONS * buttonWidth) + ((#constants.POPUP_BUTTONS - 1) * spacing)
	local buttonX = (state.screenWidth - totalButtonsWidth) / 2

	for _, button in ipairs(constants.POPUP_BUTTONS) do
		-- Draw button background
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], button.selected and 0.3 or 0.1)
		love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

		-- Draw button border
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], button.selected and 1 or 0.5)
		love.graphics.setLineWidth(button.selected and 3 or 1)
		love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5)

		-- Draw button text
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
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
function ui.showPopup(message)
	showPopup = true
	popupMessage = message
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

return ui
