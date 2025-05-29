--- ListSelect UI component (Component-based)
-- This module provides a scrollable list with checkboxes and action buttons
local love = require("love")

local colors = require("colors")
local controls = require("controls")

local component = require("ui.component")
local List = require("ui.list").List

local svg = require("utils.svg")

local ListSelect = setmetatable({}, { __index = component.Component })
ListSelect.__index = ListSelect

-- Preload icons
local SQUARE = svg.loadIcon("square", 24)
local SQUARE_CHECK_ICON = svg.loadIcon("square-check", 24)

function ListSelect:new(config)
	local self = setmetatable(component.Component:new(config), ListSelect)
	self.items = config.items or {}
	self.actions = config.actions or {}
	self.x = config.x or 0
	self.y = config.y or 0
	self.width = config.width or love.graphics.getWidth()
	self.height = config.height or love.graphics.getHeight()
	self.itemHeight = config.itemHeight or 60
	self.selectedCount = 0
	self.onItemChecked = config.onItemChecked
	self.onActionSelected = config.onActionSelected
	self.onItemSelect = config.onItemSelect
	self.onItemFocus = config.onItemFocus
	self.wrap = config.wrap or false
	self.paddingX = config.paddingX or 16
	self.paddingY = config.paddingY or 8
	self.list = List:new({
		x = self.x,
		y = self.y,
		width = self.width,
		height = self.height,
		items = self.items,
		onItemSelect = function(item, idx)
			if self.onItemSelect then
				self.onItemSelect(item, idx)
			end
			if item and item._isAction then
				if self.onActionSelected then
					self.onActionSelected(item, idx)
				end
			else
				item.checked = not item.checked
				if self.onItemChecked then
					self.onItemChecked(item, idx)
				end
			end
		end,
		onItemFocus = self.onItemFocus,
		wrap = self.wrap,
	})
	return self
end

function ListSelect:setItems(items)
	self.items = items or {}
	self.list:setItems(self.items)
end

function ListSelect:draw()
	local font = love.graphics.getFont()
	local controlsHeight = controls.HEIGHT or 42
	local indicatorHeight = font:getHeight() + 24
	local y = self.y
	local screenWidth = self.width
	local buttonWidth = screenWidth - 2 * self.paddingX
	-- Draw actions at the top
	local listStartY = y
	if #self.actions > 0 then
		for i, action in ipairs(self.actions) do
			local ay = y + (i - 1) * (self.itemHeight + self.paddingY)
			self:drawActionButton(action, ay, screenWidth)
		end
		listStartY = y + #self.actions * (self.itemHeight + self.paddingY) + self.paddingY
	end
	-- Draw the list of items
	self.list.y = listStartY
	self.list:draw()

	-- Restrict drawing of checkboxes and selection indicator to visible area
	love.graphics.push()
	love.graphics.intersectScissor(self.x, listStartY, self.width, self.height - (listStartY - self.y))

	self.selectedCount = 0
	for idx, item in ipairs(self.items) do
		if item.checked then
			self.selectedCount = self.selectedCount + 1
		end
		-- Draw checkbox for each item
		local itemY = listStartY + (idx - 1) * (self.itemHeight + self.paddingY)
		self:drawCheckboxItem(item, itemY, buttonWidth)
	end

	love.graphics.pop()

	if self.selectedCount > 0 then
		local text = tostring(self.selectedCount) .. " item" .. (self.selectedCount == 1 and "" or "s") .. " selected"
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.setFont(font)
		local textWidth = font:getWidth(text)
		local tx = (screenWidth - textWidth) / 2
		local ty = self.y + self.height - controlsHeight - indicatorHeight + 12
		love.graphics.print(text, tx, ty)
	end
end

function ListSelect:drawCheckboxItem(item, y, buttonWidth)
	local boxSize = 28
	local padding = self.paddingX
	local font = love.graphics.getFont()
	local buttonHeight = self.itemHeight
	local boxX = self.x + padding
	local boxY = y + (buttonHeight - boxSize) / 2
	local textX = boxX + boxSize + padding
	local textY = y + (buttonHeight - font:getHeight()) / 2
	if item.selected then
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle("fill", self.x + self.paddingX, y, buttonWidth, buttonHeight, 8)
	end
	if item.checked then
		if SQUARE_CHECK_ICON then
			local iconColor = item.selected and { 1, 1, 1, 1 } or colors.ui.accent
			svg.drawIcon(SQUARE_CHECK_ICON, boxX + boxSize / 2, boxY + boxSize / 2, iconColor)
		end
	else
		if SQUARE then
			local iconColor = item.selected and { 1, 1, 1, 1 } or { 0.7, 0.7, 0.7, 1 }
			svg.drawIcon(SQUARE, boxX + boxSize / 2, boxY + boxSize / 2, iconColor)
		end
	end
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(font)
	love.graphics.print(item.text, textX, textY)
end

function ListSelect:drawActionButton(action, y, screenWidth)
	local font = love.graphics.getFont()
	local buttonHeight = self.itemHeight
	local buttonWidth = screenWidth - 2 * self.paddingX
	local x = self.x + self.paddingX
	if action.selected then
		love.graphics.setColor(0.2, 0.6, 1, 1)
		love.graphics.rectangle("fill", x, y, buttonWidth, buttonHeight, 8)
		love.graphics.setColor(1, 1, 1, 1)
	else
		love.graphics.setColor(0.9, 0.9, 0.9, 1)
		love.graphics.rectangle("fill", x, y, buttonWidth, buttonHeight, 8)
		love.graphics.setColor(0.1, 0.1, 0.1, 1)
	end
	love.graphics.setFont(font)
	love.graphics.print(action.text, x + self.paddingX, y + (buttonHeight - font:getHeight()) / 2)
end

-- Find the selected index in a list of items
function ListSelect:findSelectedIndex()
	return self.list:getSelectedIndex()
end

-- Helper function to navigate between items
function ListSelect:navigate(direction)
	return self.list:navigate(direction)
end

-- Adjust scroll position to ensure the selected item is visible
function ListSelect:adjustScrollPosition()
	return self.list:adjustScrollPosition()
end

-- Helper function to toggle checked state
function ListSelect:toggleChecked(index)
	self.list:toggleProperty(index, "checked")
end

function ListSelect:handleInput(input)
	self.list:handleInput(input)
end

function ListSelect:update(dt)
	self.list:update(dt)
	-- Sync selected state in self.items with the List's selectedIndex
	local selectedIndex = self.list.selectedIndex
	for idx, item in ipairs(self.items) do
		item.selected = (idx == selectedIndex)
	end
end

function ListSelect:getSelectedItems()
	local selected = {}
	for _, item in ipairs(self.items) do
		if item.selected then
			table.insert(selected, item)
		end
	end
	return selected
end

function ListSelect:getCheckedItems()
	local checked = {}
	for _, item in ipairs(self.items) do
		if item.checked then
			table.insert(checked, item)
		end
	end
	return checked
end

return {
	ListSelect = ListSelect,
}
