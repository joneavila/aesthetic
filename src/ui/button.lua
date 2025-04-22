--- Button drawing functions
--- This file contains code for drawing buttons used in various UI screens

local love = require("love")
local colors = require("colors")
local state = require("state")
local colorUtils = require("utils.color")
local UI_CONSTANTS = require("ui.constants")

-- Module table to export public functions
local button = {}

-- Function to draw a button
function button.draw(button, x, y, isSelected)
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
			drawWidth = state.screenWidth - UI_CONSTANTS.SCROLL_BAR_WIDTH - 20 -- Add 20px padding on right side
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

-- Set button width dynamically
function button.setWidth(width)
	UI_CONSTANTS.BUTTON.WIDTH = width
end

return button
