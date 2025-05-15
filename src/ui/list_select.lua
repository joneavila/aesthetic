--- ListSelect UI component
-- This module provides a scrollable list with checkboxes and action buttons at the top

local love = require("love")
local button = require("ui.button")
local scrollView = require("ui.scroll_view")
local list = require("ui.list")
local svg = require("utils.svg")
local controls = require("controls")

local list_select = {}

-- Preload check icons
local SQUARE = svg.loadIcon("square", 24)
local SQUARE_CHECK_ICON = svg.loadIcon("square-check", 24)

-- Draw a scrollable list with checkboxes and action buttons
-- params: {
--   items = { { text = string, checked = bool, selected = bool } },
--   actions = { { text = string, selected = bool } },
--   startY = number,
--   itemHeight = number,
--   scrollPosition = number,
--   screenWidth = number,
--   screenHeight = number,
--   drawItemFunc = function(item, index, y),
--   drawActionFunc = function(action, index, y),
-- }
function list_select.draw(params)
	local items = params.items or {}
	local actions = params.actions or {}
	local startY = params.startY or 0
	local itemHeight = params.itemHeight or button.calculateHeight()
	local scrollPosition = params.scrollPosition or 0
	local screenWidth = params.screenWidth or love.graphics.getWidth()
	local screenHeight = params.screenHeight or love.graphics.getHeight()
	local scrollBarWidth = params.scrollBarWidth or 10
	local itemPadding = button.BUTTON.SPACING

	-- Reserve space for selection indicator and controls
	local font = love.graphics.getFont()
	local indicatorHeight = font:getHeight() + 24
	local controlsHeight = controls.HEIGHT or 42
	local reservedBottom = indicatorHeight + controlsHeight

	-- Draw action buttons at the top
	local actionHeight = itemHeight
	for i, action in ipairs(actions) do
		local y = startY + (i - 1) * (actionHeight + itemPadding)
		if params.drawActionFunc then
			params.drawActionFunc(action, i, y)
		else
			list_select.drawActionButton(action, y, screenWidth)
		end
	end

	local listStartY = startY + #actions * (actionHeight + itemPadding) + itemPadding

	-- Use list logic to calculate visibleCount, always reserving space for indicator and controls
	local contentAreaHeight = screenHeight - listStartY - reservedBottom
	local visibleCount = math.floor(contentAreaHeight / (itemHeight + itemPadding))

	-- Draw the list using scrollView
	scrollView.draw({
		contentCount = #items,
		visibleCount = visibleCount,
		scrollPosition = scrollPosition,
		startY = listStartY,
		contentHeight = itemHeight,
		contentPadding = itemPadding,
		screenWidth = screenWidth,
		contentDrawFunc = function()
			local visibleItemCount = 0
			for i, item in ipairs(items) do
				if i <= scrollPosition or i > scrollPosition + visibleCount then
					goto continue
				end
				visibleItemCount = visibleItemCount + 1
				local y = listStartY + (visibleItemCount - 1) * (itemHeight + itemPadding)
				if params.drawItemFunc then
					params.drawItemFunc(item, i, y)
				else
					list_select.drawCheckboxItem(item, y, screenWidth)
				end
				::continue::
			end
		end,
	})

	-- Draw selection indicator at the bottom if any items are selected
	if params.selectedCount and params.selectedCount > 0 then
		local text = tostring(params.selectedCount)
			.. " item"
			.. (params.selectedCount == 1 and "" or "s")
			.. " selected"
		love.graphics.setColor(require("colors").ui.foreground)
		love.graphics.setFont(font)
		local textWidth = font:getWidth(text)
		local x = (screenWidth - textWidth) / 2
		local y = screenHeight - controlsHeight - indicatorHeight + 12
		love.graphics.print(text, x, y)
	end

	return {
		visibleCount = visibleCount,
	}
end

-- Draw a single item with a checkbox
function list_select.drawCheckboxItem(item, y, screenWidth)
	local boxSize = 28
	local padding = button.BUTTON.HORIZONTAL_PADDING
	local font = love.graphics.getFont()
	local buttonHeight = button.calculateHeight()
	local boxX = button.BUTTON.EDGE_MARGIN + padding
	local boxY = y + (buttonHeight - boxSize) / 2
	local textX = boxX + boxSize + padding
	local textY = y + (buttonHeight - font:getHeight()) / 2

	-- Draw background if selected (hovered)
	if item.selected then
		love.graphics.setColor(require("colors").ui.surface)
		love.graphics.rectangle(
			"fill",
			button.BUTTON.EDGE_MARGIN,
			y,
			screenWidth - 2 * button.BUTTON.EDGE_MARGIN,
			buttonHeight,
			button.BUTTON.CORNER_RADIUS
		)
	end

	-- Draw checkbox icon
	if item.checked then
		if SQUARE_CHECK_ICON then
			local iconColor = item.selected and { 1, 1, 1, 1 } or require("colors").ui.accent
			svg.drawIcon(SQUARE_CHECK_ICON, boxX + boxSize / 2, boxY + boxSize / 2, iconColor)
		end
	else
		if SQUARE then
			local iconColor = item.selected and { 1, 1, 1, 1 } or { 0.7, 0.7, 0.7, 1 }
			svg.drawIcon(SQUARE, boxX + boxSize / 2, boxY + boxSize / 2, iconColor)
		end
	end

	-- Always draw text with ui.foreground color
	love.graphics.setColor(require("colors").ui.foreground)
	love.graphics.setFont(font)
	love.graphics.print(item.text, textX, textY)
end

-- Draw an action button (text only)
function list_select.drawActionButton(action, y, screenWidth)
	local font = love.graphics.getFont()
	local buttonHeight = button.calculateHeight()
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

-- Navigation helpers: reuse list.navigate and list.adjustScrollPosition
list_select.navigate = list.navigate
list_select.adjustScrollPosition = list.adjustScrollPosition
list_select.findSelectedIndex = list.findSelectedIndex

-- Helper: toggle checked state
function list_select.toggleChecked(items, index)
	if items[index] then
		items[index].checked = not items[index].checked
	end
end

return list_select
