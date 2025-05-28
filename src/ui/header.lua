--- New Header Component
--- A header component using the new component system
local love = require("love")
local colors = require("colors")
local fonts = require("ui.fonts")
local Component = require("ui.component").Component

-- Header constants
local HEADER_CONFIG = {
	HORIZONTAL_PADDING = 18,
	VERTICAL_PADDING = 10,
	BOTTOM_MARGIN = 14,
}

-- Header class
local Header = setmetatable({}, { __index = Component })
Header.__index = Header

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

function Header:calculateHeight()
	return fonts.loaded.header:getHeight() + (HEADER_CONFIG.VERTICAL_PADDING * 2)
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

	local displayTitle = self.title:upper()

	-- Draw background
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

	-- Draw header title
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.setFont(fonts.loaded.header)
	love.graphics.print(displayTitle, HEADER_CONFIG.HORIZONTAL_PADDING, HEADER_CONFIG.VERTICAL_PADDING)
end

-- Static helper functions for backwards compatibility
local header = {}
header.Header = Header
header.HORIZONTAL_PADDING = HEADER_CONFIG.HORIZONTAL_PADDING
header.VERTICAL_PADDING = HEADER_CONFIG.VERTICAL_PADDING
header.BOTTOM_MARGIN = HEADER_CONFIG.BOTTOM_MARGIN

-- Backwards compatibility functions
function header.getHeight()
	return fonts.loaded.header:getHeight() + (HEADER_CONFIG.VERTICAL_PADDING * 2)
end

function header.getContentStartY()
	return header.getHeight() + HEADER_CONFIG.BOTTOM_MARGIN
end

function header.draw(title)
	title = title:upper()

	-- Draw background
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), header.getHeight())

	-- Draw header title
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.setFont(fonts.loaded.header)
	love.graphics.print(title, HEADER_CONFIG.HORIZONTAL_PADDING, HEADER_CONFIG.VERTICAL_PADDING)
end

return header
