--- New List Component
--- A clean, reusable scrollable list component
local love = require("love")

local colors = require("colors")

local Component = require("ui.component").Component
local slider = require("ui.components.slider")
local InputManager = require("ui.controllers.input_manager")

-- List constants
local LIST_CONFIG = {
	ITEM_SPACING = 14,
	SCROLL_BAR_WIDTH = 6,
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
	instance.wrap = config.wrap ~= false -- Default true
	instance.paddingX = config.paddingX or 12
	instance.paddingY = config.paddingY or 8

	-- Height redistribution properties
	instance.adjustedItemHeight = instance.itemHeight
	instance.adjustedSpacing = instance.spacing
	instance.shouldRedistribute = false

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

		-- Check if we should redistribute height
		-- This happens when there are more items than can be shown, or when adding one more item wouldn't fit
		local totalItems = #self.items
		local wouldFitOneMore = (self.visibleCount + 1) * itemWithSpacing <= availableHeight
		self.shouldRedistribute = (totalItems > self.visibleCount)
			or (totalItems == self.visibleCount and not wouldFitOneMore)

		if self.shouldRedistribute and self.visibleCount > 0 then
			-- Calculate redistributed heights
			-- Total height used by spacing between items (n-1 spacings for n items)
			local totalSpacingHeight = (self.visibleCount - 1) * self.spacing
			-- Remaining height to distribute among items
			local heightForItems = availableHeight - totalSpacingHeight
			-- New item height
			self.adjustedItemHeight = heightForItems / self.visibleCount
			self.adjustedSpacing = self.spacing -- Keep original spacing
		else
			-- No redistribution needed, use original values
			self.adjustedItemHeight = self.itemHeight
			self.adjustedSpacing = self.spacing
		end
	else
		self.visibleCount = 0
		self.shouldRedistribute = false
		self.adjustedItemHeight = self.itemHeight
		self.adjustedSpacing = self.spacing
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
	-- Update focused state for all items (works for any component with setFocused)
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

function List:handleInput(direction, input)
	if not self.enabled or #self.items == 0 then
		return false
	end

	local handled = false

	-- Handle navigation only if direction is provided by parent
	if direction == "up" then
		if not self.wrap and self.selectedIndex == 1 then
			return "start"
		elseif not self.wrap and self.selectedIndex == 0 then
			return false
		end
		handled = self:navigate(-1)
	elseif direction == "down" then
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

	local selectedItem = self:getSelectedItem()
	-- If the selected item is a Slider, let it handle all input (left/right, etc.)
	if selectedItem and selectedItem.handleInput and selectedItem.__index and selectedItem.__index == slider.Slider then
		if selectedItem:handleInput(input) then
			return true
		end
	end

	-- Handle item selection
	if InputManager.isActionPressed(InputManager.ACTIONS.CONFIRM) then
		if selectedItem and self.onItemSelect then
			self.onItemSelect(selectedItem, self.selectedIndex)
			handled = true
		end
	end

	-- Handle option cycling - left and right separately (for non-slider items)
	if InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_LEFT) then
		if
			selectedItem
			and selectedItem.handleInput
			and not (selectedItem.__index and selectedItem.__index == slider.Slider)
			and selectedItem:handleInput(input)
		then
			handled = true
		elseif self.onItemOptionCycle then
			local changed = self.onItemOptionCycle(selectedItem, -1)
			if changed then
				handled = true
			end
		end
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_RIGHT) then
		if
			selectedItem
			and selectedItem.handleInput
			and not (selectedItem.__index and selectedItem.__index == slider.Slider)
			and selectedItem:handleInput(input)
		then
			handled = true
		elseif self.onItemOptionCycle then
			local changed = self.onItemOptionCycle(selectedItem, 1)
			if changed then
				handled = true
			end
		end
	end

	return handled
end

function List:draw()
	if not self.visible or #self.items == 0 then
		return
	end
	love.graphics.push("all")
	-- Always recalculate dimensions before drawing to ensure height/width changes are respected
	self:calculateDimensions()
	-- Calculate visible range based on scroll position
	local firstVisible = math.floor(self.scrollPosition) + 1
	local lastVisible = math.min(firstVisible + self.visibleCount - 1, #self.items)
	-- Determine if scrollbar is needed
	local needsScrollbar = #self.items > self.visibleCount
	local scrollbarWidth = LIST_CONFIG.SCROLL_BAR_WIDTH
	local effectiveRightPadding = self.paddingX
	if needsScrollbar then
		effectiveRightPadding = self.paddingX + scrollbarWidth
	end
	-- Create scissor to clip content
	love.graphics.push("all")
	love.graphics.intersectScissor(self.x, self.y, self.width, self.height)
	-- Draw visible items
	for i = firstVisible, lastVisible do
		local item = self.items[i]
		if item then
			-- Calculate item position (relative to the list, not scrolled content)
			local itemIndex = i - firstVisible -- Index within visible items (0-based)
			local itemY = self.y + self.paddingY + itemIndex * (self.adjustedItemHeight + self.adjustedSpacing)
			local itemX = self.x + self.paddingX
			local itemW = self.width - self.paddingX - effectiveRightPadding
			local itemH = self.adjustedItemHeight
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
	if needsScrollbar then
		local barX = self.x + self.width - scrollbarWidth
		local rx = 4
		local ry = rx
		-- Draw scrollbar handle
		local barHeight = (self.height - self.paddingY * 2) * (self.visibleCount / #self.items)
		local barY = self.y
			+ self.paddingY
			+ ((self.height - self.paddingY * 2) - barHeight)
				* (self.scrollPosition / (#self.items - self.visibleCount))
		love.graphics.setColor(colors.ui.scrollbar)
		love.graphics.rectangle("fill", barX, barY, scrollbarWidth, barHeight, rx, ry)
	end
	love.graphics.pop()
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

function List:getContentHeight()
	local itemCount = #self.items
	if itemCount == 0 then
		return 0
	end
	-- Total height: paddingY (top) + all items + all spacings + paddingY (bottom)
	return self.paddingY + itemCount * self.adjustedItemHeight + (itemCount - 1) * self.adjustedSpacing + self.paddingY
end

-- Module exports
local list = {}
list.List = List

return list
