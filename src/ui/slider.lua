--- Slider UI component (Component-based)
local love = require("love")
local colors = require("colors")
local tween = require("tween")
local component = require("ui.component")

local Slider = setmetatable({}, { __index = component.Component })
Slider.__index = Slider

Slider.HEIGHT = 30
Slider.PADDING = 20
Slider.TRACK_HEIGHT = 8
Slider.HANDLE_WIDTH = 16
Slider.HANDLE_HEIGHT = 36
Slider.CORNER_RADIUS = 8
Slider.TICK_HEIGHT = 10
Slider.TICK_WIDTH = 2
Slider.LABEL_OFFSET_Y = 30

function Slider:new(config)
	local self = setmetatable(component.Component:new(config), Slider)
	self.x = config.x or 0
	self.y = config.y or 0
	self.width = config.width or 200
	self.values = config.values or { 0, 100 }
	self.valueIndex = config.valueIndex or 1
	self.label = config.label
	self.onValueChanged = config.onValueChanged
	self.animatedValue = self.valueIndex
	self.currentTween = nil
	return self
end

function Slider:setValueIndex(idx, animate)
	idx = math.max(1, math.min(#self.values, idx))
	if animate then
		if math.abs(self.animatedValue - idx) > 0.01 then
			self.currentTween = tween.new(0.25, self, { animatedValue = idx }, "inOutQuad")
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

function Slider:draw()
	if not self.values or #self.values == 0 then
		return
	end
	local clampedAnimatedIndex = math.max(1, math.min(self.animatedValue, #self.values))
	local clampedCurrentIndex = math.max(1, math.min(self.valueIndex, #self.values))
	local trackX = self.x + Slider.PADDING
	local trackY = self.y + (Slider.HEIGHT / 2) - (Slider.TRACK_HEIGHT / 2)
	local trackWidth = self.width - (Slider.PADDING * 2)
	love.graphics.setColor(colors.ui.surface)
	love.graphics.rectangle("fill", trackX, trackY, trackWidth, Slider.TRACK_HEIGHT, Slider.TRACK_HEIGHT / 2)
	love.graphics.setColor(colors.ui.overlay)
	for i = 1, #self.values do
		local tickX = trackX + ((i - 1) / (#self.values - 1)) * trackWidth - (Slider.TICK_WIDTH / 2)
		local tickY = trackY + Slider.TRACK_HEIGHT + 2
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
	local handleY = self.y + (Slider.HEIGHT / 2) - (Slider.HANDLE_HEIGHT / 2)
	love.graphics.setColor(0, 0, 0, 0.3)
	love.graphics.rectangle(
		"fill",
		handleX + 1,
		handleY + 1,
		Slider.HANDLE_WIDTH,
		Slider.HANDLE_HEIGHT,
		Slider.CORNER_RADIUS
	)
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.rectangle("fill", handleX, handleY, Slider.HANDLE_WIDTH, Slider.HANDLE_HEIGHT, Slider.CORNER_RADIUS)
	if self.label then
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(self.label, self.x + Slider.PADDING, self.y - Slider.LABEL_OFFSET_Y)
	end
	local currentValue = self.values[clampedCurrentIndex]
	local valueText = tostring(currentValue)
	local font = love.graphics.getFont()
	local textWidth = font:getWidth(valueText)
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.print(valueText, self.x + self.width - Slider.PADDING - textWidth, self.y - Slider.LABEL_OFFSET_Y)
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

return {
	Slider = Slider,
}
