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
local COLORPICKERHSV_SCREEN = "colorpickerhsv"

local assets = {
	sliders = love.graphics.newImage("assets/icons/plus.png"),
}

-- Constants
local PADDING = 20
local BOTTOM_PADDING = controls.HEIGHT
local SQUARE_SPACING = 18
local SQUARE_SIZE = 60
local COLOR_NAME_PADDING = 20

-- Helper function to get all color keys
local function getColorKeys()
	-- Use the ordered keys directly from the colors module
	local keys = {}
	for _, key in ipairs(colors._ordered_keys) do
		-- Skip the "white" color since it's hardcoded as foreground
		if key ~= "white" then
			table.insert(keys, key)
		end
	end
	return keys
end

-- Helper function to calculate grid dimensions (currently hardcoded)
local function calculateGridSize()
	return {
		cols = 6,
		rows = 4,
	}
end

-- Helper function to convert grid position to linear index
local function gridPosToIndex(row, col, grid)
	return row * grid.cols + col + 1
end

-- Helper function to check if a grid position has a color
local function hasColorAt(row, col, grid, totalColors)
	-- Calculate position of custom square
	local lastRow = math.floor((totalColors - 1) / grid.cols)
	local lastCol = (totalColors - 1) % grid.cols

	-- Check if this is the custom square position
	if row == lastRow and col == lastCol + 1 then
		return true
	end

	-- Otherwise check if it's a regular color position
	local index = gridPosToIndex(row, col, grid)
	return index <= totalColors
end

-- Constants for border appearance
local BORDER = {
	NORMAL_WIDTH = 2,
	SELECTED_WIDTH = 8,
	CORNER_RADIUS = 12,
}

-- Animation constants
local ANIMATION = {
	SCALE = 1.2,
	DURATION = 0.2,
}

local colorpickerState = {
	colorKeys = getColorKeys(),
	gridSize = nil,
	squareSize = 80, -- Initialize with a default value
	selectedRow = 0,
	selectedCol = 0,
	currentScale = 1,
	scaleTween = nil,
	offsetX = 0,
	offsetY = 0,
}

function colorpicker.load()
	colorpickerState.colorKeys = getColorKeys()
	colorpickerState.gridSize = calculateGridSize()

	-- Calculate available space, accounting for bottom padding and margins
	local availableHeight = state.screenHeight - BOTTOM_PADDING - (PADDING * 2)
	local availableWidth = state.screenWidth - (PADDING * 2)

	-- Calculate square size based on available space and fixed grid dimensions
	local maxSquareWidth = (availableWidth - (SQUARE_SPACING * (colorpickerState.gridSize.cols - 1)))
		/ colorpickerState.gridSize.cols
	local maxSquareHeight = (availableHeight - (SQUARE_SPACING * (colorpickerState.gridSize.rows - 1)))
		/ colorpickerState.gridSize.rows
	colorpickerState.squareSize = math.floor(math.min(maxSquareWidth, maxSquareHeight, SQUARE_SIZE))

	-- Calculate total grid dimensions
	local totalWidth = (colorpickerState.gridSize.cols * colorpickerState.squareSize)
		+ (colorpickerState.gridSize.cols - 1) * SQUARE_SPACING
	local totalHeight = (colorpickerState.gridSize.rows * colorpickerState.squareSize)
		+ (colorpickerState.gridSize.rows - 1) * SQUARE_SPACING

	-- Center the grid in the available space, accounting for bottom padding
	colorpickerState.offsetX = math.floor((state.screenWidth - totalWidth) / 2)
	colorpickerState.offsetY = math.floor((state.screenHeight - BOTTOM_PADDING - totalHeight) / 2)
end

function colorpicker.draw()
	-- Set background
	love.graphics.setColor(colors.bg)
	love.graphics.clear()

	-- Draw color grid
	local colorIndex = 1
	for row = 0, colorpickerState.gridSize.rows - 1 do
		for col = 0, colorpickerState.gridSize.cols - 1 do
			-- Only draw if there is a color for this position
			if colorIndex <= #colorpickerState.colorKeys then
				local x = colorpickerState.offsetX + col * (colorpickerState.squareSize + SQUARE_SPACING)
				local y = colorpickerState.offsetY + row * (colorpickerState.squareSize + SQUARE_SPACING)

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

				colorIndex = colorIndex + 1
			end
		end
	end

	-- Draw selected color name below the grid
	local selectedIndex =
		gridPosToIndex(colorpickerState.selectedRow, colorpickerState.selectedCol, colorpickerState.gridSize)
	local selectedKey = colorpickerState.colorKeys[selectedIndex]
	if selectedKey then
		love.graphics.setFont(state.fonts.header)
		local colorName = colors.names[selectedKey]
		local nameWidth = state.fonts.header:getWidth(colorName)
		local nameX = (state.screenWidth - nameWidth) / 2

		-- Position the name above the controls area with padding
		local nameY = state.screenHeight - BOTTOM_PADDING - state.fonts.header:getHeight() - COLOR_NAME_PADDING
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
		love.graphics.print(colorName, nameX, nameY)
	end

	-- Draw custom color square after the grid
	local lastRow = math.floor((#colorpickerState.colorKeys - 1) / colorpickerState.gridSize.cols)
	local lastCol = (#colorpickerState.colorKeys - 1) % colorpickerState.gridSize.cols
	local customX = colorpickerState.offsetX + (lastCol + 1) * (colorpickerState.squareSize + SQUARE_SPACING)
	local customY = colorpickerState.offsetY + lastRow * (colorpickerState.squareSize + SQUARE_SPACING)

	-- Calculate scale and offset for custom square
	local scale = 1
	local offset = 0
	if lastRow == colorpickerState.selectedRow and lastCol + 1 == colorpickerState.selectedCol then
		scale = colorpickerState.currentScale
		offset = (colorpickerState.squareSize * (scale - 1)) / 2
	end

	-- Draw background
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle(
		"fill",
		customX - offset,
		customY - offset,
		colorpickerState.squareSize * scale,
		colorpickerState.squareSize * scale,
		BORDER.CORNER_RADIUS
	)

	-- Draw custom color icon centered
	love.graphics.setColor(0.2, 0.2, 0.2, 1)
	local baseIconScale = (colorpickerState.squareSize * 0.5) / assets.sliders:getWidth()
	local iconScale = baseIconScale
	-- Scale the icon with the square when selected
	if lastRow == colorpickerState.selectedRow and lastCol + 1 == colorpickerState.selectedCol then
		iconScale = baseIconScale * scale
	end

	-- Calculate icon position to keep it centered during scaling
	local iconWidth = assets.sliders:getWidth() * iconScale
	local iconHeight = assets.sliders:getHeight() * iconScale
	local iconX = customX - offset + (colorpickerState.squareSize * scale - iconWidth) / 2
	local iconY = customY - offset + (colorpickerState.squareSize * scale - iconHeight) / 2
	love.graphics.draw(assets.sliders, iconX, iconY, 0, iconScale, iconScale)

	-- Draw border
	love.graphics.setColor(colors.white[1], colors.white[2], colors.white[3], 1)
	love.graphics.setLineWidth(
		lastRow == colorpickerState.selectedRow
				and lastCol + 1 == colorpickerState.selectedCol
				and BORDER.SELECTED_WIDTH
			or BORDER.NORMAL_WIDTH
	)
	love.graphics.rectangle(
		"line",
		customX - offset,
		customY - offset,
		colorpickerState.squareSize * scale,
		colorpickerState.squareSize * scale,
		BORDER.CORNER_RADIUS
	)

	-- Show "Custom" text when selected
	if lastRow == colorpickerState.selectedRow and lastCol + 1 == colorpickerState.selectedCol then
		love.graphics.setFont(state.fonts.header)
		local text = "Custom"
		local textWidth = state.fonts.header:getWidth(text)
		local textX = (state.screenWidth - textWidth) / 2
		local textY = state.screenHeight - BOTTOM_PADDING - state.fonts.header:getHeight() - COLOR_NAME_PADDING
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
		love.graphics.print(text, textX, textY)
	end

	-- Draw controls
	controls.draw({
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

		-- Handle return to menu without selection
		if virtualJoystick:isGamepadDown("b") then
			if switchScreen then
				switchScreen(MENU_SCREEN)
				state.resetInputTimer()
			end
			return
		end

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
			end
		end

		-- Reset timer if moved
		if moved then
			state.resetInputTimer()
		end

		-- Handle select
		if virtualJoystick:isGamepadDown("a") then
			-- Check if custom square is selected
			local lastRow = math.floor((#colorpickerState.colorKeys - 1) / colorpickerState.gridSize.cols)
			local lastCol = (#colorpickerState.colorKeys - 1) % colorpickerState.gridSize.cols

			if colorpickerState.selectedRow == lastRow and colorpickerState.selectedCol == lastCol + 1 then
				-- Custom square selected, go to HSV screen
				if switchScreen then
					switchScreen(COLORPICKERHSV_SCREEN)
					state.resetInputTimer()
				end
			else
				-- Regular color selected
				local selectedIndex = gridPosToIndex(
					colorpickerState.selectedRow,
					colorpickerState.selectedCol,
					colorpickerState.gridSize
				)
				local selectedKey = colorpickerState.colorKeys[selectedIndex]
				if selectedKey then
					menuScreen.setSelectedColor(state.lastSelectedButton, selectedKey)
					if switchScreen then
						switchScreen(MENU_SCREEN)
						state.resetInputTimer()
					end
				end
			end
		end
	end
end

function colorpicker.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

return colorpicker
