--- Hex color picker screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local colorUtils = require("utils.color")
local constants = require("screen.color_picker.constants")
local tove = require("tove")
local errorHandler = require("error_handler")

local hex = {}

-- Store screen switching function
local switchScreen = nil

-- Constants
local EDGE_PADDING = 20
local TOP_PADDING = 20
local PREVIEW_HEIGHT = 80
local GRID_PADDING = 10
local LAST_COLUMN_EXTRA_PADDING = 20 -- Extra padding before the last column
local BUTTON_CORNER_RADIUS = 8
local BUTTON_OUTLINE_WIDTH = 2
local BUTTON_HOVER_OUTLINE_WIDTH = 4
local INPUT_RECT_WIDTH = 30
local INPUT_RECT_HEIGHT = 40
local INPUT_RECT_SPACING = 5
local ICON_SIZE = 24

-- State
local hexState = {
	maxInputLength = 6,
}

-- Helper function to get current hex state from central state manager
local function getCurrentHexState()
	local colorType = state.activeColorContext
	local context = state.getColorContext(colorType)
	return context.hex -- Return the hex specific state for this color context
end

-- Button grid layout (5x4)
local buttons = {
	{ "0", "1", "2", "3", "" },
	{ "4", "5", "6", "7", "BACKSPACE" },
	{ "8", "9", "A", "B", "CLEAR" },
	{ "C", "D", "E", "F", "CONFIRM" },
}

-- Icon cache
local iconCache = {}

-- Helper function to load an icon
local function loadIcon(name)
	if not iconCache[name] then
		local svgPath = "assets/icons/" .. name .. ".svg"
		local svg = love.filesystem.read(svgPath)
		if svg then
			iconCache[name] = tove.newGraphics(svg, ICON_SIZE)
		else
			errorHandler.setError("Failed to load SVG icon: " .. svgPath)
		end
	end
	return iconCache[name]
end

-- Helper function to check if hex input is valid
local function isValidHex(input)
	if #input ~= 6 then
		return false
	end

	for i = 1, 6 do
		local char = input:sub(i, i):upper()
		if not (char:match("[0-9]") or (char >= "A" and char <= "F")) then
			return false
		end
	end

	return true
end

-- Helper function to get button dimensions
local function getButtonDimensions()
	local contentArea = constants.calculateContentArea()

	local gridWidth = contentArea.width - (2 * EDGE_PADDING) - LAST_COLUMN_EXTRA_PADDING
	local availableHeight = contentArea.height - TOP_PADDING - PREVIEW_HEIGHT - (2 * GRID_PADDING)

	local buttonWidth = (gridWidth - (4 * GRID_PADDING)) / 5
	local buttonHeight = (availableHeight - (3 * GRID_PADDING)) / 4

	return buttonWidth, buttonHeight
end

-- Helper function to get button position
local function getButtonPosition(row, col)
	local contentArea = constants.calculateContentArea()

	local buttonWidth, buttonHeight = getButtonDimensions()
	local startX = EDGE_PADDING
	local startY = contentArea.y + TOP_PADDING + PREVIEW_HEIGHT + GRID_PADDING

	local x = startX + (col - 1) * (buttonWidth + GRID_PADDING)

	-- Add extra padding before the last column (special buttons)
	if col == 5 then
		x = x + LAST_COLUMN_EXTRA_PADDING
	end

	local y = startY + (row - 1) * (buttonHeight + GRID_PADDING)

	return x, y, buttonWidth, buttonHeight
end

function hex.load()
	-- Default context values are set in `state.lua`, nothing to do here

	-- Preload icons
	loadIcon("delete")
	loadIcon("trash")
	loadIcon("check")
end

function hex.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	local contentArea = constants.calculateContentArea()

	-- Get current color type state
	local currentState = getCurrentHexState()

	-- Draw color preview rectangle
	local previewX = EDGE_PADDING
	local previewY = contentArea.y + TOP_PADDING
	local previewWidth = contentArea.width - (2 * EDGE_PADDING)

	-- Variables for input display
	local inputStartX = previewX + (previewWidth - ((INPUT_RECT_WIDTH * 6) + (INPUT_RECT_SPACING * 5))) / 2
	local inputY = previewY + (PREVIEW_HEIGHT - INPUT_RECT_HEIGHT) / 2
	local textColor = colors.ui.foreground -- Default text color

	-- Fill with color if input is valid
	if isValidHex(currentState.input) then
		local r, g, b = colorUtils.hexToRgb(currentState.input)
		love.graphics.setColor(r, g, b)
		love.graphics.rectangle("fill", previewX, previewY, previewWidth, PREVIEW_HEIGHT, 8, 8)

		-- Calculate contrasting color for text
		local contrastR, contrastG, contrastB = colorUtils.calculateContrastingColor(r, g, b)
		textColor = { contrastR, contrastG, contrastB }

		-- Draw preview rectangle outline with foreground color when valid
		love.graphics.setColor(colors.ui.foreground)
	else
		-- Draw preview rectangle outline with background color when invalid (making it invisible)
		love.graphics.setColor(colors.ui.background)
	end

	-- Draw preview rectangle outline
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", previewX, previewY, previewWidth, PREVIEW_HEIGHT, 8, 8)

	-- Draw # symbol
	love.graphics.setColor(textColor)
	love.graphics.setFont(state.fonts.header)
	local hashWidth = state.fonts.header:getWidth("#")
	love.graphics.print(
		"#",
		inputStartX - hashWidth - 10,
		inputY + (INPUT_RECT_HEIGHT - state.fonts.header:getHeight()) / 2
	)

	-- Draw input characters or underscores for empty positions
	for i = 1, 6 do
		local rectX = inputStartX + (i - 1) * (INPUT_RECT_WIDTH + INPUT_RECT_SPACING)
		local charY = inputY + (INPUT_RECT_HEIGHT - state.fonts.header:getHeight()) / 2

		-- Draw character if entered, otherwise draw underscore
		local char = (i <= #currentState.input) and currentState.input:sub(i, i):upper() or "_"
		local charWidth = state.fonts.header:getWidth(char)
		local charX = rectX + (INPUT_RECT_WIDTH - charWidth) / 2

		love.graphics.setColor(textColor)
		love.graphics.print(char, charX, charY)
	end

	-- Draw button grid
	for row = 1, #buttons do
		for col = 1, #buttons[row] do
			local buttonText = buttons[row][col]
			if buttonText ~= "" then
				local x, y, width, height = getButtonPosition(row, col)
				local isSelected = (currentState.selectedButton.row == row and currentState.selectedButton.col == col)
				local isConfirmButton = (buttonText == "CONFIRM")
				local isConfirmDisabled = isConfirmButton and not isValidHex(currentState.input)

				-- Draw button background with transparency for disabled confirm button
				if isConfirmButton and isSelected and isValidHex(currentState.input) then
					-- Valid confirm button that is selected - use accent color
					love.graphics.setColor(colors.ui.accent)
				else
					-- Use surface color for selected buttons, background color for non-selected
					love.graphics.setColor(isSelected and colors.ui.surface or colors.ui.background)
				end
				love.graphics.rectangle("fill", x, y, width, height, BUTTON_CORNER_RADIUS, BUTTON_CORNER_RADIUS)

				-- Draw button outline
				love.graphics.setLineWidth(isSelected and BUTTON_HOVER_OUTLINE_WIDTH or BUTTON_OUTLINE_WIDTH)
				if isConfirmButton and isSelected and isValidHex(currentState.input) then
					-- Valid confirm button that is selected - use accent color for outline too
					love.graphics.setColor(colors.ui.accent)
				elseif isConfirmDisabled then
					-- Use semi-transparent outline for disabled confirm button
					love.graphics.setColor(
						isSelected and { colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 0.5 }
							or {
								colors.ui.surface[1],
								colors.ui.surface[2],
								colors.ui.surface[3],
								0.5,
							}
					)
				else
					-- For selected buttons, use the same color as background (surface) to make them look solid
					-- For non-selected buttons, use surface color for outline
					love.graphics.setColor(isSelected and colors.ui.surface or colors.ui.surface)
				end
				love.graphics.rectangle("line", x, y, width, height, BUTTON_CORNER_RADIUS, BUTTON_CORNER_RADIUS)

				-- Special handling for icon buttons
				if buttonText == "BACKSPACE" then
					-- Backspace icon
					local icon = loadIcon("delete")
					if icon then
						-- Set icon color directly using foreground color
						icon:setMonochrome(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3])
						-- Also set the LÖVE draw color to foreground
						love.graphics.setColor(colors.ui.foreground)
						-- Draw the icon centered on the button
						local centerX = x + width / 2
						local centerY = y + height / 2
						icon:draw(centerX, centerY)
					end
				elseif buttonText == "CLEAR" then
					-- Trash icon
					local icon = loadIcon("trash")
					if icon then
						-- Set icon color directly using foreground color
						icon:setMonochrome(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3])
						-- Also set the LÖVE draw color to foreground
						love.graphics.setColor(colors.ui.foreground)
						-- Draw the icon centered on the button
						local centerX = x + width / 2
						local centerY = y + height / 2
						icon:draw(centerX, centerY)
					end
				elseif buttonText == "CONFIRM" then
					-- Check icon (confirm)
					local icon = loadIcon("check")
					if icon then
						-- Use foreground color for icon
						if isConfirmDisabled and not isSelected then
							-- If disabled and not selected, use dimmed foreground color
							local dimmedColor = {
								colors.ui.foreground[1] * 0.5,
								colors.ui.foreground[2] * 0.5,
								colors.ui.foreground[3] * 0.5,
							}
							icon:setMonochrome(dimmedColor[1], dimmedColor[2], dimmedColor[3])
							-- Also set the LÖVE draw color to the same dimmed foreground
							love.graphics.setColor(dimmedColor)
						else
							-- Otherwise use full foreground color
							icon:setMonochrome(
								colors.ui.foreground[1],
								colors.ui.foreground[2],
								colors.ui.foreground[3]
							)
							-- Also set the LÖVE draw color to foreground
							love.graphics.setColor(colors.ui.foreground)
						end
						-- Draw the icon centered on the button
						local centerX = x + width / 2
						local centerY = y + height / 2
						icon:draw(centerX, centerY)
					end
				else
					-- Regular text button - set color for text
					love.graphics.setColor(colors.ui.foreground)
					love.graphics.setFont(state.fonts.body)
					local textWidth = state.fonts.body:getWidth(buttonText)
					local textHeight = state.fonts.body:getHeight()
					love.graphics.print(buttonText, x + (width - textWidth) / 2, y + (height - textHeight) / 2)
				end
			end
		end
	end

	-- Draw controls
	controls.draw({
		{ button = { "l1", "r1" }, text = "Switch Tabs" },
		{ button = "d_pad", text = "Navigate" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function hex.update(_dt)
	if state.canProcessInput() then
		local virtualJoystick = require("input").virtualJoystick

		-- Get current color type state
		local currentState = getCurrentHexState()

		-- Handle D-pad navigation
		if virtualJoystick:isGamepadDown("dpup") then
			currentState.selectedButton.row = math.max(1, currentState.selectedButton.row - 1)

			-- Skip empty buttons
			while buttons[currentState.selectedButton.row][currentState.selectedButton.col] == "" do
				currentState.selectedButton.col = currentState.selectedButton.col - 1
				if currentState.selectedButton.col < 1 then
					currentState.selectedButton.col = #buttons[currentState.selectedButton.row]
				end
			end

			state.resetInputTimer()
		elseif virtualJoystick:isGamepadDown("dpdown") then
			currentState.selectedButton.row = math.min(#buttons, currentState.selectedButton.row + 1)

			-- Skip empty buttons
			while
				currentState.selectedButton.col > #buttons[currentState.selectedButton.row]
				or buttons[currentState.selectedButton.row][currentState.selectedButton.col] == ""
			do
				currentState.selectedButton.col =
					math.min(currentState.selectedButton.col, #buttons[currentState.selectedButton.row])
				if buttons[currentState.selectedButton.row][currentState.selectedButton.col] == "" then
					currentState.selectedButton.col = currentState.selectedButton.col - 1
				end
			end

			state.resetInputTimer()
		elseif virtualJoystick:isGamepadDown("dpleft") then
			currentState.selectedButton.col = currentState.selectedButton.col - 1
			if currentState.selectedButton.col < 1 then
				currentState.selectedButton.col = #buttons[currentState.selectedButton.row]
			end

			-- Skip empty buttons
			while buttons[currentState.selectedButton.row][currentState.selectedButton.col] == "" do
				currentState.selectedButton.col = currentState.selectedButton.col - 1
				if currentState.selectedButton.col < 1 then
					currentState.selectedButton.col = #buttons[currentState.selectedButton.row]
				end
			end

			state.resetInputTimer()
		elseif virtualJoystick:isGamepadDown("dpright") then
			currentState.selectedButton.col = currentState.selectedButton.col + 1
			if currentState.selectedButton.col > #buttons[currentState.selectedButton.row] then
				currentState.selectedButton.col = 1
			end

			-- Skip empty buttons
			while buttons[currentState.selectedButton.row][currentState.selectedButton.col] == "" do
				currentState.selectedButton.col = currentState.selectedButton.col + 1
				if currentState.selectedButton.col > #buttons[currentState.selectedButton.row] then
					currentState.selectedButton.col = 1
				end
			end

			state.resetInputTimer()
		end

		-- Handle button press (A button)
		if virtualJoystick:isGamepadDown("a") then
			local selectedButton = buttons[currentState.selectedButton.row][currentState.selectedButton.col]

			if selectedButton == "BACKSPACE" then
				-- Backspace - remove last character
				if #currentState.input > 0 then
					currentState.input = currentState.input:sub(1, -2)
				end
			elseif selectedButton == "CLEAR" then
				-- Clear - remove all characters
				currentState.input = ""
			elseif selectedButton == "CONFIRM" then
				-- Confirm - only if input is valid
				if isValidHex(currentState.input) and switchScreen then
					-- Create hex code
					local hexCode = "#" .. currentState.input:upper()

					-- Store in central state
					local context = state.getColorContext(state.activeColorContext)
					context.currentColor = hexCode

					-- Return to menu and apply the color
					if switchScreen then
						switchScreen(state.previousScreen)
						local menuScreen = require("screen.menu")
						menuScreen.setSelectedColor(state.activeColorContext, hexCode)
					end
				end
			else
				-- Add character if not at max length
				if #currentState.input < hexState.maxInputLength then
					currentState.input = currentState.input .. selectedButton
				end
			end

			state.resetInputTimer()
		end
	end
end

function hex.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- Function to be called when entering this screen
function hex.onEnter()
	-- No additional initialization needed as state is managed centrally
	-- If hex-specific state needs to be initialized, do it here

	-- Optionally initialize input with current color if it's empty
	local currentState = getCurrentHexState()
	if currentState.input == "" then
		local colorType = state.activeColorContext
		local currentColorHex = state.getColorValue(colorType)
		if currentColorHex and currentColorHex:sub(1, 1) == "#" then
			-- Remove the # and convert to uppercase
			currentState.input = currentColorHex:sub(2):upper()
		end
	end
end

return hex
