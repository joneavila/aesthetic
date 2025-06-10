--- New Header Component
--- A header component using the new component system
local love = require("love")
local colors = require("colors")
local fonts = require("ui.fonts")
local Component = require("ui.component").Component

-- Header constants
local HEADER_CONFIG = {
	VERTICAL_PADDING = 8,
	BOTTOM_MARGIN = 8,
}

-- Header class
local Header = setmetatable({}, { __index = Component })
Header.__index = Header

function Header.title_case(str)
	return str:gsub("(%a)([%w_']*)", function(first, rest)
		return first:upper() .. rest:lower()
	end)
end

function Header:new(config)
	-- Initialize base component
	local instance = Component.new(self, config)

	-- Header-specific properties
	instance.title = config.title or ""
	instance.x = 0
	instance.y = 0
	instance.width = config.screenWidth or love.graphics.getWidth()
	instance.height = instance:calculateHeight()

	return instance
end

function Header.calculateHeight(_self)
	return fonts.loaded.body:getHeight() + (HEADER_CONFIG.VERTICAL_PADDING * 2)
end

function Header:getContentStartY()
	return self.height + HEADER_CONFIG.BOTTOM_MARGIN
end

function Header:setTitle(title)
	self.title = title or ""
end

function Header:draw()
	if not self.visible then
		return
	end
	love.graphics.push("all")
	-- local displayTitle = self.title:upper()
	local displayTitle = Header.title_case(self.title)
	-- Draw background
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	-- Draw header title
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.setFont(fonts.loaded.body)
	local titleWidth = fonts.loaded.body:getWidth(displayTitle)
	local titleX = (self.width - titleWidth) / 2
	love.graphics.print(displayTitle, titleX, HEADER_CONFIG.VERTICAL_PADDING)
	love.graphics.pop()
end

-- Static helper functions for backwards compatibility
local header = {}
header.Header = Header
header.VERTICAL_PADDING = HEADER_CONFIG.VERTICAL_PADDING
header.BOTTOM_MARGIN = HEADER_CONFIG.BOTTOM_MARGIN

-- Backwards compatibility functions
function header.getHeight()
	return fonts.loaded.body:getHeight() + (HEADER_CONFIG.VERTICAL_PADDING * 2)
end

function header.getWidth()
	return love.graphics.getWidth() -- Constant width, full width of screen
end

function header.getContentStartY()
	return header.getHeight() + HEADER_CONFIG.BOTTOM_MARGIN
end

function header.draw(title)
	local displayTitle = Header.title_case(title)

	-- Draw background
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), header.getHeight())

	-- Draw line under header
	love.graphics.setColor(colors.ui.background_outline)
	love.graphics.rectangle("line", 0, header.getHeight(), love.graphics.getWidth(), 1)

	-- Draw header title
	love.graphics.setColor(colors.ui.foreground_dim)
	love.graphics.setFont(fonts.loaded.body)
	local titleWidth = fonts.loaded.body:getWidth(displayTitle)
	local titleX = (header.getWidth() - titleWidth) / 2
	love.graphics.print(displayTitle, titleX, HEADER_CONFIG.VERTICAL_PADDING)
end

return header
