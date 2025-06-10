--- Button component
--- A reusable button component with multiple types and styles
local love = require("love")
local colors = require("colors")
local colorUtils = require("utils.color")
local svg = require("utils.svg")
local gradientPreview = require("ui.gradient_preview")
local Component = require("ui.component").Component

-- Button constants
local BUTTON_CONFIG = {
	VERTICAL_PADDING = 12,
	HORIZONTAL_PADDING = 14,
	EDGE_MARGIN = 16,
	CORNER_RADIUS = 8,
	SPACING = 12,
}

local ICON_SIZE = 14
local COLOR_DISPLAY_SIZE = 30
local CHEVRON_PADDING = 16

-- Button types
local BUTTON_TYPES = {
	BASIC = "basic",
	COLOR = "color",
	GRADIENT = "gradient",
	TEXT_PREVIEW = "text_preview",
	INDICATORS = "indicators",
	ACCENTED = "accented",
	DUAL_COLOR = "dual_color",
}

-- Button class
local Button = setmetatable({}, { __index = Component })
Button.__index = Button

function Button:new(config)
	-- Initialize base component
	local instance = Component.new(self, config)

	-- Button-specific properties
	instance.text = config.text or ""
	instance.type = config.type or BUTTON_TYPES.BASIC
	instance.disabled = config.disabled or false

	-- Visual properties
	instance.hexColor = config.hexColor
	instance.startColor = config.startColor
	instance.stopColor = config.stopColor
	instance.direction = config.direction or "Vertical"
	instance.previewText = config.previewText
	instance.monoFont = config.monoFont
	instance.iconName = config.iconName
	instance.iconSize = config.iconSize or ICON_SIZE

	-- Options for cycling
	instance.options = config.options
	instance.currentOptionIndex = config.currentOptionIndex or 1

	-- Context for state management
	instance.context = config.context

	-- Layout
	instance.screenWidth = config.screenWidth or love.graphics.getWidth()
	instance.fullWidth = config.fullWidth ~= false

	-- Custom size support
	instance.height = config.height -- may be nil
	instance.width = config.width -- may be nil

	-- Calculate dimensions (will use custom height/width if set)
	instance:calculateDimensions()

	return instance
end

function Button:calculateDimensions()
	local font = love.graphics.getFont()
	if not self.height then
		self.height = font:getHeight() + (BUTTON_CONFIG.VERTICAL_PADDING * 2)
	end
	if self.fullWidth then
		self.width = self.screenWidth - (BUTTON_CONFIG.EDGE_MARGIN * 2)
	end
	if self.width then
		self.x = BUTTON_CONFIG.EDGE_MARGIN
	end
end

function Button:setFocused(focused)
	Component.setFocused(self, focused)
end

function Button:getText()
	return self.text
end

function Button:setText(text)
	self.text = text or ""
end

function Button:getPreviewText()
	return self.previewText
end

function Button:setPreviewText(text)
	self.previewText = text
end

function Button:getCurrentOption()
	if self.options and self.currentOptionIndex then
		return self.options[self.currentOptionIndex]
	end
	return nil
end

function Button:cycleOption(direction)
	if not self.options or #self.options == 0 then
		return false
	end

	local newIndex = self.currentOptionIndex + direction
	if newIndex > #self.options then
		newIndex = 1
	elseif newIndex < 1 then
		newIndex = #self.options
	end

	if newIndex ~= self.currentOptionIndex then
		self.currentOptionIndex = newIndex
		return true
	end

	return false
end

function Button:handleInput(input)
	if not self.enabled or self.disabled then
		return false
	end

	local handled = false

	-- Handle option cycling for indicator buttons
	if self.type == BUTTON_TYPES.INDICATORS and self.focused then
		if input.isPressed("dpleft") then
			handled = self:cycleOption(-1)
		elseif input.isPressed("dpright") then
			handled = self:cycleOption(1)
		end
	end

	-- Handle selection
	if input.isPressed("a") and self.focused then
		if self.onClick then
			self.onClick(self)
		end
		handled = true
	end

	return handled
end

function Button:drawBackground()
	Component.drawBackground(self)
end

function Button:drawText()
	local font = love.graphics.getFont()
	local textHeight = font:getHeight()
	local opacity = self.disabled and 0.3 or 1

	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(self.text, self.x + BUTTON_CONFIG.HORIZONTAL_PADDING, self.y + (self.height - textHeight) / 2)
end

function Button:drawBasic()
	self:drawBackground()
	self:drawText()
end

function Button:drawTextPreview()
	self:drawBackground()
	self:drawText()

	if self.previewText then
		local font = love.graphics.getFont()
		local textWidth = font:getWidth(self.previewText)
		local textY = self.y + (self.height - font:getHeight()) / 2
		local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING

		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(self.previewText, rightEdge - textWidth, textY)
	end
end

function Button:drawIndicators()
	self:drawBackground()
	self:drawText()

	local valueText = self:getCurrentOption()
	if not valueText then
		return
	end

	local font = love.graphics.getFont()
	local textWidth = font:getWidth(valueText)
	local totalWidth = textWidth + (ICON_SIZE + CHEVRON_PADDING) * 2
	local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING
	local valueX = rightEdge - totalWidth
	local iconY = self.y + self.height / 2
	local opacity = self.disabled and 0.3 or 1

	-- Load chevron icons
	local leftChevron = svg.loadIcon("chevron-left", ICON_SIZE)
	local rightChevron = svg.loadIcon("chevron-right", ICON_SIZE)

	-- Draw value text
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(valueText, valueX + ICON_SIZE + CHEVRON_PADDING, self.y + (self.height - font:getHeight()) / 2)

	-- Draw chevron icons
	if leftChevron then
		svg.drawIcon(leftChevron, valueX + ICON_SIZE / 2, iconY, colors.ui.foreground, opacity)
	end
	if rightChevron then
		svg.drawIcon(rightChevron, rightEdge - ICON_SIZE / 2, iconY, colors.ui.foreground, opacity)
	end
end

function Button:drawColor()
	self:drawBackground()
	self:drawText()

	if not self.hexColor then
		return
	end

	local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING
	local colorX = rightEdge - COLOR_DISPLAY_SIZE
	local colorY = self.y + (self.height - COLOR_DISPLAY_SIZE) / 2
	local opacity = self.disabled and 0.5 or 1

	-- Draw color square
	local r, g, b = colorUtils.hexToRgb(self.hexColor)
	love.graphics.setColor(r, g, b, opacity)
	love.graphics.rectangle(
		"fill",
		colorX,
		colorY,
		COLOR_DISPLAY_SIZE,
		COLOR_DISPLAY_SIZE,
		BUTTON_CONFIG.CORNER_RADIUS / 2
	)

	-- Draw border
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle(
		"line",
		colorX,
		colorY,
		COLOR_DISPLAY_SIZE,
		COLOR_DISPLAY_SIZE,
		BUTTON_CONFIG.CORNER_RADIUS / 2
	)

	-- Draw hex code
	local originalFont = love.graphics.getFont()
	if self.monoFont then
		love.graphics.setFont(self.monoFont)
	end

	local hexWidth = love.graphics.getFont():getWidth(self.hexColor)
	love.graphics.print(
		self.hexColor,
		colorX - hexWidth - 10,
		self.y + (self.height - love.graphics.getFont():getHeight()) / 2
	)

	love.graphics.setFont(originalFont)
end

function Button:drawGradient()
	self:drawBackground()
	self:drawText()

	if not (self.startColor and self.stopColor) then
		return
	end

	local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING
	local colorX = rightEdge - COLOR_DISPLAY_SIZE
	local colorY = self.y + (self.height - COLOR_DISPLAY_SIZE) / 2
	local opacity = self.disabled and 0.5 or 1

	-- Draw gradient square
	local cornerRadius = BUTTON_CONFIG.CORNER_RADIUS / 2
	gradientPreview.drawSquare(
		colorX,
		colorY,
		COLOR_DISPLAY_SIZE,
		self.startColor,
		self.stopColor,
		self.direction,
		cornerRadius
	)

	-- Draw gradient text
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)

	local originalFont = love.graphics.getFont()
	if self.monoFont then
		love.graphics.setFont(self.monoFont)
	end

	local gradientText = self.startColor .. " → " .. self.stopColor
	local textWidth = love.graphics.getFont():getWidth(gradientText)
	love.graphics.print(
		gradientText,
		colorX - textWidth - 10,
		self.y + (self.height - love.graphics.getFont():getHeight()) / 2
	)

	love.graphics.setFont(originalFont)
end

function Button:drawAccented()
	local font = love.graphics.getFont()
	local textWidth = font:getWidth(self.text)
	local buttonWidth = textWidth + 360
	local buttonX = (self.screenWidth - buttonWidth) / 2

	if self.focused then
		love.graphics.setColor(colors.ui.accent)
		love.graphics.rectangle("fill", buttonX, self.y, buttonWidth, self.height, BUTTON_CONFIG.CORNER_RADIUS)

		love.graphics.setColor(colors.ui.foreground)
		local textX = math.floor(buttonX + (buttonWidth - textWidth) / 2)
		local textY = math.floor(self.y + (self.height - font:getHeight()) / 2)
		love.graphics.print(self.text, textX, textY)
	else
		love.graphics.setColor(colors.ui.surface_bright)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", buttonX, self.y, buttonWidth, self.height, BUTTON_CONFIG.CORNER_RADIUS)

		love.graphics.setColor(colors.ui.foreground)
		local textX = math.floor(buttonX + (buttonWidth - textWidth) / 2)
		local textY = math.floor(self.y + (self.height - font:getHeight()) / 2)
		love.graphics.print(self.text, textX, textY)
	end
end

function Button:drawDualColor()
	self:drawBackground()
	self:drawText()

	if not (self.color1Hex and self.color2Hex) then
		return
	end

	local font = love.graphics.getFont()
	local originalFont = font
	if self.monoFont then
		love.graphics.setFont(self.monoFont)
		font = self.monoFont
	end

	local colorBoxWidth = COLOR_DISPLAY_SIZE
	local colorBoxHeight = COLOR_DISPLAY_SIZE
	local colorBoxSpacing = 10
	local hexSpacing = 10

	local hex1 = self.color1Hex
	local hex2 = self.color2Hex
	local hex1Width = font:getWidth(hex1)
	local hex2Width = font:getWidth(hex2)
	local previewY = self.y + (self.height - colorBoxHeight) / 2
	local hexY = self.y + (self.height - font:getHeight()) / 2
	local opacity = self.disabled and 0.5 or 1

	-- Calculate total width for right alignment
	local totalWidth = hex1Width + colorBoxWidth + hexSpacing + hex2Width + colorBoxWidth + colorBoxSpacing * 2
	local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING
	local x = rightEdge - totalWidth

	-- Draw hex1
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(hex1, x, hexY)
	x = x + hex1Width + hexSpacing

	-- Draw color1 preview
	local r1, g1, b1 = colorUtils.hexToRgb(self.color1Hex)
	love.graphics.setColor(r1, g1, b1, opacity)
	love.graphics.rectangle("fill", x, previewY, colorBoxWidth, colorBoxHeight, BUTTON_CONFIG.CORNER_RADIUS / 2)
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", x, previewY, colorBoxWidth, colorBoxHeight, BUTTON_CONFIG.CORNER_RADIUS / 2)
	x = x + colorBoxWidth + colorBoxSpacing

	-- Draw hex2
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(hex2, x, hexY)
	x = x + hex2Width + hexSpacing

	-- Draw color2 preview
	local r2, g2, b2 = colorUtils.hexToRgb(self.color2Hex)
	love.graphics.setColor(r2, g2, b2, opacity)
	love.graphics.rectangle("fill", x, previewY, colorBoxWidth, colorBoxHeight, BUTTON_CONFIG.CORNER_RADIUS / 2)
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", x, previewY, colorBoxWidth, colorBoxHeight, BUTTON_CONFIG.CORNER_RADIUS / 2)

	love.graphics.setFont(originalFont)
end

function Button:draw()
	if not self.visible then
		return
	end
	love.graphics.push("all")
	if self.type == BUTTON_TYPES.BASIC then
		self:drawBasic()
	elseif self.type == BUTTON_TYPES.TEXT_PREVIEW then
		self:drawTextPreview()
	elseif self.type == BUTTON_TYPES.INDICATORS then
		self:drawIndicators()
	elseif self.type == BUTTON_TYPES.COLOR then
		self:drawColor()
	elseif self.type == BUTTON_TYPES.GRADIENT then
		self:drawGradient()
	elseif self.type == BUTTON_TYPES.ACCENTED then
		self:drawAccented()
	elseif self.type == BUTTON_TYPES.DUAL_COLOR then
		self:drawDualColor()
	else
		self:drawBasic()
	end
	love.graphics.pop()
end

-- Initialize icons
local function init()
	svg.preloadIcons({ "chevron-left", "chevron-right" }, ICON_SIZE)
	-- Preload settings screen icons at larger size
	svg.preloadIcons({ "save", "file-up", "refresh-cw", "palette", "info" }, 21)
end

-- Module exports
local button = {}
button.Button = Button
button.TYPES = BUTTON_TYPES
button.init = init

return button
