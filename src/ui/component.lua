--- Base UI Component
--- Provides common functionality for all UI components

local component = {}

-- Component base class
local Component = {}
Component.__index = Component

function Component:new(config)
	local instance = setmetatable({}, self)

	-- Core properties
	instance.id = config.id or tostring(instance)
	instance.x = config.x or 0
	instance.y = config.y or 0
	instance.width = config.width or 0
	instance.height = config.height or 0
	instance.visible = config.visible ~= false
	instance.enabled = config.enabled ~= false

	-- State
	instance.focused = false
	instance.pressed = false
	instance.hovered = false

	-- Callbacks
	instance.onFocus = config.onFocus
	instance.onBlur = config.onBlur
	instance.onClick = config.onClick
	instance.onUpdate = config.onUpdate

	return instance
end

function Component:setPosition(x, y)
	self.x = x or self.x
	self.y = y or self.y
end

function Component:setSize(width, height)
	self.width = width or self.width
	self.height = height or self.height
end

function Component:setFocused(focused)
	if self.focused ~= focused then
		self.focused = focused
		if focused and self.onFocus then
			self.onFocus(self)
		elseif not focused and self.onBlur then
			self.onBlur(self)
		end
	end
end

function Component:isPointInside(x, y)
	return x >= self.x and x < self.x + self.width and y >= self.y and y < self.y + self.height
end

function Component:update(dt)
	if self.onUpdate then
		self.onUpdate(self, dt)
	end
end

function Component.draw(_self)
	-- Override in subclasses
end

function Component.handleInput(_self, _input)
	-- Override in subclasses
	return false
end

-- Export the base component
component.Component = Component

return component
