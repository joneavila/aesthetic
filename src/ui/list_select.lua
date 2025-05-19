--- ListSelect UI component
-- This module provides a scrollable list with checkboxes and action buttons

local love = require("love")
local button = require("ui.button")
local scrollable = require("ui.scrollable")
local list = require("ui.list")
local svg = require("utils.svg")
local controls = require("controls")
local colors = require("colors")

local list_select = {}

-- Preload check icons
local SQUARE = svg.loadIcon("square", 24)
local SQUARE_CHECK_ICON = svg.loadIcon("square-check", 24)

--------------------------------------------------
-- CORE DRAWING FUNCTIONS
--------------------------------------------------

-- Draw a scrollable list with checkboxes and action buttons
-- params: {
--   items = { { text = string, checked = bool, selected = bool } },
--   actions = { { text = string, selected = bool } },
--   startY = number,
--   itemHeight = number,
--   scrollPosition = number,
--   screenWidth = number,
--   screenHeight = number,
--   selectedCount = number,
--   drawItemFunc = function(item, index, y),
--   drawActionFunc = function(action, index, y),
-- }
function list_select.draw(params)
	local items = params.items or {}
	local actions = params.actions or {}
	local startY = params.startY or list.DEFAULT_CONFIG.startY
	local itemHeight = params.itemHeight
	local scrollPosition = params.scrollPosition or list.getScrollPosition()
	local screenWidth = params.screenWidth or love.graphics.getWidth()
	local screenHeight = params.screenHeight or love.graphics.getHeight()
	local itemPadding = params.itemPadding or list.DEFAULT_CONFIG.itemPadding

	-- Get the button height (whether default or custom)
	if itemHeight then
		button.setDefaultHeight(itemHeight)
	else
		itemHeight = button.getHeight()
	end

	-- Reserve space for selection indicator and controls
	local font = love.graphics.getFont()
	local indicatorHeight = font:getHeight() + 24
	local controlsHeight = controls.HEIGHT or 42
	local reservedBottom = indicatorHeight + controlsHeight

	-- Draw action buttons at the top
	local actionHeight = itemHeight
	local listStartY = startY

	if #actions > 0 then
		for i, action in ipairs(actions) do
			local y = startY + (i - 1) * (actionHeight + itemPadding)
			if params.drawActionFunc then
				params.drawActionFunc(action, i, y)
			else
				list_select.drawActionButton(action, y, screenWidth)
			end
		end

		-- Adjust the starting Y position for the main list after drawing actions
		listStartY = startY + #actions * (actionHeight + itemPadding) + itemPadding
	end

	-- Create list drawing params
	local listParams = {
		items = items,
		startY = listStartY,
		itemHeight = itemHeight,
		scrollPosition = scrollPosition,
		screenWidth = screenWidth,
		screenHeight = screenHeight,
		itemPadding = itemPadding,
		reservedBottom = reservedBottom,
		drawItemFunc = params.drawItemFunc or list_select.drawCheckboxItem,
	}

	-- Draw the list using the core list module
	local listResult = list.draw(listParams)

	-- Draw selection indicator at the bottom if any items are selected
	if params.selectedCount and params.selectedCount > 0 then
		local text = tostring(params.selectedCount)
			.. " item"
			.. (params.selectedCount == 1 and "" or "s")
			.. " selected"
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.setFont(font)
		local textWidth = font:getWidth(text)
		local x = (screenWidth - textWidth) / 2
		local y = screenHeight - controlsHeight - indicatorHeight + 12
		love.graphics.print(text, x, y)
	end

	return listResult
end

-- Draw a single item with a checkbox
function list_select.drawCheckboxItem(item, index, y, screenWidth, buttonWidth)
	local boxSize = 28
	local padding = button.BUTTON.HORIZONTAL_PADDING
	local font = love.graphics.getFont()
	local buttonHeight = button.getHeight()
	local boxX = button.BUTTON.EDGE_MARGIN + padding
	local boxY = y + (buttonHeight - boxSize) / 2
	local textX = boxX + boxSize + padding
	local textY = y + (buttonHeight - font:getHeight()) / 2

	-- Draw background if selected (hovered)
	if item.selected then
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle(
			"fill",
			button.BUTTON.EDGE_MARGIN,
			y,
			buttonWidth or (screenWidth - 2 * button.BUTTON.EDGE_MARGIN),
			buttonHeight,
			button.BUTTON.CORNER_RADIUS
		)
	end

	-- Draw checkbox icon
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

	-- Always draw text with ui.foreground color
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(font)
	love.graphics.print(item.text, textX, textY)
end

-- Draw an action button (text only)
function list_select.drawActionButton(action, y, screenWidth)
	local font = love.graphics.getFont()
	local buttonHeight = button.getHeight()
	local buttonWidth = screenWidth - 2 * button.BUTTON.EDGE_MARGIN
	local x = button.BUTTON.EDGE_MARGIN

	if action.selected then
		love.graphics.setColor(0.2, 0.6, 1, 1)
		love.graphics.rectangle("fill", x, y, buttonWidth, buttonHeight, button.BUTTON.CORNER_RADIUS)
		love.graphics.setColor(1, 1, 1, 1)
	else
		love.graphics.setColor(0.9, 0.9, 0.9, 1)
		love.graphics.rectangle("fill", x, y, buttonWidth, buttonHeight, button.BUTTON.CORNER_RADIUS)
		love.graphics.setColor(0.1, 0.1, 0.1, 1)
	end

	love.graphics.setFont(font)
	love.graphics.print(action.text, x + button.BUTTON.HORIZONTAL_PADDING, y + (buttonHeight - font:getHeight()) / 2)
end

--------------------------------------------------
-- NAVIGATION AND SELECTION
--------------------------------------------------

-- Find the selected index in a list of items
function list_select.findSelectedIndex(items)
	return list.getSelectedIndex()
end

-- Helper function to navigate between items
function list_select.navigate(items, direction)
	return list.navigate(items, direction)
end

-- Adjust scroll position to ensure the selected item is visible
function list_select.adjustScrollPosition(params)
	return list.adjustScrollPosition(params)
end

-- Helper: toggle checked state
function list_select.toggleChecked(items, index)
	list.toggleProperty(items, index, "checked")
end

-- NEW: Handle input for a list_select component
-- This provides consistent input handling for selection lists
function list_select.handleInput(params)
	local items = params.items or {}
	local actions = params.actions or {}
	local allItems = {}
	local scrollPosition = params.scrollPosition or list.getScrollPosition()
	local visibleCount = params.visibleCount or 0
	local onItemChecked = params.onItemChecked -- Callback when an item is checked/unchecked
	local onActionSelected = params.onActionSelected -- Callback when action button is selected

	-- Combine actions and items for navigation
	for _, action in ipairs(actions) do
		table.insert(allItems, action)
	end
	for _, item in ipairs(items) do
		table.insert(allItems, item)
	end

	-- Use the main list input handler
	local result = list.handleInput({
		items = allItems,
		scrollPosition = scrollPosition,
		visibleCount = visibleCount,
		virtualJoystick = params.virtualJoystick,

		-- Handle selection (A button press)
		handleItemSelect = function(item, index)
			-- Check if it's an action or a regular item
			if index <= #actions then
				-- It's an action button
				if onActionSelected then
					onActionSelected(item, index)
				end
			else
				-- It's a regular item - toggle checked state
				local itemIndex = index - #actions
				list_select.toggleChecked(items, itemIndex)

				if onItemChecked then
					onItemChecked(items[itemIndex], itemIndex)
				end
			end
		end,
	})

	return result
end

return list_select
