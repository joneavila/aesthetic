--- Color picker palette screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local mainMenuScreen = require("screens.main_menu")
local tween = require("tween")
local controls = require("controls")
local constants = require("screens.color_picker.constants")

local palette = {}

local switchScreen = nil

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
	CORNER_RADIUS = 10,
}

-- Animation constants
local ANIMATION = {
	SCALE = 1.3,
	DURATION = 0.2,
}

-- Helper function to get current palette state from central state manager
local function getCurrentPaletteState()
	local colorType = state.activeColorContext
	local context = state.getColorContext(colorType)
	return context.palette -- Return the palette specific state for this color context
end

-- Helper function to get all color keys
local function getColorKeys()
	-- Use the ordered keys directly from the colors.palette module
	local keys = {}
	for _, key in ipairs(colors.palette._ordered_keys) do
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

	local contentArea = constants.calculateContentArea()

	-- Calculate available space
	local availableHeight = contentArea.height - (PADDING * 2)
	local availableWidth = contentArea.width - (PADDING * 2) - SCROLLBAR.WIDTH - SCROLLBAR.PADDING

	-- Calculate square size based on available width and fixed number of columns
	local squareSize = math.floor((availableWidth - (SQUARE_SPACING * (gridSize.cols - 1))) / gridSize.cols)

	-- Calculate how many rows can be displayed at once
	local visibleRows = math.floor((availableHeight - squareSize) / (squareSize + SQUARE_SPACING)) + 1

	-- Calculate total grid dimensions
	local totalWidth = (gridSize.cols * squareSize) + (gridSize.cols - 1) * SQUARE_SPACING
	local totalGridHeight = (gridSize.rows * squareSize) + (gridSize.rows - 1) * SQUARE_SPACING
	local visibleGridHeight = (visibleRows * squareSize) + (visibleRows - 1) * SQUARE_SPACING

	-- Calculate grid position
	local offsetX = math.floor((contentArea.width - totalWidth - SCROLLBAR.WIDTH - SCROLLBAR.PADDING) / 2)
	local offsetY = math.floor(contentArea.y + PADDING)

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

local paletteState = {
	colorKeys = getColorKeys(),
	gridSize = nil,
	squareSize = 0,
	currentScale = 1,
	scaleTween = nil,
	offsetX = 0,
	offsetY = 0,
	visibleRows = 0,
	totalGridHeight = 0,
	visibleGridHeight = 0,
}

function palette.load()
	-- Calculate grid dimensions and update state
	local dimensions = calculateGridDimensions()

	-- Update state with calculated dimensions
	paletteState.colorKeys = dimensions.colorKeys
	paletteState.gridSize = dimensions.gridSize
	paletteState.squareSize = dimensions.squareSize
	paletteState.visibleRows = dimensions.visibleRows
	paletteState.totalGridHeight = dimensions.totalGridHeight
	paletteState.visibleGridHeight = dimensions.visibleGridHeight
	paletteState.offsetX = dimensions.offsetX
	paletteState.offsetY = dimensions.offsetY
end

-- Helper function to draw the scrollbar
local function drawScrollbar()
	local contentArea = constants.calculateContentArea()

	-- Calculate scrollbar position and dimensions
	local scrollbarHeight = contentArea.height - (PADDING * 2)
	local scrollbarX = state.screenWidth - SCROLLBAR.WIDTH - SCROLLBAR.PADDING
	local scrollbarY = contentArea.y + PADDING

	-- Draw scrollbar background
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 0.2)
	love.graphics.rectangle("fill", scrollbarX, scrollbarY, SCROLLBAR.WIDTH, scrollbarHeight, SCROLLBAR.CORNER_RADIUS)

	-- Calculate handle position and size
	local contentRatio = paletteState.visibleGridHeight / paletteState.totalGridHeight
	local handleHeight = math.max(SCROLLBAR.HANDLE_MIN_HEIGHT, scrollbarHeight * contentRatio)

	-- Calculate handle position based on scroll position
	local scrollRatio = 0
	local currentState = getCurrentPaletteState()
	if paletteState.totalGridHeight > paletteState.visibleGridHeight then
		scrollRatio = currentState.scrollY / (paletteState.totalGridHeight - paletteState.visibleGridHeight)
	end

	local handleY = scrollbarY + (scrollbarHeight - handleHeight) * scrollRatio

	-- Draw handle
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], SCROLLBAR.OPACITY)
	love.graphics.rectangle("fill", scrollbarX, handleY, SCROLLBAR.WIDTH, handleHeight, SCROLLBAR.CORNER_RADIUS)
end

-- Helper function to draw the controls background
local function drawControlsBackground()
	love.graphics.setColor(colors.ui.background)
	love.graphics.rectangle("fill", 0, state.screenHeight - controls.HEIGHT, state.screenWidth, controls.HEIGHT)
end

function palette.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	-- Get current color type state
	local currentState = getCurrentPaletteState()

	-- Calculate the first visible row based on scroll position
	local firstVisibleRow = math.floor(currentState.scrollY / (paletteState.squareSize + SQUARE_SPACING))

	-- Calculate the last visible row
	local lastVisibleRow = math.min(firstVisibleRow + paletteState.visibleRows, paletteState.gridSize.rows - 1)

	-- Draw color grid (only visible rows)
	for row = firstVisibleRow, lastVisibleRow do
		for col = 0, paletteState.gridSize.cols - 1 do
			local colorIndex = gridPosToIndex(row, col, paletteState.gridSize)

			-- Only draw if there is a color for this position
			if colorIndex <= #paletteState.colorKeys then
				local x = paletteState.offsetX + col * (paletteState.squareSize + SQUARE_SPACING)

				-- Draw each row at a fixed position regardless of scroll offset
				local rowIndex = row - firstVisibleRow
				local y = paletteState.offsetY + rowIndex * (paletteState.squareSize + SQUARE_SPACING)

				-- Calculate scale and offset for the selected square
				local scale = 1
				local offset = 0
				if row == currentState.selectedRow and col == currentState.selectedCol then
					scale = paletteState.currentScale
					offset = (paletteState.squareSize * (scale - 1)) / 2
				end

				-- Draw the color square with scale
				local currentColor = paletteState.colorKeys[colorIndex]
				love.graphics.setColor(colors.palette[currentColor])
				love.graphics.rectangle(
					"fill",
					x - offset,
					y - offset,
					paletteState.squareSize * scale,
					paletteState.squareSize * scale,
					BORDER.CORNER_RADIUS
				)

				-- Draw border
				love.graphics.setColor(colors.ui.foreground)
				if row == currentState.selectedRow and col == currentState.selectedCol then
					love.graphics.setLineWidth(constants.OUTLINE.SELECTED_WIDTH)
				else
					love.graphics.setLineWidth(constants.OUTLINE.NORMAL_WIDTH)
				end
				love.graphics.rectangle(
					"line",
					x - offset,
					y - offset,
					paletteState.squareSize * scale,
					paletteState.squareSize * scale,
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
			button = { "l1", "r1" },
			text = "Switch Tabs",
		},
		{
			button = "a",
			text = "Confirm",
		},
		{
			button = "b",
			text = "Back",
		},
	})
end

function palette.update(dt)
	-- Update tween if it exists
	if paletteState.scaleTween then
		local complete = paletteState.scaleTween:update(dt)
		if complete then
			paletteState.scaleTween = nil
		end
	end

	if state.canProcessInput() then
		local virtualJoystick = require("input").virtualJoystick
		local moved = false

		-- Get current color type state
		local currentState = getCurrentPaletteState()

		local newRow, newCol = currentState.selectedRow, currentState.selectedCol

		-- Handle directional input
		if virtualJoystick:isGamepadDown("dpup") then
			if currentState.selectedRow > 0 then
				newRow = currentState.selectedRow - 1
			end
		elseif virtualJoystick:isGamepadDown("dpdown") then
			if currentState.selectedRow < paletteState.gridSize.rows - 1 then
				newRow = currentState.selectedRow + 1
			end
		elseif virtualJoystick:isGamepadDown("dpleft") then
			if currentState.selectedCol > 0 then
				newCol = currentState.selectedCol - 1
			end
		elseif virtualJoystick:isGamepadDown("dpright") then
			if currentState.selectedCol < paletteState.gridSize.cols - 1 then
				newCol = currentState.selectedCol + 1
			end
		end

		-- Only move if the new position has a color
		if hasColorAt(newRow, newCol, paletteState.gridSize, #paletteState.colorKeys) then
			if newRow ~= currentState.selectedRow or newCol ~= currentState.selectedCol then
				currentState.selectedRow = newRow
				currentState.selectedCol = newCol
				moved = true

				-- Start new hover animation
				paletteState.currentScale = 1
				paletteState.scaleTween = tween.new(ANIMATION.DURATION, paletteState, {
					currentScale = ANIMATION.SCALE,
				}, "outQuad")

				-- Handle scrolling when selection moves out of view
				local rowPosition = currentState.selectedRow * (paletteState.squareSize + SQUARE_SPACING)

				-- Calculate the visible area boundaries
				local visibleTop = currentState.scrollY
				local visibleBottom = visibleTop + paletteState.visibleGridHeight - paletteState.squareSize

				-- Scroll up if selection is above visible area
				if rowPosition < visibleTop then
					currentState.scrollY = rowPosition
				end

				-- Scroll down if selection is below visible area
				if rowPosition > visibleBottom then
					currentState.scrollY = rowPosition
						- paletteState.visibleGridHeight
						+ paletteState.squareSize
						+ SQUARE_SPACING
				end

				-- Ensure scroll position doesn't go out of bounds
				currentState.scrollY = math.max(
					0,
					math.min(currentState.scrollY, paletteState.totalGridHeight - paletteState.visibleGridHeight)
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
				gridPosToIndex(currentState.selectedRow, currentState.selectedCol, paletteState.gridSize)
			local selectedKey = paletteState.colorKeys[selectedIndex]
			if selectedKey then
				-- Convert the selected color key to hex code
				local hexCode = colors.toHex(selectedKey, "palette")
				if hexCode then
					-- Store in central state
					local context = state.getColorContext(state.activeColorContext)
					context.currentColor = hexCode

					-- Pass to menu
					mainMenuScreen.setSelectedColor(state.activeColorContext, hexCode)
					if switchScreen then
						switchScreen(state.previousScreen)
						state.resetInputTimer()
					end
				end
			end
		end
	end
end

function palette.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- Helper function to find the closest color in the palette to a given hex value
function palette.findClosestColor(hexColor)
	-- Convert hex to RGB
	local colorUtil = require("utils.color")
	local targetR, targetG, targetB = colorUtil.hexToRgb(hexColor)

	local minDistance = math.huge
	local closestColor = nil
	local closestRow = 0
	local closestCol = 0

	-- Loop through all colors
	local colorKeys = getColorKeys()
	local gridSize = calculateGridSize()

	for i, colorKey in ipairs(colorKeys) do
		local row = math.floor((i - 1) / gridSize.cols)
		local col = (i - 1) % gridSize.cols

		local paletteColor = colors.palette[colorKey]
		if paletteColor then
			local r, g, b = paletteColor[1], paletteColor[2], paletteColor[3]

			-- Calculate color distance (simple Euclidean distance in RGB space)
			local distance = math.sqrt((r - targetR) ^ 2 + (g - targetG) ^ 2 + (b - targetB) ^ 2)

			if distance < minDistance then
				minDistance = distance
				closestColor = colorKey
				closestRow = row
				closestCol = col
			end
		end
	end

	return {
		colorKey = closestColor,
		row = closestRow,
		col = closestCol,
	}
end

-- Function to initialize palette state for the current color
function palette.initializePaletteState()
	local currentContext = state.activeColorContext
	local hexColor = state.getColorValue(currentContext)

	-- Find the closest color in the palette
	local closestInfo = palette.findClosestColor(hexColor)

	if closestInfo and closestInfo.colorKey then
		-- Get palette state for the current color context
		local currentPaletteState = getCurrentPaletteState()

		-- Update the palette state with the closest color's position
		currentPaletteState.selectedRow = closestInfo.row
		currentPaletteState.selectedCol = closestInfo.col

		-- Ensure proper scrolling to make the selection visible
		local dimensions = calculateGridDimensions()
		local squareSize = dimensions.squareSize
		local spacing = SQUARE_SPACING

		-- Calculate scroll position to center the selected color
		currentPaletteState.scrollY = (closestInfo.row * (squareSize + spacing))
			- (dimensions.visibleRows / 2 * (squareSize + spacing))

		-- Clamp scroll position
		currentPaletteState.scrollY = math.max(0, currentPaletteState.scrollY)
		currentPaletteState.scrollY = math.min(
			(dimensions.gridSize.rows * (squareSize + spacing)) - dimensions.visibleGridHeight,
			currentPaletteState.scrollY
		)
	end
end

-- Function called when entering this screen
function palette.onEnter()
	-- Calculate grid dimensions and update state
	local dimensions = calculateGridDimensions()

	-- Update state with calculated dimensions
	paletteState.colorKeys = dimensions.colorKeys
	paletteState.gridSize = dimensions.gridSize
	paletteState.squareSize = dimensions.squareSize
	paletteState.visibleRows = dimensions.visibleRows
	paletteState.totalGridHeight = dimensions.totalGridHeight
	paletteState.visibleGridHeight = dimensions.visibleGridHeight
	paletteState.offsetX = dimensions.offsetX
	paletteState.offsetY = dimensions.offsetY

	-- Try to initialize palette state based on current color
	palette.initializePaletteState()

	-- Get current color type state
	local currentState = getCurrentPaletteState()

	-- Validate that the selected position is still valid after grid size changes
	-- and adjust if necessary
	if currentState.selectedRow >= paletteState.gridSize.rows then
		currentState.selectedRow = paletteState.gridSize.rows - 1
	end

	if currentState.selectedCol >= paletteState.gridSize.cols then
		currentState.selectedCol = paletteState.gridSize.cols - 1
	end

	-- Ensure the selected position has a color
	if
		not hasColorAt(
			currentState.selectedRow,
			currentState.selectedCol,
			paletteState.gridSize,
			#paletteState.colorKeys
		)
	then
		-- If not, reset to the first color
		currentState.selectedRow = 0
		currentState.selectedCol = 0
	end

	-- Ensure scroll position is still valid
	if paletteState.totalGridHeight > paletteState.visibleGridHeight then
		currentState.scrollY =
			math.max(0, math.min(currentState.scrollY, paletteState.totalGridHeight - paletteState.visibleGridHeight))
	else
		currentState.scrollY = 0
	end

	-- Start hover animation for the selected color
	paletteState.currentScale = 1
	paletteState.scaleTween = tween.new(ANIMATION.DURATION, paletteState, {
		currentScale = ANIMATION.SCALE,
	}, "outQuad")
end

return palette
