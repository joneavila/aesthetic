--- Scrollable component
--- Provides core scrolling functionality for all UI components that need scrolling

local love = require("love")
local colors = require("colors")
local constants = require("ui.components.constants")

-- Module table to export public functions
local scrollable = {}

-- Constants
local DEFAULT_SCROLL_STEP = 20

--------------------------------------------------
-- COMMON SCROLLING FUNCTIONS
--------------------------------------------------

-- Calculate if content needs scrolling and related metrics
function scrollable.calculateMetrics(params)
	local contentSize = params.contentSize or 0 -- Total size of scrollable content
	local viewportSize = params.viewportSize or 0 -- Visible area size
	local scrollPosition = params.scrollPosition or 0 -- Current scroll position

	-- Calculate if scrolling is needed
	local needsScrollBar = contentSize > viewportSize

	-- Calculate scrollbar dimensions
	local scrollBarSize = 0
	local scrollBarPosition = 0

	if needsScrollBar then
		-- Calculate scrollbar size proportional to visible content
		scrollBarSize = (viewportSize / contentSize) * viewportSize

		-- Calculate scrollbar position based on scroll position
		local maxScrollPosition = contentSize - viewportSize
		if maxScrollPosition > 0 then
			local scrollPercentage = scrollPosition / maxScrollPosition
			scrollBarPosition = scrollPercentage * (viewportSize - scrollBarSize)
		end
	end

	return {
		needsScrollBar = needsScrollBar,
		scrollBarSize = scrollBarSize,
		scrollBarPosition = scrollBarPosition,
		maxScrollPosition = contentSize > viewportSize and contentSize - viewportSize or 0,
	}
end

-- Draw a scrollbar
function scrollable.drawScrollbar(params)
	local x = params.x or 0
	local y = params.y or 0
	local width = params.width or constants.SCROLLBAR.WIDTH
	local height = params.height or 100
	local position = params.position or 0
	local size = params.size or 50
	local opacity = params.opacity or 1

	-- Draw scrollbar handle
	love.graphics.setColor(
		constants.SCROLLBAR.HANDLE_COLOR[1],
		constants.SCROLLBAR.HANDLE_COLOR[2],
		constants.SCROLLBAR.HANDLE_COLOR[3],
		(constants.SCROLLBAR.HANDLE_COLOR[4] or 1) * opacity
	)
	love.graphics.rectangle("fill", x, y + position, width, size, constants.SCROLLBAR.CORNER_RADIUS)
end

-- Handle scrolling input
function scrollable.handleInput(params)
	local scrollPosition = params.scrollPosition or 0
	local contentSize = params.contentSize or 0
	local viewportSize = params.viewportSize or 0
	local scrollStep = params.scrollStep or DEFAULT_SCROLL_STEP
	local input = params.input or { up = false, down = false }

	local maxScrollVal = math.max(0, contentSize - viewportSize)

	-- Adjust scroll position based on input
	if input.up then
		scrollPosition = math.max(0, scrollPosition - scrollStep)
	elseif input.down then
		scrollPosition = math.min(maxScrollVal, scrollPosition + scrollStep)
	end

	-- Ensure scroll position is within valid range
	scrollPosition = math.max(0, math.min(scrollPosition, maxScrollVal))

	return scrollPosition
end

-- Draw content with pixel-based scrolling
function scrollable.drawContent(params)
	local x = params.x or 0
	local y = params.y or 0
	local width = params.width or love.graphics.getWidth()
	local height = params.height or love.graphics.getHeight()
	local scrollPosition = params.scrollPosition or 0
	local drawContent = params.drawContent or function() end
	local drawScrollbar = params.drawScrollbar ~= false
	local contentSize = params.contentSize or 0
	local opacity = params.opacity or 1

	-- Set scissor to clip content to viewport
	love.graphics.push("all")
	love.graphics.setScissor(x, y, width, height)

	-- Adjust drawing position based on scroll
	love.graphics.translate(0, -scrollPosition)

	-- Draw the actual content
	drawContent()

	-- Reset scissor
	love.graphics.setScissor()
	love.graphics.pop()

	-- Calculate scrollbar metrics
	local metrics = scrollable.calculateMetrics({
		contentSize = contentSize,
		viewportSize = height,
		scrollPosition = scrollPosition,
	})

	-- Draw scrollbar if needed and requested
	if metrics.needsScrollBar and drawScrollbar then
		scrollable.drawScrollbar({
			x = width - constants.SCROLLBAR.WIDTH,
			y = y,
			width = constants.SCROLLBAR.WIDTH,
			height = height,
			position = metrics.scrollBarPosition,
			size = metrics.scrollBarSize,
			opacity = opacity,
		})
	end

	return {
		needsScrollBar = metrics.needsScrollBar,
		scrollBarSize = metrics.scrollBarSize,
		scrollBarPosition = metrics.scrollBarPosition,
		maxScrollPosition = metrics.maxScrollPosition,
		contentWidth = width
			- (metrics.needsScrollBar and (constants.SCROLLBAR.WIDTH + constants.SCROLLBAR.PADDING) or 0),
	}
end

-- Adjust scroll position to ensure content at specified position is visible
function scrollable.adjustScrollPosition(params)
	local itemIndex = params.itemIndex or 0
	local scrollPosition = params.scrollPosition or 0
	local viewportSize = params.viewportSize or 0
	local itemSize = params.itemSize or 0
	local itemSpacing = params.itemSpacing or 0

	-- Calculate item positions
	local itemPosition = (itemIndex - 1) * (itemSize + itemSpacing)
	local itemEndPosition = itemPosition + itemSize

	-- Adjust scroll if item is before visible area
	if itemPosition < scrollPosition then
		return itemPosition
	end

	-- Adjust scroll if item is after visible area
	if itemEndPosition > scrollPosition + viewportSize then
		return itemEndPosition - viewportSize
	end

	-- Item is already visible, no change needed
	return scrollPosition
end

return scrollable
