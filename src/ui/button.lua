--- Enhanced Button Component
--- Handles button creation, state management, and rendering
local love = require("love")
local colors = require("colors")
local colorUtils = require("utils.color")
local svg = require("utils.svg")
local gradientPreview = require("ui.gradient_preview")

-- Button constants
local BUTTON = {
	VERTICAL_PADDING = 12,
	SPACING = 12,
	EDGE_MARGIN = 16,
	HORIZONTAL_PADDING = 14,
	CORNER_RADIUS = 8,
	SELECTED_OUTLINE_WIDTH = 4,
	PADDING = 16,
}

local CHEVRON = {
	PADDING = 16,
}

local ICON_SIZE = 14
local COLOR_DISPLAY_SIZE = 30
local DEFAULT_BUTTON_HEIGHT = nil

-- Button types enumeration
local BUTTON_TYPES = {
	BASIC = "basic",
	COLOR = "color",
	GRADIENT = "gradient",
	TEXT_PREVIEW = "text_preview",
	INDICATORS = "indicators",
	ACCENTED = "accented",
}

-- Module table
local button = {}

-- ============================================================================
-- BUTTON CREATION AND MANAGEMENT
-- ============================================================================

--- Creates a new button configuration
--- @param config table Button configuration
--- @return table Button object
function button.create(config)
	local btn = {
		-- Basic properties
		text = config.text or "",
		selected = config.selected or false,
		disabled = config.disabled or false,

		-- Position and size
		x = config.x or 0,
		y = config.y or 0,
		width = config.width,
		screenWidth = config.screenWidth,

		-- Button type and behavior
		type = config.type or BUTTON_TYPES.BASIC,
		action = config.action, -- Function to call when pressed

		-- Type-specific properties
		colorKey = config.colorKey,
		previewText = config.previewText,
		valueText = config.valueText,
		hexColor = config.hexColor,
		startColor = config.startColor,
		stopColor = config.stopColor,
		direction = config.direction,
		monoFont = config.monoFont,

		-- Options for cycling values
		options = config.options,
		currentOptionIndex = config.currentOptionIndex or 1,

		-- Metadata
		isBottomButton = config.isBottomButton or false,
		context = config.context, -- Additional context data
	}

	-- Auto-detect button type if not specified
	if btn.type == BUTTON_TYPES.BASIC then
		btn.type = button._detectType(btn)
	end

	return btn
end

--- Auto-detects button type based on properties
--- @param btn table Button object
--- @return string Button type
function button._detectType(btn)
	if btn.startColor and btn.stopColor then
		return BUTTON_TYPES.GRADIENT
	elseif btn.hexColor then
		return BUTTON_TYPES.COLOR
	elseif btn.options then
		return BUTTON_TYPES.INDICATORS
	elseif btn.previewText then
		return BUTTON_TYPES.TEXT_PREVIEW
	else
		return BUTTON_TYPES.BASIC
	end
end

--- Creates a list of buttons from configuration array
--- @param buttonConfigs table Array of button configurations
--- @return table Array of button objects
function button.createList(buttonConfigs)
	local buttons = {}
	for i, config in ipairs(buttonConfigs) do
		buttons[i] = button.create(config)
	end
	return buttons
end

-- ============================================================================
-- BUTTON STATE MANAGEMENT
-- ============================================================================

--- Updates button's current option value
--- @param btn table Button object
--- @param direction number 1 for next, -1 for previous
--- @return boolean True if value changed
function button.cycleOption(btn, direction)
	if not btn.options or #btn.options == 0 then
		return false
	end

	local newIndex = btn.currentOptionIndex + direction
	if newIndex > #btn.options then
		newIndex = 1
	elseif newIndex < 1 then
		newIndex = #btn.options
	end

	if newIndex ~= btn.currentOptionIndex then
		btn.currentOptionIndex = newIndex
		btn.valueText = btn.options[newIndex]
		return true
	end

	return false
end

--- Gets the current option value
--- @param btn table Button object
--- @return string Current option value
function button.getCurrentOption(btn)
	if btn.options and btn.currentOptionIndex then
		return btn.options[btn.currentOptionIndex]
	end
	return btn.valueText
end

--- Updates button selection state
--- @param btn table Button object
--- @param selected boolean Selection state
function button.setSelected(btn, selected)
	btn.selected = selected
end

--- Updates button's preview/value text
--- @param btn table Button object
--- @param text string New text value
function button.setValueText(btn, text)
	btn.valueText = text
	btn.previewText = text
end

-- ============================================================================
-- DRAWING FUNCTIONS
-- ============================================================================

--- Calculate button height based on current font
--- @return number Button height
local function calculateButtonHeight()
	if DEFAULT_BUTTON_HEIGHT then
		return DEFAULT_BUTTON_HEIGHT
	end
	local font = love.graphics.getFont()
	return font:getHeight() + (BUTTON.VERTICAL_PADDING * 2)
end

--- Calculate button dimensions and layout
--- @param btn table Button object
--- @return table Dimension calculations
local function calculateButtonDimensions(btn)
	local buttonWidth = btn.width or btn.screenWidth
	local availableWidth = btn.screenWidth - (BUTTON.EDGE_MARGIN * 2)
	local hasFullWidth = buttonWidth >= availableWidth

	local rightEdge
	if hasFullWidth then
		rightEdge = btn.screenWidth - BUTTON.EDGE_MARGIN
	else
		rightEdge = btn.x + buttonWidth - BUTTON.EDGE_MARGIN
	end

	local drawWidth
	if btn.selected then
		if hasFullWidth then
			drawWidth = availableWidth
		else
			drawWidth = buttonWidth - BUTTON.EDGE_MARGIN
		end
	end

	return {
		drawWidth = drawWidth,
		rightEdge = rightEdge,
		hasFullWidth = hasFullWidth,
		availableWidth = availableWidth,
		buttonHeight = calculateButtonHeight(),
	}
end

--- Draw button background
--- @param btn table Button object
--- @param dimensions table Dimension calculations
local function drawButtonBackground(btn, dimensions)
	if btn.selected then
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle(
			"fill",
			BUTTON.EDGE_MARGIN,
			btn.y,
			dimensions.drawWidth,
			dimensions.buttonHeight,
			BUTTON.CORNER_RADIUS
		)
	end
end

--- Draw button text
--- @param btn table Button object
--- @param dimensions table Dimension calculations
local function drawButtonText(btn, dimensions)
	local font = love.graphics.getFont()
	local textHeight = font:getHeight()
	local opacity = btn.disabled and 0.3 or 1

	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(
		btn.text,
		btn.x + BUTTON.EDGE_MARGIN + BUTTON.HORIZONTAL_PADDING,
		btn.y + (dimensions.buttonHeight - textHeight) / 2
	)
end

--- Draw basic button
--- @param btn table Button object
--- @param dimensions table Dimension calculations
local function drawBasicButton(btn, dimensions)
	drawButtonBackground(btn, dimensions)
	drawButtonText(btn, dimensions)
end

--- Draw button with text preview
--- @param btn table Button object
--- @param dimensions table Dimension calculations
local function drawTextPreviewButton(btn, dimensions)
	drawButtonBackground(btn, dimensions)
	drawButtonText(btn, dimensions)

	if btn.previewText then
		local textWidth = love.graphics.getFont():getWidth(btn.previewText)
		local textY = btn.y + (dimensions.buttonHeight - love.graphics.getFont():getHeight()) / 2
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(btn.previewText, dimensions.rightEdge - textWidth - BUTTON.HORIZONTAL_PADDING, textY)
	end
end

--- Draw button with indicator chevrons
--- @param btn table Button object
--- @param dimensions table Dimension calculations
local function drawIndicatorsButton(btn, dimensions)
	drawButtonBackground(btn, dimensions)
	drawButtonText(btn, dimensions)

	local valueText = button.getCurrentOption(btn)
	if not valueText then
		return
	end

	local textWidth = love.graphics.getFont():getWidth(valueText)
	local totalWidth = textWidth + (ICON_SIZE + CHEVRON.PADDING) * 2
	local rightEdge = dimensions.rightEdge - BUTTON.HORIZONTAL_PADDING
	local valueX = rightEdge - totalWidth
	local iconY = btn.y + dimensions.buttonHeight / 2
	local opacity = btn.disabled and 0.3 or 1

	-- Load chevron icons
	local leftChevron = svg.loadIcon("chevron-left", ICON_SIZE)
	local rightChevron = svg.loadIcon("chevron-right", ICON_SIZE)

	-- Draw value text
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(
		valueText,
		valueX + ICON_SIZE + CHEVRON.PADDING,
		btn.y + (dimensions.buttonHeight - love.graphics.getFont():getHeight()) / 2
	)

	-- Draw chevron icons
	if leftChevron then
		svg.drawIcon(leftChevron, valueX + ICON_SIZE / 2, iconY, colors.ui.foreground, opacity)
	end
	if rightChevron then
		svg.drawIcon(rightChevron, rightEdge - ICON_SIZE / 2, iconY, colors.ui.foreground, opacity)
	end
end

--- Draw button with color preview
--- @param btn table Button object
--- @param dimensions table Dimension calculations
local function drawColorButton(btn, dimensions)
	drawButtonBackground(btn, dimensions)
	drawButtonText(btn, dimensions)

	if not btn.hexColor then
		return
	end

	local colorX = dimensions.rightEdge - COLOR_DISPLAY_SIZE - BUTTON.HORIZONTAL_PADDING
	local colorY = btn.y + (dimensions.buttonHeight - COLOR_DISPLAY_SIZE) / 2
	local opacity = btn.disabled and 0.5 or 1

	-- Draw color square
	local r, g, b = colorUtils.hexToRgb(btn.hexColor)
	love.graphics.setColor(r, g, b, opacity)
	love.graphics.rectangle("fill", colorX, colorY, COLOR_DISPLAY_SIZE, COLOR_DISPLAY_SIZE, BUTTON.CORNER_RADIUS / 2)

	-- Draw border
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", colorX, colorY, COLOR_DISPLAY_SIZE, COLOR_DISPLAY_SIZE, BUTTON.CORNER_RADIUS / 2)

	-- Draw hex code
	local originalFont = love.graphics.getFont()
	if btn.monoFont then
		love.graphics.setFont(btn.monoFont)
	end

	local hexWidth = love.graphics.getFont():getWidth(btn.hexColor)
	love.graphics.print(
		btn.hexColor,
		colorX - hexWidth - 10,
		btn.y + (dimensions.buttonHeight - love.graphics.getFont():getHeight()) / 2
	)

	love.graphics.setFont(originalFont)
end

--- Draw button with gradient preview
--- @param btn table Button object
--- @param dimensions table Dimension calculations
local function drawGradientButton(btn, dimensions)
	drawButtonBackground(btn, dimensions)
	drawButtonText(btn, dimensions)

	if not (btn.startColor and btn.stopColor) then
		return
	end

	local colorX = dimensions.rightEdge - COLOR_DISPLAY_SIZE - BUTTON.HORIZONTAL_PADDING
	local colorY = btn.y + (dimensions.buttonHeight - COLOR_DISPLAY_SIZE) / 2
	local opacity = btn.disabled and 0.5 or 1

	-- Draw gradient square
	local cornerRadius = BUTTON.CORNER_RADIUS / 2
	gradientPreview.drawSquare(
		colorX,
		colorY,
		COLOR_DISPLAY_SIZE,
		btn.startColor,
		btn.stopColor,
		btn.direction,
		cornerRadius
	)

	-- Draw gradient text
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)

	local originalFont = love.graphics.getFont()
	if btn.monoFont then
		love.graphics.setFont(btn.monoFont)
	end

	local gradientText = btn.startColor .. " → " .. btn.stopColor
	local textWidth = love.graphics.getFont():getWidth(gradientText)
	love.graphics.print(
		gradientText,
		colorX - textWidth - 10,
		btn.y + (dimensions.buttonHeight - love.graphics.getFont():getHeight()) / 2
	)

	love.graphics.setFont(originalFont)
end

--- Draw accented button (centered, special styling)
--- @param btn table Button object
local function drawAccentedButton(btn)
	local font = love.graphics.getFont()
	local textWidth = font:getWidth(btn.text)
	local buttonWidth = btn.width or (textWidth + 360)
	local buttonX = (btn.screenWidth - buttonWidth) / 2
	local buttonHeight = calculateButtonHeight()

	if btn.selected then
		-- Selected: accent background, background text
		love.graphics.setColor(colors.ui.accent)
		love.graphics.rectangle("fill", buttonX, btn.y, buttonWidth, buttonHeight, BUTTON.CORNER_RADIUS)

		love.graphics.setColor(colors.ui.background)
		local textX = math.floor(buttonX + (buttonWidth - textWidth) / 2)
		local textY = math.floor(btn.y + (buttonHeight - font:getHeight()) / 2)
		love.graphics.print(btn.text, textX, textY)
	else
		-- Unselected: background with surface outline
		love.graphics.setColor(colors.ui.background)
		love.graphics.rectangle("fill", buttonX, btn.y, buttonWidth, buttonHeight, BUTTON.CORNER_RADIUS)

		love.graphics.setColor(colors.ui.surface)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", buttonX, btn.y, buttonWidth, buttonHeight, BUTTON.CORNER_RADIUS)

		love.graphics.setColor(colors.ui.foreground)
		local textX = math.floor(buttonX + (buttonWidth - textWidth) / 2)
		local textY = math.floor(btn.y + (buttonHeight - font:getHeight()) / 2)
		love.graphics.print(btn.text, textX, textY)
	end
end

-- Drawing dispatch table
local drawingFunctions = {
	[BUTTON_TYPES.BASIC] = drawBasicButton,
	[BUTTON_TYPES.TEXT_PREVIEW] = drawTextPreviewButton,
	[BUTTON_TYPES.INDICATORS] = drawIndicatorsButton,
	[BUTTON_TYPES.COLOR] = drawColorButton,
	[BUTTON_TYPES.GRADIENT] = drawGradientButton,
	[BUTTON_TYPES.ACCENTED] = drawAccentedButton,
}

--- Main drawing function - draws a button based on its type
--- @param btn table Button object
function button.draw(btn)
	-- Update position if drawing within a list context
	if btn.listY then
		btn.y = btn.listY
	end

	local drawFunc = drawingFunctions[btn.type]
	if not drawFunc then
		drawFunc = drawingFunctions[BUTTON_TYPES.BASIC]
	end

	if btn.type == BUTTON_TYPES.ACCENTED then
		drawFunc(btn)
	else
		local dimensions = calculateButtonDimensions(btn)
		drawFunc(btn, dimensions)
	end
end

--- Draw multiple buttons
--- @param buttons table Array of button objects
function button.drawList(buttons)
	for _, btn in ipairs(buttons) do
		button.draw(btn)
	end
end

-- ============================================================================
-- PUBLIC API AND COMPATIBILITY
-- ============================================================================

--- Set a fixed button height to be used across the application
--- @param height number Button height
function button.setDefaultHeight(height)
	if type(height) == "number" and height > 0 then
		DEFAULT_BUTTON_HEIGHT = height
	end
end

--- Reset to automatic height calculation
function button.resetDefaultHeight()
	DEFAULT_BUTTON_HEIGHT = nil
end

--- Get the current button height
--- @return number Button height
function button.getHeight()
	return calculateButtonHeight()
end

--- Preload required icons
function button.load()
	svg.preloadIcons({ "chevron-left", "chevron-right" }, ICON_SIZE)
end

-- ============================================================================
-- BACKWARD COMPATIBILITY FUNCTIONS
-- ============================================================================

-- Keep existing function signatures for backward compatibility
function button.drawWithTextPreview(text, x, y, isSelected, screenWidth, previewText, buttonWidth)
	local btn = button.create({
		text = text,
		x = x,
		y = y,
		selected = isSelected,
		screenWidth = screenWidth,
		width = buttonWidth,
		type = BUTTON_TYPES.TEXT_PREVIEW,
		previewText = previewText,
	})
	button.draw(btn)
end

function button.drawWithIndicators(text, x, y, isSelected, isDisabled, screenWidth, valueText, buttonWidth)
	local btn = button.create({
		text = text,
		x = x,
		y = y,
		selected = isSelected,
		disabled = isDisabled,
		screenWidth = screenWidth,
		width = buttonWidth,
		type = BUTTON_TYPES.INDICATORS,
		valueText = valueText,
	})
	button.draw(btn)
end

function button.drawWithColorPreview(text, isSelected, x, y, screenWidth, hexColor, isDisabled, monoFont, buttonWidth)
	local btn = button.create({
		text = text,
		x = x,
		y = y,
		selected = isSelected,
		disabled = isDisabled,
		screenWidth = screenWidth,
		width = buttonWidth,
		type = BUTTON_TYPES.COLOR,
		hexColor = hexColor,
		monoFont = monoFont,
	})
	button.draw(btn)
end

function button.drawWithGradientPreview(
	text,
	isSelected,
	x,
	y,
	screenWidth,
	startColor,
	stopColor,
	direction,
	isDisabled,
	monoFont,
	buttonWidth
)
	local btn = button.create({
		text = text,
		x = x,
		y = y,
		selected = isSelected,
		disabled = isDisabled,
		screenWidth = screenWidth,
		width = buttonWidth,
		type = BUTTON_TYPES.GRADIENT,
		startColor = startColor,
		stopColor = stopColor,
		direction = direction,
		monoFont = monoFont,
	})
	button.draw(btn)
end

function button.drawAccented(text, isSelected, y, screenWidth, buttonWidth)
	local btn = button.create({
		text = text,
		y = y,
		selected = isSelected,
		screenWidth = screenWidth,
		width = buttonWidth,
		type = BUTTON_TYPES.ACCENTED,
	})
	button.draw(btn)
end

-- Export constants and types
button.BUTTON = BUTTON
button.TYPES = BUTTON_TYPES
button.calculateHeight = calculateButtonHeight

return button
