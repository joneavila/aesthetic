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

-- Store state for each screen to remember position between screen transitions
local screenStates = {}

-- The current active screen ID
local currentScreenId = nil

-- Set the current active screen ID
local function setCurrentScreen(screenId)
	if not screenId then
		return
	end

	-- Convert screenId to string to ensure it can be used as a table key
	local screenIdKey = tostring(screenId)
	currentScreenId = screenIdKey

	-- Initialize screen state if it doesn't exist
	if not screenStates[screenIdKey] then
		screenStates[screenIdKey] = {
			scrollPosition = 0,
			selectedIndex = 1,
			selectedItem = nil,
			visibleRange = { first = 1, last = 1 },
		}
	end
end

-- Get the current screen state
local function getCurrentState()
	if not currentScreenId then
		-- Return a default state if no screen is set
		return {
			scrollPosition = 0,
			selectedIndex = 1,
			selectedItem = nil,
			visibleRange = { first = 1, last = 1 },
		}
	end

	return screenStates[currentScreenId]
end

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
	local screenWidth = params.screenWidth or love.graphics.getWidth()
	local screenHeight = params.screenHeight or love.graphics.getHeight()
	local itemCount = #items
	local itemPadding = params.itemPadding or list.DEFAULT_CONFIG.itemPadding
	local drawItemFunc = params.drawItemFunc

	-- Get current screen state
	local state = getCurrentState()

	-- Use provided scroll position or the saved one
	local scrollPosition = params.scrollPosition or state.scrollPosition

	-- Check if drawItemFunc is provided
	if not drawItemFunc then
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

	-- Save the current scroll position to screen state
	state.scrollPosition = scrollPosition

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
	state.visibleRange = {
		first = firstVisibleItem,
		last = lastVisibleItem,
	}

	-- Calculate the end Y position of the list
	local endY = startY + viewportHeight

	return {
		needsScrollBar = needsScrollBar,
		visibleCount = visibleCount,
		firstVisibleItem = firstVisibleItem,
		lastVisibleItem = lastVisibleItem,
		availableWidth = availableWidth,
		totalCount = itemCount,
		endY = endY,
	}
end

-- Adjust the scroll position to ensure the selected item is visible
-- Uses fixed positioning to maintain the selected item at a consistent position
function list.adjustScrollPosition(params)
	-- Get current screen state
	local state = getCurrentState()

	local currSelectedIndex = params.selectedIndex > 0 and params.selectedIndex or state.selectedIndex
	local items = params.items or {}
	local totalCount = params.totalCount or #items
	local visibleCount = params.visibleCount or 0
	local oldScrollPosition = params.scrollPosition or state.scrollPosition
	local direction = params.direction or 0 -- -1 for up, 1 for down, 0 for unknown

	-- If the list has fewer items than visible capacity, show from the beginning
	if totalCount <= visibleCount then
		return 0
	end

	-- When wrapping from last to first item, reset scroll position to 0
	if direction == 1 and currSelectedIndex == 1 and oldScrollPosition > 0 then
		return 0
	end

	-- Calculate the maximum valid scroll position
	local maxScrollPosition = math.max(0, totalCount - visibleCount)

	-- Calculate the current first visible item
	local firstVisible = math.floor(oldScrollPosition) + 1

	-- Special case for navigating up: if we're going from the first visible item to the
	-- item just above it, we want to scroll exactly one item up
	if direction == -1 and currSelectedIndex == firstVisible - 1 then
		return math.max(0, oldScrollPosition - 1)
	end

	-- Early in the list: fixed positioning until we need to scroll
	if currSelectedIndex <= visibleCount then
		return 0
	end

	-- Near end of list: ensure we always show exactly visibleCount items
	-- This condition ensures we switch to end-of-list mode when the selected item
	-- would be in the last visible set of items
	if currSelectedIndex > totalCount - visibleCount and currSelectedIndex == totalCount then
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

	-- Ensure the new scroll position is within valid bounds and prevent excessive jumps
	newScrollPosition = math.max(0, math.min(newScrollPosition, maxScrollPosition))

	-- Limit jump distance to at most one item when navigating down
	if newScrollPosition > oldScrollPosition and newScrollPosition - oldScrollPosition > 1 then
		newScrollPosition = oldScrollPosition + 1
	end

	-- Limit jump distance to at most one item when navigating up
	if newScrollPosition < oldScrollPosition and oldScrollPosition - newScrollPosition > 1 then
		newScrollPosition = oldScrollPosition - 1
	end

	-- Store the last selected index when explicit selectedIndex is provided
	if params.selectedIndex > 0 then
		state.selectedIndex = params.selectedIndex
	end

	return math.floor(newScrollPosition)
end

-- Helper function to navigate between items
function list.navigate(items, direction)
	-- Get current screen state
	local state = getCurrentState()

	-- Calculate new index
	local newIndex = state.selectedIndex + direction

	-- Wrap around if needed
	if newIndex < 1 then
		newIndex = #items
	elseif newIndex > #items then
		newIndex = 1
	end

	-- Update selection state for all items
	for i, item in ipairs(items) do
		item.selected = (i == newIndex)

		-- Store reference to the selected item
		if item.selected then
			state.selectedItem = item
		end
	end

	-- Update the selected index in the screen state
	state.selectedIndex = newIndex

	-- Update the current visible range to reflect the new selection
	-- This helps ensure that subsequent navigation will be based on correct values
	-- First estimate what the visible range should be after this navigation
	if direction > 0 and state.visibleRange.last < newIndex then
		-- Moving down past the last visible item
		state.visibleRange.first = state.visibleRange.first + 1
		state.visibleRange.last = newIndex
	elseif direction < 0 and state.visibleRange.first > newIndex then
		-- Moving up past the first visible item
		state.visibleRange.first = newIndex
		state.visibleRange.last = state.visibleRange.last - 1
	end

	return newIndex
end

-- Helper: toggle a boolean property on an item
function list.toggleProperty(items, index, property)
	if items[index] and property then
		items[index][property] = not items[index][property]
	end
end

-- Enhanced handle input function that combines navigation, selection and option cycling
function list.handleInput(params)
	local items = params.items or {}
	local virtualJoystick = params.virtualJoystick or require("input").virtualJoystick
	local handleItemSelect = params.handleItemSelect -- Callback for A button
	local handleItemOption = params.handleItemOption -- Callback for left/right

	-- Get current screen state
	local state = getCurrentState()

	-- Use provided scroll position or the saved one
	local scrollPosition = params.scrollPosition or state.scrollPosition
	local visibleCount = params.visibleCount or 0

	-- Ensure scroll position is an integer
	scrollPosition = math.floor(scrollPosition)

	local result = {
		scrollPositionChanged = false,
		selectedIndexChanged = false,
		optionChanged = false,
		scrollPosition = scrollPosition,
		selectedIndex = state.selectedIndex,
		direction = 0, -- Track navigation direction
	}

	-- Calculate current visible item range
	local firstVisible = math.floor(scrollPosition) + 1
	local lastVisible = firstVisible + visibleCount - 1

	-- Check if the currently selected item is not visible and force scroll update if needed
	local currentVisible = (state.selectedIndex >= firstVisible and state.selectedIndex <= lastVisible)
	if not currentVisible then
		result.scrollPositionChanged = true
		result.direction = (state.selectedIndex < firstVisible) and -1 or 1
	end

	-- Handle D-pad up/down navigation
	if virtualJoystick.isGamepadPressedWithDelay("dpup") then
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
		end
	elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
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
		end
	end

	-- Handle left/right for option cycling
	local pressedLeft = virtualJoystick.isGamepadPressedWithDelay("dpleft")
	local pressedRight = virtualJoystick.isGamepadPressedWithDelay("dpright")

	if (pressedLeft or pressedRight) and handleItemOption and state.selectedItem then
		local direction = pressedLeft and -1 or 1
		local changed = handleItemOption(state.selectedItem, direction)
		result.optionChanged = changed or false
	end

	-- Handle A button for selection
	if virtualJoystick.isGamepadPressedWithDelay("a") and handleItemSelect and state.selectedItem then
		handleItemSelect(state.selectedItem, state.selectedIndex)
	end

	-- Update scroll position if navigation occurred and selection is outside visible range
	-- or if we detected that the selected item is not visible
	if result.scrollPositionChanged then
		-- Get the new scroll position - pass total item count to ensure proper calculation
		local newScrollPosition = list.adjustScrollPosition({
			selectedIndex = result.selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleCount,
			totalCount = #items,
			items = items, -- Pass items to ensure proper count
			direction = result.direction, -- Pass the direction
		})

		-- Ensure the new scroll position is an integer
		newScrollPosition = math.floor(newScrollPosition)

		-- Update result with the new scroll position
		result.scrollPosition = newScrollPosition

		-- Update the state
		state.scrollPosition = newScrollPosition
	end

	-- Even if no navigation occurred, make sure to save the current scroll position
	-- This ensures it's remembered between screen transitions
	if not result.scrollPositionChanged then
		state.scrollPosition = scrollPosition
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

-- Reset the stored scroll position for the current screen
function list.resetScrollPosition()
	local state = getCurrentState()
	state.scrollPosition = 0
	state.selectedIndex = 1
	state.selectedItem = nil
	state.visibleRange = { first = 1, last = 1 }
end

-- Get the current scroll position for the current screen
function list.getScrollPosition()
	return getCurrentState().scrollPosition
end

-- Get the selected index for the current screen
function list.getSelectedIndex()
	return getCurrentState().selectedIndex
end

-- Get the selected item for the current screen
function list.getSelectedItem()
	return getCurrentState().selectedItem
end

-- Set the scroll position to a specific value for the current screen
function list.setScrollPosition(pos)
	getCurrentState().scrollPosition = pos or 0
end

-- Set the selected index to a specific value for the current screen
function list.setSelectedIndex(index, items)
	local state = getCurrentState()

	if items and index >= 1 and index <= #items then
		-- Update previous selections
		for i, item in ipairs(items) do
			item.selected = (i == index)
			if item.selected then
				state.selectedItem = item
			end
		end
		state.selectedIndex = index
	elseif not items then
		-- Just update the index without modifying items
		state.selectedIndex = index
	end
end

-- Get the current visible range for the current screen
function list.getVisibleRange()
	return getCurrentState().visibleRange
end

-- Handle screen entrance - centralizes list reset logic
-- Call this when entering a screen that uses a list
-- Parameters:
--   screenId: unique identifier for the screen
--   items: the list items to use
--   savedIndex: (optional) previously saved selection index to restore
function list.onScreenEnter(screenId, items, savedIndex)
	-- Set the current screen to ensure state is associated with it
	setCurrentScreen(screenId)

	local state = getCurrentState()
	local itemCount = #items

	-- Restore selected index if provided, otherwise use the saved one
	local indexToUse = savedIndex or state.selectedIndex

	-- Ensure index is valid
	if indexToUse < 1 or indexToUse > itemCount then
		indexToUse = 1
	end

	-- Set the selected index in items
	list.setSelectedIndex(indexToUse, items)

	-- Always ensure the selected item will be visible
	-- Calculate a reasonable estimate for visible count if not known yet
	local visibleCount = math.min(itemCount, 10)

	-- First visible item should be at most the selected index - 1
	-- This places the selected item as the second item when possible
	local targetScrollPosition = math.max(0, indexToUse - 2)

	-- But don't scroll past the end
	local maxScrollPosition = math.max(0, itemCount - visibleCount)
	targetScrollPosition = math.min(targetScrollPosition, maxScrollPosition)

	-- Update the state
	state.scrollPosition = targetScrollPosition

	return targetScrollPosition
end

-- Handle screen exit - saves list state
-- Call this when exiting a screen that uses a list
function list.onScreenExit()
	-- No need to do anything special on exit with per-screen state
	-- State is already saved in the screenStates table
	return getCurrentState().selectedIndex
end

return list
