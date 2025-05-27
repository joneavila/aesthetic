--- Slider UI component
local love = require("love")
local colors = require("colors")
local tween = require("tween") -- Add tween require

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

-- Create a state table for an animated slider
function slider.createAnimatedSliderState(initialIndex)
	local state = {
		animatedValue = initialIndex,
		currentTween = nil,
	}
	return state
end

-- Update the animation state
function slider.updateAnimatedSliderState(state, dt)
	if state.currentTween then
		local completed = state.currentTween:update(dt)
		if completed then
			state.currentTween = nil
		end
	end
end

-- Start an animation to a new target index
function slider.setAnimatedSliderValue(state, targetIndex, duration)
	-- Only animate if the target is different from the current animated value (approximately)
	-- This check prevents starting a new tween if the value is already close to the target
	-- Use state.animatedValue here as it reflects the current position.
	if math.abs(state.animatedValue - targetIndex) > 0.01 then
		-- Create tween from current animated value to the new target value
		-- The new tween will replace the old one if one exists.
		-- The tween will directly update state.animatedValue
		local newTween = tween.new(duration, state, { animatedValue = targetIndex }, "inOutQuad")
		if newTween then -- Ensure a valid tween object was created
			state.currentTween = newTween
		end
	end
end

-- Draw a slider with the given parameters
-- @param x The x coordinate of the slider
-- @param y The y coordinate of the slider
-- @param width The width of the slider
-- @param values The array of values that the slider can snap to
-- @param animatedIndex The current interpolated index for drawing the handle
-- @param currentIndex The actual current index for displaying the value text
-- @param label (optional) A label to display above the slider
function slider.draw(x, y, width, values, animatedIndex, currentIndex, label)
	if not values or #values == 0 then
		return
	end

	-- Ensure indices are valid for accessing values array
	-- animatedIndex is already the interpolated value from the tween
	local clampedAnimatedIndex = math.max(1, math.min(animatedIndex, #values))
	local clampedCurrentIndex = math.max(1, math.min(currentIndex, #values))

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

	-- Draw filled portion of track based on animated index
	local rawPercent = (animatedIndex - 1) / math.max(1, #values - 1) -- Calculate percent first
	local percent = math.max(0, math.min(1, rawPercent)) -- Clamp the percentage
	local fillWidth = trackWidth * percent
	love.graphics.setColor(colors.ui.accent)
	love.graphics.rectangle("fill", trackX, trackY, fillWidth, slider.TRACK_HEIGHT, slider.TRACK_HEIGHT / 2)

	-- Draw handle based on animated index
	local handlePercent = (animatedIndex - 1) / math.max(1, #values - 1) -- Use raw percent for handle position
	local clampedHandlePercent = math.max(0, math.min(1, handlePercent))
	local handleX = trackX + trackWidth * clampedHandlePercent - (slider.HANDLE_WIDTH / 2)
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
		love.graphics.print(label, x + slider.PADDING, y - slider.LABEL_OFFSET_Y) -- Assuming font is already set
	end

	-- Draw current value (use the actual current index)
	local currentValue = values[clampedCurrentIndex]
	local valueText = tostring(currentValue)
	local font = love.graphics.getFont() -- Get current font
	local textWidth = font:getWidth(valueText)

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.print(valueText, x + width - slider.PADDING - textWidth, y - slider.LABEL_OFFSET_Y) -- Assuming font is already set
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
