--- New List Component
--- A clean, reusable scrollable list component
local love = require("love")

local Component = require("ui.component").Component
local inputHandler = require("ui.input_handler")

-- List constants
local LIST_CONFIG = {
	ITEM_SPACING = 12,
	SCROLL_BAR_WIDTH = 8,
}

-- List class
local List = setmetatable({}, { __index = Component })
List.__index = List

function List:new(config)
	-- Initialize base component
	local instance = Component.new(self, config)

	-- List-specific properties
	instance.items = config.items or {}
	instance.selectedIndex = config.selectedIndex or 1
	instance.scrollPosition = config.scrollPosition or 0
	instance.itemHeight = config.itemHeight or 50
	instance.spacing = config.spacing or LIST_CONFIG.ITEM_SPACING
	instance.visibleCount = 0
	instance.wrap = config.wrap ~= false -- default true
	instance.paddingX = config.paddingX or 12
	instance.paddingY = config.paddingY or 8

	-- Callbacks
	instance.onItemSelect = config.onItemSelect
	instance.onItemOptionCycle = config.onItemOptionCycle

	-- Calculate dimensions
	instance:calculateDimensions()
	instance:updateSelection()

	return instance
end

function List:calculateDimensions()
	if #self.items > 0 then
		-- Calculate how many items can fit, accounting for spacing between items and vertical padding
		local availableHeight = self.height - self.paddingY * 2
		local itemWithSpacing = self.itemHeight + self.spacing
		self.visibleCount = math.floor(availableHeight / itemWithSpacing)
		self.visibleCount = math.max(1, math.min(self.visibleCount, #self.items))
	else
		self.visibleCount = 0
	end
end

function List:setItems(items)
	self.items = items or {}
	if self.selectedIndex > #self.items then
		self.selectedIndex = math.max(1, #self.items)
	end
	self:updateSelection()
	self:calculateDimensions()
end

function List:addItem(item)
	table.insert(self.items, item)
	self:calculateDimensions()
end

function List:removeItem(index)
	if index >= 1 and index <= #self.items then
		table.remove(self.items, index)
		if self.selectedIndex > #self.items and #self.items > 0 then
			self.selectedIndex = #self.items
		elseif #self.items == 0 then
			self.selectedIndex = 1
		end
		self:updateSelection()
		self:calculateDimensions()
	end
end

function List:getSelectedItem()
	if self.selectedIndex >= 1 and self.selectedIndex <= #self.items then
		return self.items[self.selectedIndex]
	end
	return nil
end

function List:getSelectedIndex()
	return self.selectedIndex
end

function List:setSelectedIndex(index)
	if (index == 0) or (index >= 1 and index <= #self.items) then
		self.selectedIndex = index
		self:updateSelection()
		if index > 0 then
			self:adjustScrollPosition()
		end
	end
end

function List:updateSelection()
	-- Update focused state for all items
	for i, item in ipairs(self.items) do
		if item.setFocused then
			item:setFocused(i == self.selectedIndex and self.selectedIndex > 0)
		elseif item.focused ~= nil then
			item.focused = (i == self.selectedIndex and self.selectedIndex > 0)
		end
	end
end

function List:navigate(direction)
	if #self.items == 0 then
		return false
	end

	local oldIndex = self.selectedIndex
	local newIndex = self.selectedIndex + direction

	if self.wrap then
		if newIndex < 1 then
			newIndex = #self.items
		elseif newIndex > #self.items then
			newIndex = 1
		end
	else
		if newIndex < 1 then
			newIndex = 1
		elseif newIndex > #self.items then
			newIndex = #self.items
		end
	end

	if newIndex ~= oldIndex then
		self.selectedIndex = newIndex
		self:updateSelection()
		self:adjustScrollPosition(direction)
		return true
	end

	return false
end

function List:adjustScrollPosition(direction)
	if #self.items <= self.visibleCount then
		self.scrollPosition = 0
		return
	end

	direction = direction or 0
	local maxScrollPosition = math.max(0, #self.items - self.visibleCount)

	-- When wrapping from last to first item, reset scroll position
	if direction == 1 and self.selectedIndex == 1 and self.scrollPosition > 0 then
		self.scrollPosition = 0
		return
	end

	-- When wrapping from first to last item, scroll to end
	if direction == -1 and self.selectedIndex == #self.items then
		self.scrollPosition = maxScrollPosition
		return
	end

	-- Calculate what the first and last visible items should be
	local firstVisible = math.floor(self.scrollPosition) + 1
	local lastVisible = firstVisible + self.visibleCount - 1

	-- Only adjust scroll if selected item is not visible
	if self.selectedIndex < firstVisible then
		-- Scrolling up: selected item should be first visible
		self.scrollPosition = self.selectedIndex - 1
	elseif self.selectedIndex > lastVisible then
		-- Scrolling down: selected item should be last visible
		self.scrollPosition = self.selectedIndex - self.visibleCount
	end

	-- Ensure scroll position is within bounds
	self.scrollPosition = math.max(0, math.min(self.scrollPosition, maxScrollPosition))
end

function List:handleInput(input)
	if not self.enabled or #self.items == 0 then
		return false
	end

	-- Ensure input has isPressed method (wrap if needed)
	if not input or type(input.isPressed) ~= "function" then
		input = inputHandler.create(input)
	end

	local handled = false

	-- Handle navigation first
	if input.isPressed("dpup") then
		if not self.wrap and self.selectedIndex == 1 then
			return "start"
		elseif not self.wrap and self.selectedIndex == 0 then
			return false
		end
		handled = self:navigate(-1)
	elseif input.isPressed("dpdown") then
		if not self.wrap and self.selectedIndex == #self.items then
			return "end"
		elseif not self.wrap and self.selectedIndex == 0 then
			return false
		end
		handled = self:navigate(1)
	end

	-- If navigation was handled, don't process other inputs
	if handled then
		return true
	end

	-- Handle item selection
	if input.isPressed("a") then
		local selectedItem = self:getSelectedItem()
		if selectedItem and self.onItemSelect then
			self.onItemSelect(selectedItem, self.selectedIndex)
			handled = true
		end
	end

	-- Handle option cycling - left and right separately
	if input.isPressed("dpleft") then
		local selectedItem = self:getSelectedItem()
		if selectedItem then
			if selectedItem.handleInput and selectedItem:handleInput(input) then
				handled = true
			elseif self.onItemOptionCycle then
				local changed = self.onItemOptionCycle(selectedItem, -1)
				if changed then
					handled = true
				end
			end
		end
	elseif input.isPressed("dpright") then
		local selectedItem = self:getSelectedItem()
		if selectedItem then
			if selectedItem.handleInput and selectedItem:handleInput(input) then
				handled = true
			elseif self.onItemOptionCycle then
				local changed = self.onItemOptionCycle(selectedItem, 1)
				if changed then
					handled = true
				end
			end
		end
	end

	return handled
end

function List:draw()
	if not self.visible or #self.items == 0 then
		return
	end

	-- Calculate visible range based on scroll position
	local firstVisible = math.floor(self.scrollPosition) + 1
	local lastVisible = math.min(firstVisible + self.visibleCount - 1, #self.items)

	-- Create scissor to clip content
	love.graphics.push()
	love.graphics.intersectScissor(self.x, self.y, self.width, self.height)

	-- Draw visible items
	for i = firstVisible, lastVisible do
		local item = self.items[i]
		if item then
			-- Calculate item position (relative to the list, not scrolled content)
			local itemIndex = i - firstVisible -- Index within visible items (0-based)
			local itemY = self.y + self.paddingY + itemIndex * (self.itemHeight + self.spacing)
			local itemX = self.x + self.paddingX
			local itemW = self.width - self.paddingX * 2
			local itemH = self.itemHeight

			-- Set item position
			if item.setPosition then
				item:setPosition(itemX, itemY)
			else
				item.x = itemX
				item.y = itemY
			end

			-- Set item size if needed
			if item.setSize then
				item:setSize(itemW, itemH)
			elseif item.width == nil or item.height == nil then
				item.width = itemW
				item.height = itemH
			end

			-- Draw the item
			if item.draw then
				item:draw()
			end
		end
	end

	love.graphics.pop()
	love.graphics.setScissor() -- Reset scissor to avoid affecting other UI

	-- Draw scrollbar if needed
	if #self.items > self.visibleCount then
		local barHeight = (self.height - self.paddingY * 2) * (self.visibleCount / #self.items)
		local barY = self.y
			+ self.paddingY
			+ ((self.height - self.paddingY * 2) - barHeight)
				* (self.scrollPosition / (#self.items - self.visibleCount))
		local barX = self.x + self.width - 6 -- 6px from the right edge
		love.graphics.setColor(1, 1, 1, 0.3)
		love.graphics.rectangle("fill", barX, barY, 4, barHeight, 2, 2)
	end
end

function List:update(dt)
	Component.update(self, dt)

	-- Update all items
	for _, item in ipairs(self.items) do
		if item.update then
			item:update(dt)
		end
	end
end

-- Module exports
local list = {}
list.List = List

return list
