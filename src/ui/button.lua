--- Button drawing functions
--- This file contains code for drawing buttons used in various UI screens
local love = require("love")
local colors = require("colors")
local colorUtils = require("utils.color")

-- Button constants
local BUTTON = {
	VERTICAL_PADDING = 12, -- Padding above and below text
	SPACING = 12, -- Used for vertical spacing between list items
	EDGE_MARGIN = 16, -- Horizontal padding from screen edges
	HORIZONTAL_PADDING = 14, -- Internal horizontal padding for text and content
	CORNER_RADIUS = 8,
	SELECTED_OUTLINE_WIDTH = 4,
}

-- Module table to export public functions
local button = {}

local TRIANGLE = {
	HEIGHT = 20,
	WIDTH = 12,
	PADDING = 16,
}

-- Function to calculate button height based on current font
local function calculateButtonHeight()
	local font = love.graphics.getFont()
	return font:getHeight() + (BUTTON.VERTICAL_PADDING * 2)
end

-- Internal helper functions for drawing button backgrounds and base text
local function drawButtonBackground(y, width, isSelected)
	if isSelected then
		love.graphics.setColor(colors.ui.surface)
		local height = calculateButtonHeight()
		love.graphics.rectangle("fill", BUTTON.EDGE_MARGIN, y, width, height, BUTTON.CORNER_RADIUS)
	end
end

local function drawButtonText(text, x, y, isDisabled)
	local font = love.graphics.getFont()
	local textHeight = font:getHeight()
	local buttonHeight = calculateButtonHeight()
	local opacity = isDisabled and 0.3 or 1
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(text, x + BUTTON.EDGE_MARGIN + BUTTON.HORIZONTAL_PADDING, y + (buttonHeight - textHeight) / 2)
end

-- Function to calculate button dimensions and edges
local function calculateButtonDimensions(x, buttonWidth, screenWidth, isSelected)
	-- Import scroll bar width once at the start since we need it for calculations
	local scrollView = require("ui.scroll_view")

	-- Define consistent padding using EDGE_MARGIN
	local leftPadding = BUTTON.EDGE_MARGIN

	-- Default buttonWidth to screenWidth if not provided
	buttonWidth = buttonWidth or screenWidth

	-- Calculate available width (excluding margins)
	local availableWidth
	if buttonWidth >= screenWidth - (BUTTON.EDGE_MARGIN * 2) then
		-- Full width case: screen width minus margins on both sides
		availableWidth = screenWidth - (BUTTON.EDGE_MARGIN * 2)
	else
		-- Scrollbar case: screen width minus scrollbar, minus margins
		availableWidth = screenWidth - scrollView.SCROLL_BAR_WIDTH - (BUTTON.EDGE_MARGIN * 2)
	end

	-- Determine if we're in full width mode
	local hasFullWidth = buttonWidth >= availableWidth

	-- Calculate the right edge position for content
	local rightEdge
	if hasFullWidth then
		rightEdge = screenWidth - BUTTON.EDGE_MARGIN - scrollView.SCROLL_BAR_WIDTH
	else
		rightEdge = x + buttonWidth
	end

	-- For selected buttons, determine draw width for background
	local drawWidth
	if isSelected then
		if hasFullWidth then
			drawWidth = screenWidth - scrollView.SCROLL_BAR_WIDTH - (BUTTON.EDGE_MARGIN * 2)
		else
			drawWidth = buttonWidth
		end
	end

	return {
		drawWidth = drawWidth,
		rightEdge = rightEdge,
		hasFullWidth = hasFullWidth,
	}
end

-- Base function to draw a button (no right side content)
function button.draw(text, x, y, isSelected, screenWidth, buttonWidth)
	local dimensions = calculateButtonDimensions(x, buttonWidth, screenWidth, isSelected)
	drawButtonBackground(y, dimensions.drawWidth, isSelected)
	drawButtonText(text, x, y, false)
end

-- Function to draw a button with right-aligned text
function button.drawWithTextPreview(text, x, y, isSelected, screenWidth, previewText, buttonWidth)
	local dimensions = calculateButtonDimensions(x, buttonWidth, screenWidth, isSelected)
	drawButtonBackground(y, dimensions.drawWidth, isSelected)
	drawButtonText(text, x, y, false)

	-- Draw right (preview) text
	local buttonHeight = calculateButtonHeight()
	local textWidth = love.graphics.getFont():getWidth(previewText)
	local textY = y + (buttonHeight - love.graphics.getFont():getHeight()) / 2
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.print(previewText, dimensions.rightEdge - textWidth - BUTTON.HORIZONTAL_PADDING, textY)
end

-- Function to draw a button with triangle indicators for selecting values
function button.drawWithIndicators(text, x, y, isSelected, isDisabled, screenWidth, valueText, buttonWidth)
	local dimensions = calculateButtonDimensions(x, buttonWidth, screenWidth, isSelected)
	drawButtonBackground(y, dimensions.drawWidth, isSelected)
	drawButtonText(text, x, y, isDisabled)
	local textWidth = love.graphics.getFont():getWidth(valueText)
	local totalWidth = textWidth + (TRIANGLE.WIDTH + TRIANGLE.PADDING) * 2
	local rightEdge = dimensions.rightEdge - BUTTON.HORIZONTAL_PADDING
	local valueX = rightEdge - totalWidth
	local buttonHeight = calculateButtonHeight()
	local triangleY = y + buttonHeight / 2
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

	-- Draw text
	love.graphics.print(
		valueText,
		valueX + TRIANGLE.WIDTH + TRIANGLE.PADDING,
		y + (buttonHeight - love.graphics.getFont():getHeight()) / 2
	)
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
function button.drawWithColorPreview(text, isSelected, x, y, screenWidth, hexColor, isDisabled, monoFont, buttonWidth)
	local COLOR_DISPLAY_SIZE = 30
	local dimensions = calculateButtonDimensions(x, buttonWidth, screenWidth, isSelected)
	drawButtonBackground(y, dimensions.drawWidth, isSelected)
	drawButtonText(text, x, y, isDisabled)

	-- Only draw color display if we have a valid color
	if hexColor then
		-- Draw color square
		local buttonHeight = calculateButtonHeight()
		local colorX = dimensions.rightEdge - COLOR_DISPLAY_SIZE - BUTTON.HORIZONTAL_PADDING
		local colorY = y + (buttonHeight - COLOR_DISPLAY_SIZE) / 2

		local r, g, b = colorUtils.hexToRgb(hexColor)
		local opacity = isDisabled and 0.5 or 1

		love.graphics.setColor(r, g, b, opacity)
		love.graphics.rectangle(
			"fill",
			colorX,
			colorY,
			COLOR_DISPLAY_SIZE,
			COLOR_DISPLAY_SIZE,
			BUTTON.CORNER_RADIUS / 2 -- Using half the button corner radius for the color square
		)

		-- Draw border around color square
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle(
			"line",
			colorX,
			colorY,
			COLOR_DISPLAY_SIZE,
			COLOR_DISPLAY_SIZE,
			BUTTON.CORNER_RADIUS / 2 -- Using half the button corner radius for the color square
		)

		-- Draw color hex code
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
		local hexCode = hexColor

		-- Use monospace font for hex codes if provided
		local originalFont = love.graphics.getFont()
		if monoFont then
			love.graphics.setFont(monoFont)
		end
		local hexWidth = love.graphics.getFont():getWidth(hexCode)
		love.graphics.print(
			hexCode,
			colorX - hexWidth - 10,
			y + (buttonHeight - love.graphics.getFont():getHeight()) / 2
		)

		-- Reset to original font
		love.graphics.setFont(originalFont)
	end
end

-- Function to draw an accented centered button
function button.drawAccented(text, isSelected, y, screenWidth, buttonWidth)
	local font = love.graphics.getFont()
	local textWidth = font:getWidth(text)

	-- Use provided buttonWidth or calculate default
	buttonWidth = buttonWidth or (textWidth + (180 * 2))

	local buttonX = (screenWidth - buttonWidth) / 2
	local cornerRadius = BUTTON.CORNER_RADIUS
	local buttonHeight = calculateButtonHeight()

	if isSelected then
		-- Selected state: accent background, background text
		love.graphics.setColor(colors.ui.accent)
		love.graphics.rectangle("fill", buttonX, y, buttonWidth, buttonHeight, cornerRadius)

		-- Draw text
		love.graphics.setColor(colors.ui.background)
		local textX = math.floor(buttonX + (buttonWidth - textWidth) / 2)
		local textY = math.floor(y + (buttonHeight - font:getHeight()) / 2)
		love.graphics.print(text, textX, textY)
	else
		-- Unselected state: background with surface outline
		love.graphics.setColor(colors.ui.background)
		love.graphics.rectangle("fill", buttonX, y, buttonWidth, buttonHeight, cornerRadius)

		-- Draw outline
		love.graphics.setColor(colors.ui.surface)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", buttonX, y, buttonWidth, buttonHeight, cornerRadius)

		-- Draw text
		love.graphics.setColor(colors.ui.foreground)
		local textX = math.floor(buttonX + (buttonWidth - textWidth) / 2)
		local textY = math.floor(y + (buttonHeight - font:getHeight()) / 2)
		love.graphics.print(text, textX, textY)
	end
end

-- Export button constants and height calculation
button.BUTTON = BUTTON
button.calculateHeight = calculateButtonHeight

return button
