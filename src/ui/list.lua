--- List UI component
--- This file defines a reusable scrollable list of buttons

local love = require("love")
local button = require("ui.button")
local scrollView = require("ui.scroll_view")

-- Module table to export public functions
local list = {}

-- Draw a scrollable list of items
-- Returns a table with needsScrollBar (boolean) and visibleCount (number) properties
function list.draw(params)
	local items = params.items or {}
	local startY = params.startY or 0
	local itemHeight = params.itemHeight or button.BUTTON.HEIGHT
	local itemPadding = params.itemPadding or button.BUTTON.PADDING
	local scrollPosition = params.scrollPosition or 0
	local screenWidth = params.screenWidth or love.graphics.getWidth()
	local screenHeight = params.screenHeight or love.graphics.getHeight()
	local scrollBarWidth = params.scrollBarWidth or scrollView.SCROLL_BAR_WIDTH
	local itemCount = #items
	local visibleCount = params.visibleCount or math.floor((screenHeight - startY) / (itemHeight + itemPadding))
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
	button.setWidth(buttonWidth)

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
						button.draw(item.text, 0, y, item.selected, screenWidth)
					end
				end

				::continue::
			end
		end,
	})

	return {
		needsScrollBar = needsScrollBar,
		visibleCount = visibleCount,
	}
end

-- Adjust the scroll position to ensure the selected item is visible
function list.adjustScrollPosition(params)
	return scrollView.adjustScrollPosition({
		selectedIndex = params.selectedIndex,
		scrollPosition = params.scrollPosition,
		visibleCount = params.visibleCount,
	})
end

-- Helper function to find the currently selected item index
function list.findSelectedIndex(items)
	for i, item in ipairs(items) do
		if item.selected then
			return i
		end
	end
	return 1 -- Default to first item if none selected
end

-- Helper function to navigate between items
function list.navigate(items, direction)
	local currentIndex = list.findSelectedIndex(items)
	local newIndex = currentIndex + direction

	-- Wrap around if needed
	if newIndex < 1 then
		newIndex = #items
	elseif newIndex > #items then
		newIndex = 1
	end

	-- Update selection state
	for i, item in ipairs(items) do
		item.selected = (i == newIndex)
	end

	return newIndex
end

return list
