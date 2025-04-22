--- Scroll view component
--- This file defines a content area that is scrollable and draws the content with a scrollbar

local love = require("love")
local colors = require("colors")
local UI_CONSTANTS = require("ui.constants")

-- Module table to export public functions
local scrollView = {}

-- Function to draw a scroll view with content
function scrollView.draw(params)
	local contentCount = params.contentCount or 0
	local visibleCount = params.visibleCount or 0
	local scrollPosition = params.scrollPosition or 0
	local startY = params.startY or 0
	local contentHeight = params.contentHeight or 0
	local contentPadding = params.contentPadding or 0
	local screenWidth = params.screenWidth or love.graphics.getWidth()
	local contentDrawFunc = params.contentDrawFunc or function() end
	local scrollBarWidth = params.scrollBarWidth or UI_CONSTANTS.SCROLL_BAR_WIDTH

	-- Calculate visible area and scroll bar dimensions
	local needsScrollBar = contentCount > visibleCount

	-- Draw the content
	contentDrawFunc(needsScrollBar, scrollBarWidth)

	-- Draw scroll bar if needed
	if needsScrollBar then
		-- Calculate the visible area height
		local scrollAreaHeight = visibleCount * (contentHeight + contentPadding) - contentPadding

		-- Calculate scroll bar height and position
		local scrollBarHeight = (visibleCount / contentCount) * scrollAreaHeight

		-- Calculate maximum scroll position to keep handle in bounds
		local maxScrollY = scrollAreaHeight - scrollBarHeight
		local scrollPercentage = scrollPosition / (contentCount - visibleCount)
		local scrollBarY = startY + (scrollPercentage * maxScrollY)

		-- Ensure the scrollbar handle stays within the visible area
		scrollBarY = math.min(scrollBarY, startY + maxScrollY)

		-- Draw scroll bar background - position it flush with right edge
		love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 0.3)
		love.graphics.rectangle(
			"fill",
			screenWidth - scrollBarWidth,
			startY,
			scrollBarWidth,
			scrollAreaHeight,
			4 -- Add corner radius of 4px for the scrollbar background
		)

		-- Draw scroll bar handle - position it flush with right edge
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle(
			"fill",
			screenWidth - scrollBarWidth,
			scrollBarY,
			scrollBarWidth,
			scrollBarHeight,
			4 -- Add corner radius of 4px for the scrollbar handle
		)
	end

	return needsScrollBar
end

-- Function to calculate the adjusted scroll position based on selection
function scrollView.adjustScrollPosition(params)
	local selectedIndex = params.selectedIndex or 0
	local scrollPosition = params.scrollPosition or 0
	local visibleCount = params.visibleCount or 0

	-- Adjust scroll position if the selected item is outside the visible area
	if selectedIndex <= scrollPosition then
		return selectedIndex - 1
	elseif selectedIndex > scrollPosition + visibleCount then
		return selectedIndex - visibleCount
	end

	return scrollPosition
end

return scrollView
