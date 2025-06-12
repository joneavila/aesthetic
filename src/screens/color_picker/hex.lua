--- Hex color picker screen
local love = require("love")

local colors = require("colors")
local controls = require("control_hints").ControlHints
local screens = require("screens")
local shared = require("screens.color_picker.shared")

local state = require("state")

local background = require("ui.background")
local fonts = require("ui.fonts")

local colorUtils = require("utils.color")
local svg = require("utils.svg")
local tween = require("tween")
local InputManager = require("ui.controllers.input_manager")

local hex = {}

local EDGE_PADDING = 20
local TOP_PADDING = 10
local PREVIEW_HEIGHT = 80
local GRID_PADDING = 10
local BUTTON_CORNER_RADIUS = 8
local INPUT_RECT_WIDTH = 30
local INPUT_RECT_HEIGHT = 40
local INPUT_RECT_SPACING = 5
local ICON_SIZE = 24
local ANIMATION_SCALE = 0.1
local ANIMATION_DURATION = 0.4 -- Duration for each phase (expand/contract) in seconds
-- State
local hexState = {
	maxInputLength = 6,
	confirmButtonTween = nil,
	confirmButtonScale = 1,
	confirmButtonFlash = 0,
	lastValidInput = "",
	animationPhase = "idle", -- "expanding", "contracting", "idle"
}

local controlHintsInstance

-- Helper function to get current hex state from central state manager
local function getCurrentHexState()
	local colorType = state.activeColorContext
	local context = state.getColorContext(colorType)
	return context.hex -- Return the hex specific state for this color context
end

-- Button grid layout (3x6)
local buttons = {
	{ "0", "1", "2", "3", "4", "5" },
	{ "6", "7", "8", "9", "A", "B" },
	{ "C", "D", "E", "F", "BACKSPACE", "CONFIRM" },
}

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

local function getButtonDimensions()
	local contentArea = shared.calculateContentArea()

	local gridWidth = contentArea.width - (2 * EDGE_PADDING)
	local availableHeight = contentArea.height

	local buttonWidth = (gridWidth - (5 * GRID_PADDING)) / 6
	local buttonHeight = (availableHeight - (2 * GRID_PADDING)) / 3

	-- Make buttons square by using the smaller dimension
	local buttonSize = math.min(buttonWidth, buttonHeight)

	return buttonSize, buttonSize
end

-- Helper function to get grid start position (for centering)
local function getGridStartPosition()
	local contentArea = shared.calculateContentArea()
	local buttonSize = getButtonDimensions()

	-- Calculate total grid dimensions
	local totalGridWidth = (buttonSize * 6) + (GRID_PADDING * 5)
	local totalGridHeight = (buttonSize * 3) + (GRID_PADDING * 2)

	-- Calculate available space for the grid (between preview and controls)
	local availableWidth = contentArea.width
	local availableHeight = contentArea.height - TOP_PADDING - PREVIEW_HEIGHT

	-- Center the grid horizontally and vertically in the available area
	local startX = (availableWidth - totalGridWidth) / 2
	local startY = contentArea.y + TOP_PADDING + PREVIEW_HEIGHT + (availableHeight - totalGridHeight) / 2

	return startX, startY
end

-- Helper function to get button position
local function getButtonPosition(row, col)
	local buttonWidth, buttonHeight = getButtonDimensions()
	local startX, startY = getGridStartPosition()

	local x = startX + (col - 1) * (buttonWidth + GRID_PADDING)
	local y = startY + (row - 1) * (buttonHeight + GRID_PADDING)

	return x, y, buttonWidth, buttonHeight
end

-- Helper function to start confirm button wobble animation
local function startConfirmButtonWobble()
	if hexState.confirmButtonTween then
		return -- Animation already running
	end

	-- Reset animation values
	hexState.confirmButtonScale = 1
	hexState.confirmButtonFlash = 0
	hexState.animationPhase = "expanding"

	-- Create expand phase: animate from 1 to 1 + ANIMATION_SCALE
	hexState.confirmButtonTween = tween.new(ANIMATION_DURATION, hexState, {
		confirmButtonScale = 1 + ANIMATION_SCALE,
		confirmButtonFlash = 1,
	}, tween.easing.outQuad)
end

function hex.draw()
	background.draw()

	love.graphics.push("all")

	local contentArea = shared.calculateContentArea()

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
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", previewX, previewY, previewWidth, PREVIEW_HEIGHT, 8, 8)

	-- Get fonts
	local monoHeaderFont = fonts.loaded.monoHeader
	local bodyFont = fonts.loaded.body

	-- Draw # symbol
	love.graphics.setColor(textColor)
	if monoHeaderFont then
		love.graphics.setFont(monoHeaderFont)
		local hashWidth = monoHeaderFont:getWidth("#")
		love.graphics.print(
			"#",
			inputStartX - hashWidth - 10,
			inputY + (INPUT_RECT_HEIGHT - monoHeaderFont:getHeight()) / 2
		)

		-- Draw input characters or underscores for empty positions
		for i = 1, 6 do
			local rectX = inputStartX + (i - 1) * (INPUT_RECT_WIDTH + INPUT_RECT_SPACING)
			local charY = inputY + (INPUT_RECT_HEIGHT - monoHeaderFont:getHeight()) / 2

			-- Draw character if entered, otherwise draw underscore
			local char = (i <= #currentState.input) and currentState.input:sub(i, i):upper() or "_"
			local charWidth = monoHeaderFont:getWidth(char)
			local charX = rectX + (INPUT_RECT_WIDTH - charWidth) / 2

			love.graphics.setColor(textColor)
			love.graphics.print(char, charX, charY)
		end
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

				-- Apply animation to confirm button
				if isConfirmButton then
					local scale = hexState.confirmButtonScale

					-- Calculate scaled dimensions
					local scaledWidth = width * scale
					local scaledHeight = height * scale
					local scaledX = x + (width - scaledWidth) / 2
					local scaledY = y + (height - scaledHeight) / 2

					-- Update position and size for animation
					x, y, width, height = scaledX, scaledY, scaledWidth, scaledHeight
				end

				-- Draw button background
				if isConfirmButton then
					-- For confirm button, handle animation color fading
					local normalBgColor = (isSelected and isValidHex(currentState.input)) and colors.ui.accent
						or (isSelected and colors.ui.surface or colors.ui.background)

					if hexState.confirmButtonTween and isValidHex(currentState.input) then
						-- During animation, fade between normal color and accent color
						local fadeAmount = hexState.confirmButtonFlash
						local accentColor = colors.ui.accent

						-- Interpolate between normal background and accent color
						local r = normalBgColor[1] + (accentColor[1] - normalBgColor[1]) * fadeAmount
						local g = normalBgColor[2] + (accentColor[2] - normalBgColor[2]) * fadeAmount
						local b = normalBgColor[3] + (accentColor[3] - normalBgColor[3]) * fadeAmount

						love.graphics.setColor(r, g, b)
					else
						-- No animation, use normal colors
						love.graphics.setColor(normalBgColor)
					end
				else
					-- Non-confirm buttons use normal colors
					love.graphics.setColor(isSelected and colors.ui.surface or colors.ui.background)
				end
				love.graphics.rectangle("fill", x, y, width, height, BUTTON_CORNER_RADIUS, BUTTON_CORNER_RADIUS)

				-- Draw button outline
				love.graphics.setLineWidth(1)
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
					local icon = svg.loadIcon("delete", ICON_SIZE)
					if icon then
						-- Draw the icon centered on the button with SVG utility
						local centerX = x + width / 2
						local centerY = y + height / 2
						svg.drawIcon(icon, centerX, centerY, colors.ui.foreground)
					end
				elseif buttonText == "CONFIRM" then
					-- Check icon (confirm)
					local icon = svg.loadIcon("check", ICON_SIZE)
					if icon then
						local iconColor
						-- Use foreground color for icon
						if isConfirmDisabled and not isSelected then
							-- If disabled and not selected, use dimmed foreground color
							iconColor = {
								colors.ui.foreground[1] * 0.5,
								colors.ui.foreground[2] * 0.5,
								colors.ui.foreground[3] * 0.5,
							}
						elseif hexState.confirmButtonTween and isValidHex(currentState.input) then
							-- During animation, fade icon color from normal to background color for contrast
							local fadeAmount = hexState.confirmButtonFlash
							local normalIconColor = isSelected and colors.ui.background or colors.ui.foreground
							local targetIconColor = colors.ui.background

							-- Interpolate between normal icon color and background color
							local r = normalIconColor[1] + (targetIconColor[1] - normalIconColor[1]) * fadeAmount
							local g = normalIconColor[2] + (targetIconColor[2] - normalIconColor[2]) * fadeAmount
							local b = normalIconColor[3] + (targetIconColor[3] - normalIconColor[3]) * fadeAmount

							iconColor = { r, g, b }
						elseif isSelected and isValidHex(currentState.input) then
							-- If selected and valid, use background color for icon (for contrast with accent background)
							iconColor = colors.ui.background
						else
							-- Otherwise use full foreground color
							iconColor = colors.ui.foreground
						end

						-- Draw the icon centered on the button with SVG utility
						local centerX = x + width / 2
						local centerY = y + height / 2
						svg.drawIcon(icon, centerX, centerY, iconColor)
					end
				else
					-- Regular text button - set color for text
					love.graphics.setColor(colors.ui.foreground)
					if bodyFont then
						love.graphics.setFont(bodyFont)
						local textWidth = bodyFont:getWidth(buttonText)
						local textHeight = bodyFont:getHeight()
						love.graphics.print(buttonText, x + (width - textWidth) / 2, y + (height - textHeight) / 2)
					end
				end
			end
		end
	end

	love.graphics.pop()

	-- Draw controls
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
		{ button = "y", text = "Clear" },
		{ button = { "leftshoulder", "rightshoulder" }, text = "Tabs" },
	}
	controlHintsInstance:setControlsList(controlsList)

	controlHintsInstance:draw()
end

function hex.update(dt)
	-- Get current color type state
	local currentState = getCurrentHexState()

	-- Update confirm button animation
	if hexState.confirmButtonTween then
		local isComplete = hexState.confirmButtonTween:update(dt)
		if isComplete then
			if hexState.animationPhase == "expanding" then
				-- Start contracting phase
				hexState.animationPhase = "contracting"
				hexState.confirmButtonTween = tween.new(ANIMATION_DURATION, hexState, {
					confirmButtonScale = 1,
					confirmButtonFlash = 0,
				}, tween.easing.inQuad)
			else
				-- Animation fully complete
				hexState.confirmButtonTween = nil
				hexState.confirmButtonScale = 1
				hexState.confirmButtonFlash = 0
				hexState.animationPhase = "idle"
			end
		end
	end

	-- Start wobble animation only once when hex becomes valid
	if isValidHex(currentState.input) then
		-- Only trigger animation if this is a new valid input
		if currentState.input ~= hexState.lastValidInput and not hexState.confirmButtonTween then
			startConfirmButtonWobble()
			hexState.lastValidInput = currentState.input
		end
	else
		-- Reset animation and tracking if input becomes invalid
		if hexState.confirmButtonTween then
			hexState.confirmButtonTween = nil
			hexState.confirmButtonScale = 1
			hexState.confirmButtonFlash = 0
			hexState.animationPhase = "idle"
		end
		hexState.lastValidInput = ""
	end

	-- Handle D-pad navigation
	if InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_UP) then
		currentState.selectedButton.row = math.max(1, currentState.selectedButton.row - 1)
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_DOWN) then
		currentState.selectedButton.row = math.min(#buttons, currentState.selectedButton.row + 1)
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_LEFT) then
		currentState.selectedButton.col = currentState.selectedButton.col - 1
		if currentState.selectedButton.col < 1 then
			currentState.selectedButton.col = #buttons[currentState.selectedButton.row]
		end
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_RIGHT) then
		currentState.selectedButton.col = currentState.selectedButton.col + 1
		if currentState.selectedButton.col > #buttons[currentState.selectedButton.row] then
			currentState.selectedButton.col = 1
		end
	end

	-- Handle Y button for clear
	if InputManager.isActionPressed(InputManager.ACTIONS.CLEAR) then
		-- Clear all input
		currentState.input = ""
	end

	-- Handle button press (A button)
	if InputManager.isActionPressed(InputManager.ACTIONS.CONFIRM) then
		local selectedButton = buttons[currentState.selectedButton.row][currentState.selectedButton.col]

		if selectedButton == "BACKSPACE" then
			-- Backspace - remove last character
			if #currentState.input > 0 then
				currentState.input = currentState.input:sub(1, -2)
			end
		elseif selectedButton == "CONFIRM" then
			-- Confirm - only if input is valid
			if isValidHex(currentState.input) then
				-- Create hex code
				local hexCode = "#" .. currentState.input:upper()

				-- Store in central state
				local context = state.getColorContext(state.activeColorContext)
				context.currentColor = hexCode

				-- Return to menu and apply the color
				screens.switchTo(state.previousScreen)
				state.setColorValue(state.activeColorContext, hexCode)
			end
		else
			-- Add character if not at max length
			if #currentState.input < hexState.maxInputLength then
				currentState.input = currentState.input .. selectedButton
			end
		end
	end
end

-- Function to be called when entering this screen
function hex.onEnter()
	-- Preload icons if not already done
	if not svg.isIconLoaded("delete") or not svg.isIconLoaded("check") then
		svg.preloadIcons({ "delete", "check" }, ICON_SIZE)
	end

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

return hex
