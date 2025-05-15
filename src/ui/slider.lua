--- Slider UI component
local love = require("love")
local colors = require("colors")

-- Module table to export public functions
local slider = {}

-- Default slider constants
slider.HEIGHT = 30
slider.PADDING = 20
slider.TRACK_HEIGHT = 8
slider.HANDLE_WIDTH = 16 -- Fixed handle width
slider.HANDLE_HEIGHT = 36 -- Fixed handle height
slider.CORNER_RADIUS = 8 -- Rounded corners
slider.TICK_HEIGHT = 10
slider.TICK_WIDTH = 2
slider.LABEL_OFFSET_Y = 30 -- Distance from slider to label text

-- Draw a slider with the given parameters
-- @param x The x coordinate of the slider
-- @param y The y coordinate of the slider
-- @param width The width of the slider
-- @param values The array of values that the slider can snap to
-- @param currentIndex The index of the currently selected value
-- @param label (optional) A label to display above the slider
function slider.draw(x, y, width, values, currentIndex, label)
	if not values or #values == 0 then
		return
	end

	-- Ensure currentIndex is valid
	currentIndex = math.max(1, math.min(currentIndex, #values))

	-- Calculate track metrics
	local trackX = x + slider.PADDING
	local trackY = y + (slider.HEIGHT / 2) - (slider.TRACK_HEIGHT / 2)
	local trackWidth = width - (slider.PADDING * 2)

	-- Draw track background
	love.graphics.setColor(colors.ui.surface)
	love.graphics.rectangle("fill", trackX, trackY, trackWidth, slider.TRACK_HEIGHT, slider.TRACK_HEIGHT / 2)

	-- Draw tick marks for each value
	love.graphics.setColor(colors.ui.overlay)
	for i = 1, #values do
		local tickX = trackX + ((i - 1) / (#values - 1)) * trackWidth - (slider.TICK_WIDTH / 2)
		local tickY = trackY + slider.TRACK_HEIGHT + 2
		love.graphics.rectangle("fill", tickX, tickY, slider.TICK_WIDTH, slider.TICK_HEIGHT, 1)
	end

	-- Draw filled portion of track
	local percent = (currentIndex - 1) / (#values - 1)
	local fillWidth = trackWidth * percent
	love.graphics.setColor(colors.ui.accent)
	love.graphics.rectangle("fill", trackX, trackY, fillWidth, slider.TRACK_HEIGHT, slider.TRACK_HEIGHT / 2)

	-- Draw handle
	local handleX = trackX + fillWidth - (slider.HANDLE_WIDTH / 2)
	local handleY = y + (slider.HEIGHT / 2) - (slider.HANDLE_HEIGHT / 2)

	-- Draw handle shadow
	love.graphics.setColor(0, 0, 0, 0.3)
	love.graphics.rectangle(
		"fill",
		handleX + 1,
		handleY + 1,
		slider.HANDLE_WIDTH,
		slider.HANDLE_HEIGHT,
		slider.CORNER_RADIUS
	)

	-- Draw handle
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.rectangle("fill", handleX, handleY, slider.HANDLE_WIDTH, slider.HANDLE_HEIGHT, slider.CORNER_RADIUS)

	-- Draw label if provided
	if label then
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(label, x + slider.PADDING, y - slider.LABEL_OFFSET_Y)
	end

	-- Draw current value
	local currentValue = values[currentIndex]
	local valueText = tostring(currentValue)
	local font = love.graphics.getFont()
	local textWidth = font:getWidth(valueText)

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.print(valueText, x + width - slider.PADDING - textWidth, y - slider.LABEL_OFFSET_Y)
end

-- Helper function to get the next snapping value based on a relative position
function slider.getValueIndexFromPosition(x, width, values, padding)
	padding = padding or slider.PADDING

	-- Calculate track width
	local trackWidth = width - (padding * 2)

	-- Calculate relative position (0-1)
	local relativePos = math.max(0, math.min(1, (x - padding) / trackWidth))

	-- Find closest snap point
	local targetIndex = math.floor(relativePos * (#values - 1) + 0.5) + 1

	-- Ensure index is within valid range
	return math.max(1, math.min(#values, targetIndex))
end

-- Update slider value with left/right navigation
function slider.updateValue(currentIndex, direction, values)
	local newIndex = currentIndex + direction
	if newIndex < 1 then
		newIndex = 1
	elseif newIndex > #values then
		newIndex = #values
	end
	return newIndex
end

return slider
