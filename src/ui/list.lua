--- List UI component
--- This file defines a reusable scrollable list of buttons
---
--- Scrolling Behavior:
--- 1. At the beginning of the list, items 1 through visibleCount are shown
--- 2. As user scrolls down, the selection moves down until reaching the bottom position
--- 3. When scrolling past the last visible item:
---    - The list scrolls by exactly ONE item at a time
---    - The previously last visible item becomes the second-to-last
---    - The previously hidden next item becomes visible as the new last item
--- 4. When approaching the end of the list, the final scroll position shows
---    the last visibleCount items (items totalCount-visibleCount+1 through totalCount)
--- 5. The highlight/focus should always be visible and positioned correctly
---    relative to the visible items

local love = require("love")
local button = require("ui.button")
local scrollable = require("ui.scrollable")

-- Module table to export public functions
local list = {}

--------------------------------------------------
-- STATE TRACKING
--------------------------------------------------

-- Store the last scroll position to prevent jumps when moving focus out of the list
local lastScrollPosition = 0

-- Track the selected item index
local selectedIndex = 1

-- Track the selected item itself
local selectedItem = nil

-- Store the currently visible range to help with navigation
local currentVisibleRange = { first = 1, last = 1 }

--------------------------------------------------
-- CONFIG CONSTANTS
--------------------------------------------------

-- Default configuration values that can be overridden by params
list.DEFAULT_CONFIG = {
	startY = 0,
	itemPadding = button.BUTTON.SPACING,
}

-- Draw a scrollable list of items
-- Returns a table with information about the list state
function list.draw(params)
	local items = params.items or {}
	local startY = params.startY or list.DEFAULT_CONFIG.startY
	local itemHeight = params.itemHeight
	local scrollPosition = params.scrollPosition or lastScrollPosition
	local screenWidth = params.screenWidth or love.graphics.getWidth()
	local screenHeight = params.screenHeight or love.graphics.getHeight()
	local itemCount = #items
	local itemPadding = params.itemPadding or list.DEFAULT_CONFIG.itemPadding
	local edgeMargin = button.BUTTON.EDGE_MARGIN
	local logger = require("utils.logger")
	local drawItemFunc = params.drawItemFunc

	-- Check if drawItemFunc is provided
	if not drawItemFunc then
		logger.error("list.draw: drawItemFunc is required")
		return {}
	end

	-- Set a custom button height if specified in params
	if itemHeight then
		button.setDefaultHeight(itemHeight)
	else
		-- Otherwise use the button's calculation
		itemHeight = button.getHeight()
	end

	local reservedBottomSpace = params.reservedBottom or 0

	-- Save the current scroll position
	lastScrollPosition = scrollPosition

	-- Calculate the visible content area height
	local contentAreaHeight = screenHeight - startY - reservedBottomSpace

	-- Calculate how many full items can fit in the visible area
	local visibleCount = math.floor(contentAreaHeight / (itemHeight + itemPadding))
	visibleCount = math.min(visibleCount, itemCount)

	-- Ensure scroll position doesn't exceed maximum valid position and is an integer
	local maxScrollPosition = math.max(0, itemCount - visibleCount)
	scrollPosition = math.floor(math.min(scrollPosition, maxScrollPosition))

	local needsScrollBar, availableWidth

	-- Calculate total content height (including padding)
	-- Make sure we account for correct spacing between all items
	local totalContentHeight = (itemCount * itemHeight) + ((itemCount - 1) * itemPadding)

	local viewportHeight = (visibleCount * itemHeight) + ((visibleCount - 1) * itemPadding)

	local pixelScrollPosition = scrollPosition * (itemHeight + itemPadding)

	-- Define a content drawing function for scrollable
	local function drawContent()
		-- Track the displayed items for our hardcoded fix
		local displayedItems = {}

		for i, item in ipairs(items) do
			-- We're no longer accounting for scroll position in the Y calculation because
			-- the scrollable container already applied the translation via pixelScrollPosition
			local y = startY + (i - 1) * (itemHeight + itemPadding)
			local itemEndY = y + itemHeight

			-- Calculate visible index without affecting positioning
			local visibleIndex = i - math.floor(scrollPosition)

			-- Only draw the item if it would be in the visible area after translation
			-- Check if the item would be visible in the viewport after translation
			if y + itemHeight > pixelScrollPosition and y < pixelScrollPosition + viewportHeight + 1 then
				local displayY = y -- We don't subtract pixelScrollPosition here because scrollable.drawContent handles this
				drawItemFunc(item, i, displayY, screenWidth, availableWidth)
				table.insert(displayedItems, i)
			end
		end

		-- HARDCODED FIX: Always display the last item that should be visible based on our scrollPosition and visibleCount
		local expectedLastVisibleItem = math.floor(scrollPosition) + visibleCount
		if expectedLastVisibleItem <= itemCount then
			local alreadyDisplayed = false
			for _, displayedIndex in ipairs(displayedItems) do
				if displayedIndex == expectedLastVisibleItem then
					alreadyDisplayed = true
					break
				end
			end
			if not alreadyDisplayed then
				local y = startY + (expectedLastVisibleItem - 1) * (itemHeight + itemPadding)
				drawItemFunc(items[expectedLastVisibleItem], expectedLastVisibleItem, y, screenWidth, availableWidth)
				table.insert(displayedItems, expectedLastVisibleItem)
			end
		end
	end

	-- Draw the list using scrollable.drawContent
	local metrics = scrollable.drawContent({
		x = 0,
		y = startY,
		width = screenWidth,
		height = viewportHeight,
		scrollPosition = pixelScrollPosition,
		contentSize = totalContentHeight,
		drawContent = drawContent,
	})

	needsScrollBar = metrics.needsScrollBar
	availableWidth = metrics.contentWidth

	-- Calculate actual first and last visible items based on our drawing criteria
	-- This must match the logic in our drawContent function
	local visibleItems = {}
	for i = 1, itemCount do
		local y = startY + (i - 1) * (itemHeight + itemPadding)
		if y + itemHeight > pixelScrollPosition and y < pixelScrollPosition + viewportHeight + 1 then
			table.insert(visibleItems, i)
		end
	end

	local firstVisibleItem = visibleItems[1] or math.floor(scrollPosition) + 1
	local lastVisibleItem = visibleItems[#visibleItems] or math.min(firstVisibleItem + visibleCount - 1, itemCount)

	-- Store the current visible range for navigation purposes
	currentVisibleRange = {
		first = firstVisibleItem,
		last = lastVisibleItem,
	}

	return {
		needsScrollBar = needsScrollBar,
		visibleCount = visibleCount,
		firstVisibleItem = firstVisibleItem,
		lastVisibleItem = lastVisibleItem,
		availableWidth = availableWidth,
		totalCount = itemCount,
	}
end

-- Adjust the scroll position to ensure the selected item is visible
-- Uses fixed positioning to maintain the selected item at a consistent position
function list.adjustScrollPosition(params)
	local logger = require("utils.logger")

	local currSelectedIndex = params.selectedIndex > 0 and params.selectedIndex or selectedIndex
	local totalCount = params.totalCount or #(params.items or {})
	local visibleCount = params.visibleCount or 0
	local oldScrollPosition = params.scrollPosition or 0
	local direction = params.direction or 0 -- -1 for up, 1 for down, 0 for unknown
	local isWrapping = params.isWrapping or false -- New parameter to indicate wrap-around

	logger.debug(
		"list.adjustScrollPosition - selectedIndex: "
			.. currSelectedIndex
			.. ", visibleCount: "
			.. visibleCount
			.. ", totalCount: "
			.. totalCount
			.. ", direction: "
			.. direction
	)

	-- If the list has fewer items than visible capacity, show from the beginning
	if totalCount <= visibleCount then
		return 0
	end

	-- When wrapping from last to first item, reset scroll position to 0
	if direction == 1 and currSelectedIndex == 1 and oldScrollPosition > 0 then
		logger.debug("Wrapping to top of list, resetting scroll position to 0")
		return 0
	end

	-- Calculate the maximum valid scroll position
	local maxScrollPosition = math.max(0, totalCount - visibleCount)

	-- Calculate the current first visible item
	local firstVisible = math.floor(oldScrollPosition) + 1

	-- Special case for navigating up: if we're going from the first visible item to the
	-- item just above it, we want to scroll exactly one item up
	if direction == -1 and currSelectedIndex == firstVisible - 1 then
		logger.debug("Special case: scrolling exactly one item up")
		return math.max(0, oldScrollPosition - 1)
	end

	-- Early in the list: fixed positioning until we need to scroll
	if currSelectedIndex <= visibleCount then
		logger.debug("Early in list, showing from beginning")
		return 0
	end

	-- Near end of list: ensure we always show exactly visibleCount items
	-- This condition ensures we switch to end-of-list mode when the selected item
	-- would be in the last visible set of items
	if currSelectedIndex > totalCount - visibleCount and currSelectedIndex == totalCount then
		logger.debug("At end of list, showing last section: " .. maxScrollPosition)
		return maxScrollPosition
	end

	-- Middle of list: position the selected item correctly in the visible area
	-- This fixes the jumping issue by using only the current selected index, not old scroll position
	local newScrollPosition = currSelectedIndex - visibleCount

	-- Use a smooth formula that ensures the selected item is always in the visible range
	-- but prevents jumps when navigating linearly
	if currSelectedIndex > visibleCount then
		newScrollPosition = currSelectedIndex - visibleCount
	end

	logger.debug("Middle of list, positioning item: " .. newScrollPosition)

	-- Ensure the new scroll position is within valid bounds and prevent excessive jumps
	newScrollPosition = math.max(0, math.min(newScrollPosition, maxScrollPosition))

	-- Limit jump distance to at most one item when navigating down
	if newScrollPosition > oldScrollPosition and newScrollPosition - oldScrollPosition > 1 then
		newScrollPosition = oldScrollPosition + 1
		logger.debug("Limited scroll jump to one item down: " .. newScrollPosition)
	end

	-- Limit jump distance to at most one item when navigating up
	if newScrollPosition < oldScrollPosition and oldScrollPosition - newScrollPosition > 1 then
		newScrollPosition = oldScrollPosition - 1
		logger.debug("Limited scroll jump to one item up: " .. newScrollPosition)
	end

	-- Store the last selected index when explicit selectedIndex is provided
	if params.selectedIndex > 0 then
		selectedIndex = params.selectedIndex
	end

	return math.floor(newScrollPosition)
end

-- Helper function to navigate between items
function list.navigate(items, direction)
	local logger = require("utils.logger")

	logger.debug(
		"list.navigate - currentIndex: " .. selectedIndex .. ", direction: " .. direction .. ", items count: " .. #items
	)

	-- Calculate new index
	local newIndex = selectedIndex + direction

	-- Wrap around if needed
	if newIndex < 1 then
		newIndex = #items
		logger.debug("Wrapping to bottom: " .. newIndex)
	elseif newIndex > #items then
		newIndex = 1
		logger.debug("Wrapping to top: " .. newIndex)
	end

	-- Update selection state for all items
	for i, item in ipairs(items) do
		local wasSelected = item.selected
		item.selected = (i == newIndex)

		if wasSelected ~= item.selected then
			logger.debug(
				"Selection changed for item " .. i .. ": " .. tostring(wasSelected) .. " -> " .. tostring(item.selected)
			)
		end

		-- Store reference to the selected item
		if item.selected then
			selectedItem = item
		end
	end

	-- Update the selected index
	selectedIndex = newIndex
	logger.debug("Updated selectedIndex to: " .. newIndex)

	-- Update the current visible range to reflect the new selection
	-- This helps ensure that subsequent navigation will be based on correct values
	-- First estimate what the visible range should be after this navigation
	if direction > 0 and currentVisibleRange.last < newIndex then
		-- Moving down past the last visible item
		currentVisibleRange.first = currentVisibleRange.first + 1
		currentVisibleRange.last = newIndex
	elseif direction < 0 and currentVisibleRange.first > newIndex then
		-- Moving up past the first visible item
		currentVisibleRange.first = newIndex
		currentVisibleRange.last = currentVisibleRange.last - 1
	end

	return newIndex
end

-- TODO: Toggle of button should be `button.lua`
-- Helper: toggle a boolean property on an item
function list.toggleProperty(items, index, property)
	if items[index] and property then
		items[index][property] = not items[index][property]
	end
end

-- Handle input for a list and return updated list state
-- This is a new comprehensive function that screens can use
function list.handleInput(params)
	local items = params.items or {}
	local scrollPosition = params.scrollPosition or lastScrollPosition
	local visibleCount = params.visibleCount or 0
	local virtualJoystick = params.virtualJoystick or require("input").virtualJoystick
	local handleItemSelect = params.handleItemSelect -- Callback for A button
	local handleItemOption = params.handleItemOption -- Callback for left/right
	local logger = require("utils.logger")

	-- Ensure scroll position is an integer
	scrollPosition = math.floor(scrollPosition)

	local result = {
		scrollPositionChanged = false,
		selectedIndexChanged = false,
		optionChanged = false,
		scrollPosition = scrollPosition,
		selectedIndex = selectedIndex,
		direction = 0, -- Track navigation direction
	}

	-- Calculate current visible item range
	local firstVisible = math.floor(scrollPosition) + 1
	local lastVisible = firstVisible + visibleCount - 1

	-- Handle D-pad up/down navigation
	if virtualJoystick.isGamepadPressedWithDelay("dpup") then
		logger.debug("List handling dpup")
		local oldIndex = result.selectedIndex
		result.selectedIndex = list.navigate(items, -1)
		result.direction = -1 -- Set direction to up
		result.selectedIndexChanged = (oldIndex ~= result.selectedIndex)

		-- Check for wrap-around when pressing up (going from first to last item)
		local isWrappingToBottom = (oldIndex == 1 and result.selectedIndex == #items)

		-- When navigating up, we need to scroll if:
		-- 1. Moving to an item completely above the visible range, OR
		-- 2. Wrapping around from the first item to the last item
		if result.selectedIndex < firstVisible or isWrappingToBottom then
			-- We need to scroll
			result.scrollPositionChanged = true
		else
			-- We're navigating within the visible range, no need to scroll
			result.scrollPositionChanged = false
		end
	elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
		logger.debug("List handling dpdown")
		local oldIndex = result.selectedIndex
		result.selectedIndex = list.navigate(items, 1)
		result.direction = 1 -- Set direction to down
		result.selectedIndexChanged = (oldIndex ~= result.selectedIndex)

		-- Check for wrap-around when pressing down (going from last to first item)
		local isWrappingToTop = (oldIndex == #items and result.selectedIndex == 1)

		-- Only update scroll position if:
		-- 1. New selection is below visible range, OR
		-- 2. Wrapping around from the last item to the first item
		if result.selectedIndex > lastVisible or isWrappingToTop then
			result.scrollPositionChanged = true
		else
			-- We're navigating within the visible range, no need to scroll
			result.scrollPositionChanged = false
		end
	end

	-- Handle left/right for option cycling
	local pressedLeft = virtualJoystick.isGamepadPressedWithDelay("dpleft")
	local pressedRight = virtualJoystick.isGamepadPressedWithDelay("dpright")

	if (pressedLeft or pressedRight) and handleItemOption and selectedItem then
		local direction = pressedLeft and -1 or 1
		local changed = handleItemOption(selectedItem, direction)
		result.optionChanged = changed or false
	end

	-- Handle A button for selection
	if virtualJoystick.isGamepadPressedWithDelay("a") and handleItemSelect and selectedItem then
		handleItemSelect(selectedItem, selectedIndex)
	end

	-- Update scroll position if navigation occurred and selection is outside visible range
	if result.scrollPositionChanged then
		logger.debug(
			"Need to scroll - firstVisible: "
				.. firstVisible
				.. ", lastVisible: "
				.. lastVisible
				.. ", selectedIndex: "
				.. result.selectedIndex
				.. ", direction: "
				.. result.direction
		)

		-- Check if we're wrapping around (for dpdown only, dpup is already handled correctly)
		local isWrapping = (result.direction == 1 and result.selectedIndex == 1 and oldIndex == #items)

		-- Get the new scroll position - pass total item count to ensure proper calculation
		local newScrollPosition = list.adjustScrollPosition({
			selectedIndex = result.selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleCount,
			totalCount = #items,
			items = items, -- Pass items to ensure proper count
			direction = result.direction, -- Pass the direction
			isWrapping = isWrapping, -- Pass wrapping info
		})

		-- Ensure the new scroll position is an integer
		newScrollPosition = math.floor(newScrollPosition)

		-- Update result with the new scroll position
		result.scrollPosition = newScrollPosition

		logger.debug("After scroll adjustment - new scrollPosition: " .. result.scrollPosition)
	end

	return result
end

-- Helper function for item cycling
-- Changes option values based on the specified property and options
function list.cycleItemOption(item, direction, property, options)
	if not item or not property or not options or #options == 0 then
		return false
	end

	local currentValue = item[property]
	local currentIndex = 1

	-- Find current index in options
	for i, option in ipairs(options) do
		if option == currentValue then
			currentIndex = i
			break
		end
	end

	-- Calculate new index with wrap-around
	local newIndex = currentIndex + direction
	if newIndex < 1 then
		newIndex = #options
	elseif newIndex > #options then
		newIndex = 1
	end

	-- Set new value
	item[property] = options[newIndex]
	return true
end

--------------------------------------------------
-- STATE MANAGEMENT
--------------------------------------------------

-- Reset the stored scroll position (useful when switching screens)
function list.resetScrollPosition()
	lastScrollPosition = 0
	selectedIndex = 1
	selectedItem = nil
	currentVisibleRange = { first = 1, last = 1 }
end

-- Get the current scroll position
function list.getScrollPosition()
	return lastScrollPosition
end

-- Get the selected index
function list.getSelectedIndex()
	return selectedIndex
end

-- Get the selected item
function list.getSelectedItem()
	return selectedItem
end

-- Set the scroll position to a specific value
function list.setScrollPosition(pos)
	lastScrollPosition = pos or 0
end

-- Set the selected index to a specific value
function list.setSelectedIndex(index, items)
	if items and index >= 1 and index <= #items then
		-- Update previous selections
		for i, item in ipairs(items) do
			item.selected = (i == index)
			if item.selected then
				selectedItem = item
			end
		end
		selectedIndex = index
	elseif not items then
		-- Just update the index without modifying items
		selectedIndex = index
	end
end

-- Get the current visible range (useful for navigation)
function list.getVisibleRange()
	return currentVisibleRange
end

-- Handle screen entrance - centralizes list reset logic
-- Call this when entering a screen that uses a list
-- Parameters:
--   items: the list items to use
--   savedIndex: (optional) previously saved selection index to restore
function list.onScreenEnter(items, savedIndex)
	-- Reset list state
	list.resetScrollPosition()

	-- Restore selected index if provided
	if savedIndex and savedIndex > 0 and items and #items >= savedIndex then
		list.setSelectedIndex(savedIndex, items)
	else
		-- Otherwise select the first item
		list.setSelectedIndex(1, items)
	end

	return 0 -- Return initial scroll position
end

-- Handle screen exit - saves list state
-- Call this when exiting a screen that uses a list
-- Returns: the current selected index that can be stored and passed to onScreenEnter later
function list.onScreenExit()
	return list.getSelectedIndex()
end

return list
