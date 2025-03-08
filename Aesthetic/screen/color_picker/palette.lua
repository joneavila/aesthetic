--- Color picker palette screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local menuScreen = require("screen.menu")
local tween = require("tween")
local controls = require("controls")

local colorpicker = {}

local switchScreen = nil
local MENU_SCREEN = "menu"

-- Constants
local PADDING = 20
local SQUARE_SPACING = 20

-- Scrollbar constants
local SCROLLBAR = {
	WIDTH = 8,
	PADDING = 10,
	CORNER_RADIUS = 4,
	OPACITY = 0.7,
	HANDLE_MIN_HEIGHT = 30,
}

-- Border constants
local BORDER = {
	NORMAL_WIDTH = 1,
	SELECTED_WIDTH = 3,
	CORNER_RADIUS = 10,
}

-- Animation constants
local ANIMATION = {
	SCALE = 1.3,
	DURATION = 0.2,
}

-- Helper function to get all color keys
local function getColorKeys()
	-- Use the ordered keys directly from the colors module
	local keys = {}
	for _, key in ipairs(colors._ordered_keys) do
		table.insert(keys, key)
	end
	return keys
end

-- Helper function to calculate grid dimensions
local function calculateGridSize()
	local totalColors = #getColorKeys()
	local cols = 8
	local rows = math.ceil(totalColors / cols)
	return {
		cols = cols,
		rows = rows,
	}
end

-- Helper function to convert grid position to linear index
local function gridPosToIndex(row, col, grid)
	return row * grid.cols + col + 1
end

-- Helper function to check if a grid position has a color
local function hasColorAt(row, col, grid, totalColors)
	-- Check if it's a regular color position
	local index = gridPosToIndex(row, col, grid)
	return index <= totalColors
end

-- Helper function to calculate grid dimensions and layout
local function calculateGridDimensions()
	-- Get updated color keys and grid size
	local colorKeys = getColorKeys()
	local gridSize = calculateGridSize()

	-- Calculate available space
	local availableHeight = state.screenHeight - state.CONTROLS_HEIGHT - state.TAB_HEIGHT - (PADDING * 2)
	local availableWidth = state.screenWidth - (PADDING * 2) - SCROLLBAR.WIDTH - SCROLLBAR.PADDING

	-- Calculate square size based on available width and fixed number of columns
	local squareSize = math.floor((availableWidth - (SQUARE_SPACING * (gridSize.cols - 1))) / gridSize.cols)

	-- Calculate how many rows can be displayed at once
	local visibleRows = math.floor((availableHeight - squareSize) / (squareSize + SQUARE_SPACING)) + 1

	-- Calculate total grid dimensions
	local totalWidth = (gridSize.cols * squareSize) + (gridSize.cols - 1) * SQUARE_SPACING
	local totalGridHeight = (gridSize.rows * squareSize) + (gridSize.rows - 1) * SQUARE_SPACING
	local visibleGridHeight = (visibleRows * squareSize) + (visibleRows - 1) * SQUARE_SPACING

	-- Calculate grid position
	local offsetX = math.floor((state.screenWidth - totalWidth - SCROLLBAR.WIDTH - SCROLLBAR.PADDING) / 2)
	local offsetY = math.floor(state.TAB_HEIGHT + PADDING)

	return {
		colorKeys = colorKeys,
		gridSize = gridSize,
		squareSize = squareSize,
		visibleRows = visibleRows,
		totalGridHeight = totalGridHeight,
		visibleGridHeight = visibleGridHeight,
		offsetX = offsetX,
		offsetY = offsetY,
	}
end

local colorpickerState = {
	colorKeys = getColorKeys(),
	gridSize = nil,
	squareSize = 0,
	selectedRow = 0,
	selectedCol = 0,
	currentScale = 1,
	scaleTween = nil,
	offsetX = 0,
	offsetY = 0,
	scrollY = 0,
	visibleRows = 0,
	totalGridHeight = 0,
	visibleGridHeight = 0,
}

function colorpicker.load()
	-- Calculate grid dimensions and update state
	local dimensions = calculateGridDimensions()

	-- Update state with calculated dimensions
	colorpickerState.colorKeys = dimensions.colorKeys
	colorpickerState.gridSize = dimensions.gridSize
	colorpickerState.squareSize = dimensions.squareSize
	colorpickerState.visibleRows = dimensions.visibleRows
	colorpickerState.totalGridHeight = dimensions.totalGridHeight
	colorpickerState.visibleGridHeight = dimensions.visibleGridHeight
	colorpickerState.offsetX = dimensions.offsetX
	colorpickerState.offsetY = dimensions.offsetY

	-- Only reset scroll position if it hasn't been set before
	if colorpickerState.scrollY == nil then
		colorpickerState.scrollY = 0
	end
end

-- Helper function to draw the scrollbar
local function drawScrollbar()
	-- Calculate scrollbar position and dimensions
	local scrollbarHeight = state.screenHeight - state.CONTROLS_HEIGHT - state.TAB_HEIGHT - (PADDING * 2)
	local scrollbarX = state.screenWidth - SCROLLBAR.WIDTH - SCROLLBAR.PADDING
	local scrollbarY = state.TAB_HEIGHT + PADDING

	-- Draw scrollbar background
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 0.2)
	love.graphics.rectangle("fill", scrollbarX, scrollbarY, SCROLLBAR.WIDTH, scrollbarHeight, SCROLLBAR.CORNER_RADIUS)

	-- Calculate handle position and size
	local contentRatio = colorpickerState.visibleGridHeight / colorpickerState.totalGridHeight
	local handleHeight = math.max(SCROLLBAR.HANDLE_MIN_HEIGHT, scrollbarHeight * contentRatio)

	-- Calculate handle position based on scroll position
	local scrollRatio = 0
	if colorpickerState.totalGridHeight > colorpickerState.visibleGridHeight then
		scrollRatio = colorpickerState.scrollY / (colorpickerState.totalGridHeight - colorpickerState.visibleGridHeight)
	end

	local handleY = scrollbarY + (scrollbarHeight - handleHeight) * scrollRatio

	-- Draw handle
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], SCROLLBAR.OPACITY)
	love.graphics.rectangle("fill", scrollbarX, handleY, SCROLLBAR.WIDTH, handleHeight, SCROLLBAR.CORNER_RADIUS)
end

-- Helper function to draw the controls background
local function drawControlsBackground()
	love.graphics.setColor(colors.bg)
	love.graphics.rectangle(
		"fill",
		0,
		state.screenHeight - state.CONTROLS_HEIGHT,
		state.screenWidth,
		state.CONTROLS_HEIGHT
	)
end

function colorpicker.draw()
	-- Set background
	love.graphics.setColor(colors.bg)
	love.graphics.clear()

	-- Calculate the first visible row based on scroll position
	local firstVisibleRow = math.floor(colorpickerState.scrollY / (colorpickerState.squareSize + SQUARE_SPACING))

	-- Calculate the last visible row
	local lastVisibleRow = math.min(firstVisibleRow + colorpickerState.visibleRows, colorpickerState.gridSize.rows - 1)

	-- Calculate the offset for smooth scrolling
	local scrollOffset = colorpickerState.scrollY % (colorpickerState.squareSize + SQUARE_SPACING)

	-- Draw color grid (only visible rows)
	for row = firstVisibleRow, lastVisibleRow do
		for col = 0, colorpickerState.gridSize.cols - 1 do
			local colorIndex = gridPosToIndex(row, col, colorpickerState.gridSize)

			-- Only draw if there is a color for this position
			if colorIndex <= #colorpickerState.colorKeys then
				local x = colorpickerState.offsetX + col * (colorpickerState.squareSize + SQUARE_SPACING)
				local y = colorpickerState.offsetY
					+ (row - firstVisibleRow) * (colorpickerState.squareSize + SQUARE_SPACING)
					- scrollOffset

				-- Calculate scale and offset for the selected square
				local scale = 1
				local offset = 0
				if row == colorpickerState.selectedRow and col == colorpickerState.selectedCol then
					scale = colorpickerState.currentScale
					offset = (colorpickerState.squareSize * (scale - 1)) / 2
				end

				-- Draw the color square with scale
				local currentColor = colorpickerState.colorKeys[colorIndex]
				love.graphics.setColor(colors[currentColor])
				love.graphics.rectangle(
					"fill",
					x - offset,
					y - offset,
					colorpickerState.squareSize * scale,
					colorpickerState.squareSize * scale,
					BORDER.CORNER_RADIUS
				)

				-- Draw border
				love.graphics.setColor(colors.white)
				if row == colorpickerState.selectedRow and col == colorpickerState.selectedCol then
					love.graphics.setLineWidth(BORDER.SELECTED_WIDTH)
				else
					love.graphics.setLineWidth(BORDER.NORMAL_WIDTH)
				end
				love.graphics.rectangle(
					"line",
					x - offset,
					y - offset,
					colorpickerState.squareSize * scale,
					colorpickerState.squareSize * scale,
					BORDER.CORNER_RADIUS
				)
			end
		end
	end

	drawScrollbar()

	-- Draw controls
	drawControlsBackground()
	controls.draw({
		{
			icon = "l1.png",
			text = "Prev. Tab",
		},
		{
			icon = "r1.png",
			text = "Next Tab",
		},
		{
			icon = "d_pad.png",
			text = "Navigate",
		},
		{
			icon = "a.png",
			text = "Confirm",
		},
		{
			icon = "b.png",
			text = "Back",
		},
	})
end

function colorpicker.update(dt)
	-- Update tween if it exists
	if colorpickerState.scaleTween then
		local complete = colorpickerState.scaleTween:update(dt)
		if complete then
			colorpickerState.scaleTween = nil
		end
	end

	if state.canProcessInput() then
		local virtualJoystick = require("input").virtualJoystick
		local moved = false
		local newRow, newCol = colorpickerState.selectedRow, colorpickerState.selectedCol

		-- Handle directional input
		if virtualJoystick:isGamepadDown("dpup") then
			if colorpickerState.selectedRow > 0 then
				newRow = colorpickerState.selectedRow - 1
			end
		elseif virtualJoystick:isGamepadDown("dpdown") then
			if colorpickerState.selectedRow < colorpickerState.gridSize.rows - 1 then
				newRow = colorpickerState.selectedRow + 1
			end
		elseif virtualJoystick:isGamepadDown("dpleft") then
			if colorpickerState.selectedCol > 0 then
				newCol = colorpickerState.selectedCol - 1
			end
		elseif virtualJoystick:isGamepadDown("dpright") then
			if colorpickerState.selectedCol < colorpickerState.gridSize.cols - 1 then
				newCol = colorpickerState.selectedCol + 1
			end
		end

		-- Only move if the new position has a color
		if hasColorAt(newRow, newCol, colorpickerState.gridSize, #colorpickerState.colorKeys) then
			if newRow ~= colorpickerState.selectedRow or newCol ~= colorpickerState.selectedCol then
				colorpickerState.selectedRow = newRow
				colorpickerState.selectedCol = newCol
				moved = true

				-- Start new hover animation
				colorpickerState.currentScale = 1
				colorpickerState.scaleTween = tween.new(ANIMATION.DURATION, colorpickerState, {
					currentScale = ANIMATION.SCALE,
				}, "outQuad")

				-- Handle scrolling when selection moves out of view
				local rowPosition = colorpickerState.selectedRow * (colorpickerState.squareSize + SQUARE_SPACING)

				-- Calculate the visible area boundaries
				local visibleTop = colorpickerState.scrollY
				local visibleBottom = visibleTop + colorpickerState.visibleGridHeight - colorpickerState.squareSize

				-- Scroll up if selection is above visible area
				if rowPosition < visibleTop then
					colorpickerState.scrollY = rowPosition
				end

				-- Scroll down if selection is below visible area
				if rowPosition > visibleBottom then
					colorpickerState.scrollY = rowPosition
						- colorpickerState.visibleGridHeight
						+ colorpickerState.squareSize
						+ SQUARE_SPACING
				end

				-- Ensure scroll position doesn't go out of bounds
				colorpickerState.scrollY = math.max(
					0,
					math.min(
						colorpickerState.scrollY,
						colorpickerState.totalGridHeight - colorpickerState.visibleGridHeight
					)
				)
			end
		end

		-- Reset timer if moved
		if moved then
			state.resetInputTimer()
		end

		-- Handle select
		if virtualJoystick:isGamepadDown("a") then
			-- Regular color selected
			local selectedIndex =
				gridPosToIndex(colorpickerState.selectedRow, colorpickerState.selectedCol, colorpickerState.gridSize)
			local selectedKey = colorpickerState.colorKeys[selectedIndex]
			if selectedKey then
				menuScreen.setSelectedColor(state.lastSelectedColorButton, selectedKey)
				if switchScreen then
					switchScreen(MENU_SCREEN)
					state.resetInputTimer()
				end
			end
		end
	end
end

function colorpicker.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- Function called when entering this screen
function colorpicker.onEnter()
	-- Calculate grid dimensions and update state
	local dimensions = calculateGridDimensions()

	-- Update state with calculated dimensions
	colorpickerState.colorKeys = dimensions.colorKeys
	colorpickerState.gridSize = dimensions.gridSize
	colorpickerState.squareSize = dimensions.squareSize
	colorpickerState.visibleRows = dimensions.visibleRows
	colorpickerState.totalGridHeight = dimensions.totalGridHeight
	colorpickerState.visibleGridHeight = dimensions.visibleGridHeight
	colorpickerState.offsetX = dimensions.offsetX
	colorpickerState.offsetY = dimensions.offsetY

	-- Only reset selection and scroll position if they haven't been set before
	-- This allows the screen to remember its position when returning to it
	if colorpickerState.selectedRow == nil or colorpickerState.selectedCol == nil then
		colorpickerState.selectedRow = 0
		colorpickerState.selectedCol = 0
		colorpickerState.scrollY = 0
	else
		-- Validate that the selected position is still valid after grid size changes
		-- and adjust if necessary
		if colorpickerState.selectedRow >= colorpickerState.gridSize.rows then
			colorpickerState.selectedRow = colorpickerState.gridSize.rows - 1
		end

		if colorpickerState.selectedCol >= colorpickerState.gridSize.cols then
			colorpickerState.selectedCol = colorpickerState.gridSize.cols - 1
		end

		-- Ensure the selected position has a color
		if
			not hasColorAt(
				colorpickerState.selectedRow,
				colorpickerState.selectedCol,
				colorpickerState.gridSize,
				#colorpickerState.colorKeys
			)
		then
			-- If not, reset to the first color
			colorpickerState.selectedRow = 0
			colorpickerState.selectedCol = 0
		end

		-- Ensure scroll position is still valid
		if colorpickerState.totalGridHeight > colorpickerState.visibleGridHeight then
			colorpickerState.scrollY = math.max(
				0,
				math.min(
					colorpickerState.scrollY,
					colorpickerState.totalGridHeight - colorpickerState.visibleGridHeight
				)
			)
		else
			colorpickerState.scrollY = 0
		end
	end

	-- Start hover animation for the selected color
	colorpickerState.currentScale = 1
	colorpickerState.scaleTween = tween.new(ANIMATION.DURATION, colorpickerState, {
		currentScale = ANIMATION.SCALE,
	}, "outQuad")
end

return colorpicker
