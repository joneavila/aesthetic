--- Button drawing functions
--- This file contains code for drawing buttons used in various UI screens
local state = require("state")
local love = require("love")
local colors = require("colors")
local colorUtils = require("utils.color")
local UI_CONSTANTS = require("ui.constants")

-- Module table to export public functions
local button = {}

local TRIANGLE = {
	HEIGHT = 20,
	WIDTH = 12,
	PADDING = 16,
}

-- Internal helper functions for drawing button backgrounds and base text
local function drawButtonBackground(y, width, isSelected)
	if isSelected then
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle("fill", 10, y, width, UI_CONSTANTS.BUTTON.HEIGHT, UI_CONSTANTS.BUTTON.CORNER_RADIUS)
	end
end

local function drawButtonText(text, x, y, isDisabled)
	local textHeight = love.graphics.getFont():getHeight()
	local opacity = isDisabled and 0.3 or 1
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(text, x + 20, y + (UI_CONSTANTS.BUTTON.HEIGHT - textHeight) / 2)
end

-- Function to calculate button dimensions and edges
local function calculateButtonDimensions(x, buttonWidth, screenWidth, isSelected)
	-- Define consistent padding for text and content
	local leftPadding = 20
	local rightPadding = 0 -- Consistent padding for right-aligned content

	-- If there's no scrollbar needed, reduce right padding to match left
	-- and adjust the right edge position for content
	local hasFullWidth = buttonWidth >= screenWidth - UI_CONSTANTS.BUTTON.PADDING
	local rightEdge = x + buttonWidth - rightPadding

	-- When no scrollbar, position content from the screen edge
	if hasFullWidth then
		rightPadding = leftPadding
		rightEdge = screenWidth - rightPadding
	end

	-- For selected buttons, determine draw width for background
	local drawWidth
	if isSelected then
		if hasFullWidth then
			drawWidth = screenWidth - 20 -- Add 20px padding on both sides
		else
			drawWidth = screenWidth - UI_CONSTANTS.SCROLL_BAR_WIDTH - 20 -- Add 20px padding on right side
		end
	end

	return {
		drawWidth = drawWidth,
		rightEdge = rightEdge,
		hasFullWidth = hasFullWidth,
	}
end

-- Base function to draw a button (no right side content)
function button.draw(text, x, y, isSelected, screenWidth)
	local dimensions = calculateButtonDimensions(x, UI_CONSTANTS.BUTTON.WIDTH, screenWidth, isSelected)
	drawButtonBackground(y, dimensions.drawWidth, isSelected)
	drawButtonText(text, x, y, false)
end

-- Function to draw a button with right-aligned text
function button.drawWithTextPreview(text, x, y, isSelected, screenWidth, previewText)
	local dimensions = calculateButtonDimensions(x, UI_CONSTANTS.BUTTON.WIDTH, screenWidth, isSelected)

	drawButtonBackground(y, dimensions.drawWidth, isSelected)
	drawButtonText(text, x, y, false)

	-- Draw right text
	local textWidth = love.graphics.getFont():getWidth(previewText)
	local textY = y + (UI_CONSTANTS.BUTTON.HEIGHT - love.graphics.getFont():getHeight()) / 2

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.print(previewText, dimensions.rightEdge - textWidth, textY)
end

-- Function to draw a button with triangle indicators for selecting values
function button.drawWithIndicators(text, x, y, isSelected, isDisabled, screenWidth, valueText)
	local dimensions = calculateButtonDimensions(x, UI_CONSTANTS.BUTTON.WIDTH, screenWidth, isSelected)

	-- Draw background
	drawButtonBackground(y, dimensions.drawWidth, isSelected)

	-- Draw button text
	drawButtonText(text, x, y, isDisabled)

	-- Draw value with triangles on the right side
	local textWidth = love.graphics.getFont():getWidth(valueText)

	-- Calculate total width of the text and triangles
	local totalWidth = textWidth + (TRIANGLE.WIDTH + TRIANGLE.PADDING) * 2

	-- Position at the right edge of the screen with padding
	local rightEdge = dimensions.rightEdge
	local valueX = rightEdge - totalWidth

	-- Draw triangles (left and right arrows)
	local triangleY = y + UI_CONSTANTS.BUTTON.HEIGHT / 2
	local opacity = isDisabled and 0.3 or 1

	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)

	-- Left triangle (pointing left)
	love.graphics.polygon(
		"fill",
		valueX + TRIANGLE.WIDTH,
		triangleY - TRIANGLE.HEIGHT / 2,
		valueX + TRIANGLE.WIDTH,
		triangleY + TRIANGLE.HEIGHT / 2,
		valueX,
		triangleY
	)

	-- Draw the text after the left triangle
	love.graphics.print(
		valueText,
		valueX + TRIANGLE.WIDTH + TRIANGLE.PADDING,
		y + (UI_CONSTANTS.BUTTON.HEIGHT - love.graphics.getFont():getHeight()) / 2
	)

	-- Right triangle (pointing right)
	love.graphics.polygon(
		"fill",
		rightEdge - TRIANGLE.WIDTH,
		triangleY - TRIANGLE.HEIGHT / 2,
		rightEdge - TRIANGLE.WIDTH,
		triangleY + TRIANGLE.HEIGHT / 2,
		rightEdge,
		triangleY
	)
end

-- Function to draw a button with color preview
function button.drawWithColorPreview(text, isSelected, x, y, screenWidth, hexColor, isDisabled)
	local dimensions = calculateButtonDimensions(x, UI_CONSTANTS.BUTTON.WIDTH, screenWidth, isSelected)

	-- Draw background
	drawButtonBackground(y, dimensions.drawWidth, isSelected)

	-- Draw button text
	drawButtonText(text, x, y, isDisabled)

	-- Only draw color display if we have a valid color
	if hexColor then
		-- Draw color square on the right side of the button with consistent padding
		local colorX = dimensions.rightEdge - UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE
		local colorY = y + (UI_CONSTANTS.BUTTON.HEIGHT - UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE) / 2

		local r, g, b = colorUtils.hexToRgb(hexColor)
		local opacity = isDisabled and 0.5 or 1

		-- Draw color square
		love.graphics.setColor(r, g, b, opacity)
		love.graphics.rectangle(
			"fill",
			colorX,
			colorY,
			UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE,
			UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE,
			UI_CONSTANTS.BUTTON.CORNER_RADIUS / 2 -- Using half the button corner radius for the color square
		)

		-- Draw border around color square
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle(
			"line",
			colorX,
			colorY,
			UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE,
			UI_CONSTANTS.BUTTON.COLOR_DISPLAY_SIZE,
			UI_CONSTANTS.BUTTON.CORNER_RADIUS / 2 -- Using half the button corner radius for the color square
		)

		-- Draw color hex code
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
		local hexCode = hexColor

		-- Use monospace font for hex codes if provided
		local originalFont = love.graphics.getFont()

		love.graphics.setFont(state.fonts.monoBody)

		local hexWidth = love.graphics.getFont():getWidth(hexCode)
		love.graphics.print(
			hexCode,
			colorX - hexWidth - 10,
			y + (UI_CONSTANTS.BUTTON.HEIGHT - love.graphics.getFont():getHeight()) / 2
		)

		-- Reset to original font after printing hex code
		love.graphics.setFont(originalFont)
	end
end

-- Function to draw an accented centered button (like "Create theme")
function button.drawAccented(text, isSelected, y, screenWidth, buttonWidth)
	local font = love.graphics.getFont()
	local padding = 20
	local textWidth = font:getWidth(text)

	-- Use provided buttonWidth or calculate default
	buttonWidth = buttonWidth or (textWidth + (180 * 2))

	local buttonX = (screenWidth - buttonWidth) / 2
	local cornerRadius = UI_CONSTANTS.BUTTON.CORNER_RADIUS
	local buttonHeight = UI_CONSTANTS.BUTTON.HEIGHT

	if isSelected then
		-- Selected state: accent background, background text
		love.graphics.setColor(colors.ui.accent)
		love.graphics.rectangle("fill", buttonX, y, buttonWidth, buttonHeight, cornerRadius)

		-- Draw text
		love.graphics.setColor(colors.ui.background)
		love.graphics.print(text, buttonX + (buttonWidth - textWidth) / 2, y + (buttonHeight - font:getHeight()) / 2)
	else
		-- Unselected state: background with surface outline
		love.graphics.setColor(colors.ui.background)
		love.graphics.rectangle("fill", buttonX, y, buttonWidth, buttonHeight, cornerRadius)

		-- Draw outline
		love.graphics.setColor(colors.ui.surface)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", buttonX, y, buttonWidth, buttonHeight, cornerRadius)

		-- Draw text
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(text, buttonX + (buttonWidth - textWidth) / 2, y + (buttonHeight - font:getHeight()) / 2)
	end
end

-- Set button width dynamically
function button.setWidth(width)
	UI_CONSTANTS.BUTTON.WIDTH = width
end

return button
