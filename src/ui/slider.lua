--- Slider UI component (Component-based)
local love = require("love")
local colors = require("colors")
local tween = require("tween")
local component = require("ui.component")

local Slider = setmetatable({}, { __index = component.Component })
Slider.__index = Slider

Slider.HEIGHT = 30
Slider.PADDING = 18
Slider.TRACK_HEIGHT = 8
Slider.HANDLE_WIDTH = 14
Slider.HANDLE_HEIGHT = 32
Slider.CORNER_RADIUS = 8
Slider.TICK_HEIGHT = 10
Slider.TICK_WIDTH = 2
Slider.LABEL_OFFSET_Y = 38

-- Focus background constants
Slider.FOCUS_BACKGROUND_TOP_MARGIN = 6
Slider.FOCUS_BACKGROUND_BOTTOM_MARGIN = 12

-- Label positioning constants
Slider.LABEL_LEFT_PADDING = 12

-- Handle shadow constants
Slider.HANDLE_SHADOW_OFFSET_X = 1
Slider.HANDLE_SHADOW_OFFSET_Y = 1

-- Tick positioning constants
Slider.TICK_VERTICAL_OFFSET = 2

-- Component padding constants
Slider.BOTTOM_PADDING = 10

Slider.TWEEN_DURATION = 0.25 -- Duration in seconds for slider animation
Slider.TWEEN_EASING = "outQuad" -- Easing function for slider animation

function Slider.new(_, config)
	local instance = setmetatable(component.Component:new(config), Slider)
	instance.x = config.x or 0
	instance.y = config.y or 0
	instance.width = config.width or 200
	instance.values = config.values or { 0, 100 }
	instance.valueIndex = config.valueIndex or 1
	instance.label = config.label
	instance.onValueChanged = config.onValueChanged
	instance.valueFormatter = config.valueFormatter -- Custom formatter function
	instance.animatedValue = instance.valueIndex
	instance.currentTween = nil
	return instance
end

function Slider:setValueIndex(idx, animate)
	idx = math.max(1, math.min(#self.values, idx))
	if animate then
		if math.abs(self.animatedValue - idx) > 0.01 then
			self.currentTween = tween.new(Slider.TWEEN_DURATION, self, { animatedValue = idx }, Slider.TWEEN_EASING)
		end
	else
		self.animatedValue = idx
		self.currentTween = nil
	end
	self.valueIndex = idx
	if self.onValueChanged then
		self.onValueChanged(self.values[self.valueIndex], self.valueIndex)
	end
end

function Slider:update(dt)
	if self.currentTween then
		local completed = self.currentTween:update(dt)
		if completed then
			self.currentTween = nil
		end
	end
end

function Slider.getTotalHeight()
	local baseHeight = Slider.LABEL_OFFSET_Y + Slider.HEIGHT + Slider.BOTTOM_PADDING
	return baseHeight + Slider.FOCUS_BACKGROUND_BOTTOM_MARGIN
end

function Slider:draw()
	if not self.values or #self.values == 0 then
		return
	end

	-- Draw focused background if focused
	if self.focused then
		local backgroundPadding = 0
		local backgroundY = self.y - Slider.FOCUS_BACKGROUND_TOP_MARGIN
		local backgroundHeight = Slider.getTotalHeight() + Slider.FOCUS_BACKGROUND_TOP_MARGIN
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle(
			"fill",
			self.x - backgroundPadding,
			backgroundY,
			self.width + (backgroundPadding * 2),
			backgroundHeight,
			Slider.CORNER_RADIUS
		)
	end
	local clampedCurrentIndex = math.max(1, math.min(self.valueIndex, #self.values))
	local trackX = self.x + Slider.PADDING
	local trackY = self.y + Slider.LABEL_OFFSET_Y + (Slider.HEIGHT / 2) - (Slider.TRACK_HEIGHT / 2)
	local trackWidth = self.width - (Slider.PADDING * 2)

	-- Draw track background - use overlay color when focused for better contrast
	local trackBackgroundColor = self.focused and colors.ui.overlay or colors.ui.surface
	love.graphics.setColor(trackBackgroundColor)
	love.graphics.rectangle("fill", trackX, trackY, trackWidth, Slider.TRACK_HEIGHT, Slider.TRACK_HEIGHT / 2)
	love.graphics.setColor(colors.ui.overlay)
	for i = 1, #self.values do
		local tickX = trackX + ((i - 1) / (#self.values - 1)) * trackWidth - (Slider.TICK_WIDTH / 2)
		local tickY = trackY + Slider.TRACK_HEIGHT + Slider.TICK_VERTICAL_OFFSET
		love.graphics.rectangle("fill", tickX, tickY, Slider.TICK_WIDTH, Slider.TICK_HEIGHT, 1)
	end
	local rawPercent = (self.animatedValue - 1) / math.max(1, #self.values - 1)
	local percent = math.max(0, math.min(1, rawPercent))
	local fillWidth = trackWidth * percent
	love.graphics.setColor(colors.ui.accent)
	love.graphics.rectangle("fill", trackX, trackY, fillWidth, Slider.TRACK_HEIGHT, Slider.TRACK_HEIGHT / 2)
	local handlePercent = (self.animatedValue - 1) / math.max(1, #self.values - 1)
	local clampedHandlePercent = math.max(0, math.min(1, handlePercent))
	local handleX = trackX + trackWidth * clampedHandlePercent - (Slider.HANDLE_WIDTH / 2)
	local handleY = self.y + Slider.LABEL_OFFSET_Y + (Slider.HEIGHT / 2) - (Slider.HANDLE_HEIGHT / 2)
	love.graphics.setColor(0, 0, 0, 0.3)
	love.graphics.rectangle(
		"fill",
		handleX + Slider.HANDLE_SHADOW_OFFSET_X,
		handleY + Slider.HANDLE_SHADOW_OFFSET_Y,
		Slider.HANDLE_WIDTH,
		Slider.HANDLE_HEIGHT,
		Slider.CORNER_RADIUS
	)
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.rectangle("fill", handleX, handleY, Slider.HANDLE_WIDTH, Slider.HANDLE_HEIGHT, Slider.CORNER_RADIUS)
	if self.label then
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(self.label, self.x + Slider.LABEL_LEFT_PADDING, self.y)
	end
	local currentValue = self.values[clampedCurrentIndex]
	-- Use custom formatter if provided, otherwise fall back to tostring
	local valueText = self.valueFormatter and self.valueFormatter(currentValue) or tostring(currentValue)
	local font = love.graphics.getFont()
	local textWidth = font:getWidth(valueText)
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.print(valueText, self.x + self.width - Slider.PADDING - textWidth, self.y)
end

function Slider:handleInput(input)
	if input.isPressed then
		if input.isPressed("dpleft") then
			self:setValueIndex(self.valueIndex - 1, true)
			return true
		elseif input.isPressed("dpright") then
			self:setValueIndex(self.valueIndex + 1, true)
			return true
		end
	end
	return false
end

function Slider:handleInputIfFocused(input)
	if self.focused then
		return self:handleInput(input)
	end
	return false
end

return {
	Slider = Slider,
}
