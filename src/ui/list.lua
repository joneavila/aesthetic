--- List UI component
--- This file defines a reusable scrollable list of buttons

local love = require("love")
local button = require("ui.button")
local scrollView = require("ui.scroll_view")

-- Module table to export public functions
local list = {}

-- Store the last scroll position to prevent jumps when moving focus out of the list
local lastScrollPosition = 0

-- Track the last selected item index when focus moves out of the list
local lastSelectedIndex = 1

-- Store whether selected item is transitioning to a bottom button
local movingToBottomButton = false

-- Draw a scrollable list of items
-- Returns a table with needsScrollBar (boolean) and visibleCount (number) properties
function list.draw(params)
	local items = params.items or {}
	local startY = params.startY or 0
	local itemHeight = params.itemHeight or button.calculateHeight()
	local scrollPosition = params.scrollPosition or lastScrollPosition
	local screenWidth = params.screenWidth or love.graphics.getWidth()
	local screenHeight = params.screenHeight or love.graphics.getHeight()
	local scrollBarWidth = params.scrollBarWidth or scrollView.SCROLL_BAR_WIDTH
	local itemCount = #items

	local itemPadding = button.BUTTON.SPACING

	-- Save the current scroll position
	lastScrollPosition = scrollPosition

	-- Calculate the visible content area height
	local contentAreaHeight = screenHeight - startY

	-- Calculate how many full items can fit in the visible area
	local visibleCount = math.floor(contentAreaHeight / (itemHeight + itemPadding))

	-- drawItemFunc: Function responsible for drawing each item
	-- Parameters:
	--   item: The current item being drawn (contains all properties like text, selected, etc.)
	--   index: The index of the item in the original items array
	--   y: The vertical position where the item should be drawn
	local drawItemFunc = params.drawItemFunc

	-- Calculate if scrollbar is needed
	local needsScrollBar = itemCount > visibleCount

	-- Set button width based on whether scrollbar is needed
	local buttonWidth = screenWidth - itemPadding - (needsScrollBar and scrollBarWidth or 0)

	-- Draw the list using scrollView
	scrollView.draw({
		contentCount = itemCount,
		visibleCount = visibleCount,
		scrollPosition = scrollPosition,
		startY = startY,
		contentHeight = itemHeight,
		contentPadding = itemPadding,
		screenWidth = screenWidth,
		scrollBarWidth = scrollBarWidth,
		contentDrawFunc = function()
			local visibleItemCount = 0

			for i, item in ipairs(items) do
				-- Skip if item is scrolled out of view
				if i <= scrollPosition or i > scrollPosition + visibleCount then
					goto continue
				end

				visibleItemCount = visibleItemCount + 1
				local y = startY + (visibleItemCount - 1) * (itemHeight + itemPadding)

				-- Skip if item would be partially drawn outside the content area
				if y + itemHeight > screenHeight then
					goto continue
				end

				-- If there's a custom drawing function, let the caller handle all drawing
				if drawItemFunc then
					drawItemFunc(item, i, y)
				else
					-- Default drawing behavior if no custom function provided
					if item.options then
						-- For items with multiple options
						local currentValue = item.options[item.currentOption]
						button.drawWithIndicators(
							item.text,
							0,
							y,
							item.selected,
							item.disabled,
							screenWidth,
							currentValue
						)
					elseif item.min ~= nil and item.max ~= nil then
						-- For numeric ranges
						local currentValue = item.value or item.min
						button.drawWithIndicators(
							item.text,
							0,
							y,
							item.selected,
							item.disabled,
							screenWidth,
							tostring(currentValue)
						)
					elseif item.valueText then
						-- For items with valueText property
						button.drawWithIndicators(
							item.text,
							0,
							y,
							item.selected,
							item.disabled,
							screenWidth,
							item.valueText
						)
					elseif item.value then
						-- For items with a simple value display
						button.drawWithTextPreview(item.text, 0, y, item.selected, screenWidth, tostring(item.value))
					else
						-- Basic button with no extras
						button.draw(item.text, 0, y, item.selected, screenWidth, buttonWidth)
					end
				end

				::continue::
			end
		end,
	})

	return {
		needsScrollBar = needsScrollBar,
		visibleCount = visibleCount,
		firstVisibleItem = math.floor(scrollPosition) + 1,
		lastVisibleItem = math.min(math.floor(scrollPosition) + visibleCount, itemCount),
	}
end

-- Adjust the scroll position to ensure the selected item is visible
function list.adjustScrollPosition(params)
	local oldScrollPosition = params.scrollPosition
	local selectedIndex = params.selectedIndex > 0 and params.selectedIndex or lastSelectedIndex

	-- If we're transitioning to a bottom button, maintain current scroll position
	if movingToBottomButton then
		movingToBottomButton = false
		return oldScrollPosition
	end

	local newScrollPosition = scrollView.adjustScrollPosition({
		selectedIndex = selectedIndex,
		scrollPosition = params.scrollPosition,
		visibleCount = params.visibleCount,
	})

	-- Update the lastScrollPosition so it's maintained even when focus leaves the list
	lastScrollPosition = newScrollPosition

	-- Store the selected index for when focus leaves the list
	if params.selectedIndex > 0 then
		lastSelectedIndex = params.selectedIndex
	end

	return newScrollPosition
end

-- Helper function to find the currently selected item index
function list.findSelectedIndex(items)
	for i, item in ipairs(items) do
		if item.selected then
			return i
		end
	end
	return -1 -- Return -1 if none selected instead of defaulting to 1
end

-- Helper function to navigate between items
function list.navigate(items, direction)
	local currentIndex = list.findSelectedIndex(items)

	-- If no item is selected but remembered index exists, use that
	if currentIndex == -1 then
		currentIndex = lastSelectedIndex
	end

	local newIndex = currentIndex + direction

	-- Wrap around if needed
	if newIndex < 1 then
		newIndex = #items
	elseif newIndex > #items then
		newIndex = 1
	end

	-- Check if transitioning from regular list to bottom button
	local wasLastItem = (currentIndex == #items - 1 and direction == 1)
	if wasLastItem and newIndex == #items then
		movingToBottomButton = true
	end

	-- Update selection state
	for i, item in ipairs(items) do
		item.selected = (i == newIndex)
	end

	-- Store the new index if it's within the regular items
	if newIndex >= 1 and newIndex <= #items - 1 then -- Assuming last item is always the bottom button
		lastSelectedIndex = newIndex
	end

	return newIndex
end

-- Set whether moving to a bottom button
function list.setMovingToBottomButton(value)
	movingToBottomButton = value
end

-- Reset the stored scroll position (useful when switching screens)
function list.resetScrollPosition()
	lastScrollPosition = 0
	lastSelectedIndex = 1
	movingToBottomButton = false
end

-- Get the current scroll position
function list.getScrollPosition()
	return lastScrollPosition
end

-- Get the last selected index (useful for maintaining position when focus moves out of list)
function list.getLastSelectedIndex()
	return lastSelectedIndex
end

return list
