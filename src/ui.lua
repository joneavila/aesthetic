--- UI drawing functions
--- This file contains code for drawing UI elements that are shared throughout different screens, e.g., buttons
local love = require("love")
local colors = require("colors")
local state = require("state")
local colorUtils = require("utils.color")

-- Module table to export public functions
local ui = {}

-- Define the scrollbar width (must match the value in menu.lua)
local scrollBarWidth = 10

-- Use constants from the shared constants file instead of menu
local UI_CONSTANTS = require("ui.constants")

-- Popup state variables
local showPopup = false
local popupMessage = ""
local popupButtons = {}
local popupVerticalButtons = false

-- Function to draw a button
function ui.drawButton(button, x, y, isSelected)
	-- Determine button width based on type
	local buttonWidth = UI_CONSTANTS.BUTTON.WIDTH

	-- Define consistent padding for text and content
	local leftPadding = 20
	local rightPadding = 0 -- Consistent padding for right-aligned content

	-- If there's no scrollbar needed, reduce right padding to match left
	-- and adjust the right edge position for content
	local hasFullWidth = buttonWidth >= state.screenWidth - UI_CONSTANTS.BUTTON.PADDING
	local rightEdge = x + buttonWidth - rightPadding

	-- When no scrollbar, position content from the screen edge
	if hasFullWidth then
		rightPadding = leftPadding
		rightEdge = state.screenWidth - rightPadding
	end

	-- For selected buttons, check if we need to draw the background to the edge
	local drawWidth
	if isSelected then
		-- If there's no scrollbar needed (width is almost full screen width),
		-- extend the background to the right edge of the screen
		if hasFullWidth then
			drawWidth = state.screenWidth - 20 -- Add 20px padding on both sides
		else
			-- When scrollbar is present, extend background to right edge of screen
			drawWidth = state.screenWidth - scrollBarWidth - 20 -- Add 20px padding on right side
		end

		-- Draw background with rounded corners (8px radius)
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle("fill", 10, y, drawWidth, UI_CONSTANTS.BUTTON.HEIGHT, 8)
	end

	-- Draw button text with different color when selected
	love.graphics.setFont(state.fonts.body)
	local textHeight = state.fonts.body:getHeight()

	love.graphics.setColor(colors.ui.foreground)

	love.graphics.print(button.text, x + leftPadding, y + (UI_CONSTANTS.BUTTON.HEIGHT - textHeight) / 2)

	-- If this is a color selection button
	if button.colorKey then
		-- Get the color from state
		local hexColor = state.getColorValue(button.colorKey)

		-- Only draw color display if we have a valid color
		if hexColor then
			-- Draw color square on the right side of the button with consistent padding
			local colorX = rightEdge - UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE
			local colorY = y + (UI_CONSTANTS.BUTTON.HEIGHT - UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE) / 2

			local r, g, b = colorUtils.hexToRgb(hexColor)

			-- Draw color square
			love.graphics.setColor(r, g, b, 1)
			love.graphics.rectangle(
				"fill",
				colorX,
				colorY,
				UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE,
				UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE,
				4
			)

			-- Draw border around color square
			love.graphics.setColor(colors.ui.foreground)
			love.graphics.setLineWidth(1)
			love.graphics.rectangle(
				"line",
				colorX,
				colorY,
				UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE,
				UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE,
				4
			)

			-- Draw color hex code
			love.graphics.setColor(colors.ui.foreground)
			local hexCode = state.getColorValue(button.colorKey)

			-- Use monospace font for hex codes
			if button.colorKey == "background" or button.colorKey == "foreground" then
				love.graphics.setFont(state.fonts.monoBody)
			end

			local hexWidth = love.graphics.getFont():getWidth(hexCode)
			love.graphics.print(
				hexCode,
				colorX - hexWidth - 10,
				y + (UI_CONSTANTS.BUTTON.HEIGHT - love.graphics.getFont():getHeight()) / 2
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

		-- Use the appropriate font for measurement and display
		love.graphics.setFont(state.getFontByName(selectedFontName))

		-- Position the font name with consistent padding
		local fontNameWidth = love.graphics.getFont():getWidth(selectedFontName)
		local fontNameY = y + (UI_CONSTANTS.BUTTON.HEIGHT - love.graphics.getFont():getHeight()) / 2
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(selectedFontName, rightEdge - fontNameWidth, fontNameY)

		-- Reset font
		love.graphics.setFont(state.fonts.body)
	elseif button.fontSizeToggle then
		-- Get the selected font size from state
		local selectedFontSize = state.fontSize

		local fontSizeWidth = state.fonts.body:getWidth(selectedFontSize)
		local fontSizeY = y + (UI_CONSTANTS.BUTTON.HEIGHT - state.fonts.body:getHeight()) / 2

		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(selectedFontSize, rightEdge - fontSizeWidth, fontSizeY)
	elseif button.glyphsToggle then
		-- Get glyphs state
		local statusText = state.glyphs_enabled and "Enabled" or "Disabled"

		local statusWidth = state.fonts.body:getWidth(statusText)
		local statusY = y + (UI_CONSTANTS.BUTTON.HEIGHT - state.fonts.body:getHeight()) / 2

		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(statusText, rightEdge - statusWidth, statusY)
	elseif button.boxArt then
		-- Draw box art width value on right
		local boxArtText = state.boxArtWidth
		if boxArtText == "Disabled" then
			boxArtText = "0 (Disabled)"
		end

		local statusWidth = state.fonts.body:getWidth(boxArtText)
		local statusY = y + (UI_CONSTANTS.BUTTON.HEIGHT - state.fonts.body:getHeight()) / 2

		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(boxArtText, rightEdge - statusWidth, statusY)
	elseif button.rgbLighting then
		-- Get RGB lighting state
		local statusText = state.rgbMode
		-- Do not display the brightness level if mode is set to "Off"
		if state.rgbMode ~= "Off" then
			statusText = statusText .. " (" .. state.rgbBrightness .. ")"
		end

		local statusWidth = state.fonts.body:getWidth(statusText)
		local statusY = y + (UI_CONSTANTS.BUTTON.HEIGHT - state.fonts.body:getHeight()) / 2

		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(statusText, rightEdge - statusWidth, statusY)
	end
end

-- Popup drawing function
function ui.drawPopup()
	-- Draw semi-transparent background
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.9)
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
	love.graphics.setColor(colors.ui.surface)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, popupWidth, popupHeight, 10)

	-- Draw message with wrapping
	love.graphics.setColor(colors.ui.foreground)
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
			local isSelected = button.selected

			-- Draw button background
			love.graphics.setColor(isSelected and colors.ui.surface or colors.ui.background)
			love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

			-- Draw button outline
			love.graphics.setLineWidth(isSelected and 4 or 2)
			love.graphics.setColor(colors.ui.surface)
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
			local isSelected = button.selected

			-- Draw button background
			love.graphics.setColor(isSelected and colors.ui.surface or colors.ui.background)
			love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

			-- Draw button outline
			love.graphics.setLineWidth(isSelected and 4 or 2)
			love.graphics.setColor(colors.ui.surface)
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

-- Set button width dynamically
function ui.setButtonWidth(width)
	UI_CONSTANTS.BUTTON.WIDTH = width
end

-- Show popup with message
function ui.showPopup(message, buttons, verticalButtons)
	showPopup = true
	popupMessage = message
	popupButtons = buttons or UI_CONSTANTS.POPUP_BUTTONS
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
