--- ColorSquare component for palette color preview
local love = require("love")
local colors = require("colors")
local Component = require("ui.component").Component
local tween = require("tween")

local FOCUS_SCALE = 1.2
local NORMAL_SCALE = 1.0
local ANIMATION_DURATION = 0.15

local ColorSquare = setmetatable({}, { __index = Component })
ColorSquare.__index = ColorSquare

function ColorSquare:new(config)
	local instance = Component.new(self, config)
	instance.color = config.color or { 1, 1, 1, 1 }
	instance.borderRadius = config.borderRadius or 8
	instance.selected = config.selected or false
	instance.focused = config.focused or false
	instance._scale = NORMAL_SCALE
	instance._scaleTween = nil
	return instance
end

function ColorSquare:setFocused(focused)
	Component.setFocused(self, focused)
	local targetScale = focused and FOCUS_SCALE or NORMAL_SCALE
	if self._scale ~= targetScale then
		self._scaleTween = tween.new(ANIMATION_DURATION, self, { _scale = targetScale }, "outQuad")
	end
end

function ColorSquare:update(dt)
	if self._scaleTween then
		local complete = self._scaleTween:update(dt)
		if complete then
			self._scaleTween = nil
		end
	end
	if Component.update then
		Component.update(self, dt)
	end
end

function ColorSquare:draw()
	if not self.visible then
		return
	end
	love.graphics.push("all")
	local scale = self._scale or 1.0
	local cx = self.x + self.width / 2
	local cy = self.y + self.height / 2
	local drawWidth = self.width * scale
	local drawHeight = self.height * scale
	local drawX = cx - drawWidth / 2
	local drawY = cy - drawHeight / 2
	-- Draw filled square
	love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] or 1)
	love.graphics.rectangle("fill", drawX, drawY, drawWidth, drawHeight, self.borderRadius)

	-- Draw border
	if self.selected or self.focused then
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.setLineWidth(3)
	else
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.setLineWidth(1)
	end
	love.graphics.rectangle("line", drawX, drawY, drawWidth, drawHeight, self.borderRadius)
	love.graphics.pop()
end

return ColorSquare
