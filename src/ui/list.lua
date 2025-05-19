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

	logger.debug(
		"list.adjustScrollPosition - selectedIndex: "
			.. currSelectedIndex
			.. ", visibleCount: "
			.. visibleCount
			.. ", totalCount: "
			.. totalCount
	)

	-- If the list has fewer items than visible capacity, show from the beginning
	if totalCount <= visibleCount then
		return 0
	end

	-- Calculate the maximum valid scroll position
	local maxScrollPosition = math.max(0, totalCount - visibleCount)

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

	-- Calculate the current visible range based on old scroll position
	local firstVisible = math.floor(oldScrollPosition) + 1
	local lastVisible = firstVisible + visibleCount - 1

	-- If the selected item is just one position below the last visible item,
	-- scroll by exactly one position to reveal it, ensuring smooth scrolling
	if currSelectedIndex == lastVisible + 1 then
		logger.debug("Scrolling one item down from: " .. oldScrollPosition .. " to " .. (oldScrollPosition + 1))
		return oldScrollPosition + 1
	end

	-- Middle of list: maintain selected item at bottom of visible area
	-- but ensure we're not jumping too far when scrolling down
	local newScrollPosition = currSelectedIndex - visibleCount + 1
	logger.debug("Middle of list, positioning item at bottom visible slot: " .. newScrollPosition)

	-- Ensure the new scroll position is within valid bounds
	newScrollPosition = math.max(0, math.min(newScrollPosition, maxScrollPosition))

	-- Prevent large jumps in scroll position when navigating down
	-- Allow at most one item of scrolling at a time
	if newScrollPosition > oldScrollPosition and newScrollPosition - oldScrollPosition > 1 then
		newScrollPosition = oldScrollPosition + 1
		logger.debug("Limited scroll jump to one item: " .. newScrollPosition)
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
	}

	-- Handle D-pad up/down navigation
	if virtualJoystick.isGamepadPressedWithDelay("dpup") then
		logger.debug("List handling dpup")
		local oldIndex = result.selectedIndex
		result.selectedIndex = list.navigate(items, -1)
		result.selectedIndexChanged = (oldIndex ~= result.selectedIndex)
		result.scrollPositionChanged = true
	elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
		logger.debug("List handling dpdown")
		local oldIndex = result.selectedIndex
		result.selectedIndex = list.navigate(items, 1)
		result.selectedIndexChanged = (oldIndex ~= result.selectedIndex)
		result.scrollPositionChanged = true
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

	-- Update scroll position if navigation occurred
	if result.scrollPositionChanged then
		-- Calculate the current visible range
		local firstVisible = math.floor(scrollPosition) + 1
		local lastVisible = firstVisible + visibleCount - 1

		logger.debug(
			"Before scroll adjustment - firstVisible: "
				.. firstVisible
				.. ", lastVisible: "
				.. lastVisible
				.. ", selectedIndex: "
				.. result.selectedIndex
		)

		-- Get the new scroll position
		local newScrollPosition = list.adjustScrollPosition({
			selectedIndex = result.selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleCount,
			totalCount = #items,
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

return list
