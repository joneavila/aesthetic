local love = require("love")
local state = require("state")
local colors = require("colors")
local header = require("ui.header")
local controls = require("controls")
local background = require("ui.background")
local input = require("input")

-- Virtual keyboard screen module
local virtual_keyboard = {}

--[[
Navigation behavior:
- D-pad up/down/left/right navigates the keyboard grid
- When moving down from Row 4 to Row 5:
  * z/x keys → ABC key (layer switch)
  * c/v/b/n/m keys → SPACE key
  * ./,/ keys → OK key
- When moving up from Row 5 to Row 4, the keyboard returns to the last key position that was selected in Row 4
- If there's no remembered position, fallback mappings are used
]]

-- Screen state
local inputValue = ""
local headerTitle = "Input"
local selectedX = 1
local selectedY = 1
local returnScreen = nil
local callback = nil
local lastRow4X = nil -- Track the last X position in Row 4
local currentLayer = 1 -- Track current keyboard layer (1, 2, or 3)

-- Keyboard layouts for different layers
local keyboardLayouts = {
	-- Layer 1: Lowercase (QWERTY)
	{
		-- Row 1: Digits
		{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
		-- Row 2: QWERTY
		{ "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
		-- Row 3: ASDF
		{ "a", "s", "d", "f", "g", "h", "j", "k", "l", "'" },
		-- Row 4: ZXCV with spacing
		{ "z", "x", "c", "v", "b", "n", "m", ".", ",", "/" },
		-- Row 5: Special keys
		{ "ABC", "", "OK" },
	},
	-- Layer 2: Uppercase (QWERTY)
	{
		-- Row 1: Digits
		{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
		-- Row 2: QWERTY uppercase
		{ "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" },
		-- Row 3: ASDF uppercase
		{ "A", "S", "D", "F", "G", "H", "J", "K", "L", "'" },
		-- Row 4: ZXCV uppercase with spacing
		{ "Z", "X", "C", "V", "B", "N", "M", ".", ",", "/" },
		-- Row 5: Special keys
		{ "!@#", "", "OK" },
	},
	-- Layer 3: Symbols and special characters
	{
		-- Row 1: Symbols
		{ "!", "@", "#", "$", "%", "^", "&", "*", "(", ")" },
		-- Row 2: Symbols
		{ "`", "~", "_", "-", "+", "=", "{", "}", "[", "]" },
		-- Row 3: Symbols
		{ "|", "\\", ":", ";", '"', "'", "!", "@", "#", "?" },
		-- Row 4: Symbols
		{ "<", ">", ",", ".", "?", "/", "$", "?", "?", "?" },
		-- Row 5: Special keys
		{ "abc", "", "OK" },
	},
}

-- Variable to store the current keyboard layout
local keyboard = keyboardLayouts[1]

-- Function to switch keyboard layer
local function switchKeyboardLayer()
	currentLayer = currentLayer % 3 + 1 -- Cycle through layers 1, 2, 3
	keyboard = keyboardLayouts[currentLayer]
end

-- Key dimensions and layout
local keyWidth = 40
local keyHeight = 40
local keySpacing = 10
local keyboardX = 0
local keyboardY = 0
local inputFieldHeight = 50
local inputFieldPadding = 10
local screenPadding = 40 -- Padding from screen edges

-- Initialize the keyboard position
local function initializeKeyboard()
	-- Find the maximum row length
	local maxRowLength = 0
	for _, row in ipairs(keyboard) do
		if #row > maxRowLength then
			maxRowLength = #row
		end
	end

	-- Calculate key width based on available width
	local availableWidth = state.screenWidth - (screenPadding * 2)
	keyWidth = (availableWidth - ((maxRowLength - 1) * keySpacing)) / maxRowLength

	-- Make keys square by setting height equal to width
	keyHeight = keyWidth

	-- Position keyboard at left edge + padding
	keyboardX = screenPadding

	-- Position keyboard below input field
	keyboardY = header.getHeight() + inputFieldHeight + 30
end

-- Store the screen switcher function
function virtual_keyboard.setScreenSwitcher(switcher)
	virtual_keyboard.switchScreen = switcher
end

-- Load resources
function virtual_keyboard.load()
	-- Initialize keyboard positioning
	initializeKeyboard()
end

-- Handle screen entry
function virtual_keyboard.onEnter(params)
	-- Reset state
	inputValue = ""
	selectedX = 1
	selectedY = 1
	lastRow4X = nil -- Reset last Row 4 position
	currentLayer = 1 -- Reset to first layer
	keyboard = keyboardLayouts[currentLayer]

	-- Store parameters
	if params then
		headerTitle = params.title or "Input"
		returnScreen = params.returnScreen
		callback = params.callback
	end

	-- Re-initialize keyboard in case screen dimensions changed
	initializeKeyboard()
end

-- Handle screen exit
function virtual_keyboard.onExit()
	-- Clean up if needed
end

-- Handle key selection
local function handleKeySelection()
	local selectedKey = keyboard[selectedY][selectedX]

	if selectedKey == "OK" then
		-- Return to previous screen with the input value
		if returnScreen and virtual_keyboard.switchScreen then
			print("Returning to " .. returnScreen .. " with value `" .. inputValue .. "`")

			-- Pass both the preventImmediateInput flag AND the input value
			virtual_keyboard.switchScreen(returnScreen, {
				preventImmediateInput = true,
				inputValue = inputValue,
			})
		end
	elseif selectedKey == "" then
		-- Space key (empty text)
		inputValue = inputValue .. " "
	elseif selectedKey == "ABC" or selectedKey == "!@#" or selectedKey == "abc" then
		-- Layer switching
		switchKeyboardLayer()
	elseif selectedKey == "BACKSPACE" then
		if #inputValue > 0 then
			inputValue = string.sub(inputValue, 1, -2)
		end
	elseif selectedKey ~= "" then
		inputValue = inputValue .. selectedKey
	end
end

-- Handle user input
function virtual_keyboard.update(dt)
	local virtualJoystick = input.virtualJoystick

	-- D-pad navigation
	if virtualJoystick.isGamepadPressedWithDelay("dpup") then
		if selectedY == 5 then
			-- Moving up from the bottom row (special keys)
			if lastRow4X and lastRow4X >= 1 and lastRow4X <= #keyboard[4] then
				-- Return to previously selected position in Row 4 if valid
				selectedY = 4
				selectedX = lastRow4X
			else
				-- Fallback to default mapping if no previous position
				if selectedX == 1 then -- ABC/layer switch key
					selectedY = 4
					selectedX = 1 -- Jump to "z"
				elseif selectedX == 2 then -- SPACE
					selectedY = 4
					selectedX = 5 -- Jump to "b" (center of c,v,b,n,m)
				elseif selectedX == 3 then -- OK
					selectedY = 4
					selectedX = 9 -- Jump to "," (center of .,/)
				end
			end
		else
			-- Regular up movement for other rows
			selectedY = math.max(1, selectedY - 1)
		end
	elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
		if selectedY == 4 then
			-- Save current position in Row 4 before moving to Row 5
			lastRow4X = selectedX

			-- Moving down from the letter/number rows to special keys
			if selectedX <= 2 then -- "z" or "x"
				selectedY = 5
				selectedX = 1 -- ABC/layer switch key
			elseif selectedX >= 3 and selectedX <= 7 then -- "c", "v", "b", "n", "m"
				selectedY = 5
				selectedX = 2 -- SPACE
			elseif selectedX >= 8 then -- ".", ",", "/"
				selectedY = 5
				selectedX = 3 -- OK
			end
		else
			-- Regular down movement for other rows
			selectedY = math.min(#keyboard, selectedY + 1)
		end
	elseif virtualJoystick.isGamepadPressedWithDelay("dpleft") then
		selectedX = math.max(1, selectedX - 1)
	elseif virtualJoystick.isGamepadPressedWithDelay("dpright") then
		local maxX = #keyboard[selectedY]
		selectedX = math.min(maxX, selectedX + 1)
	end

	-- Ensure selectedX is valid for the current row
	if selectedX > #keyboard[selectedY] then
		selectedX = #keyboard[selectedY]
	end

	-- Button actions
	if virtualJoystick.isGamepadPressedWithDelay("a") then
		handleKeySelection()
	end

	-- B button - go back
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		if returnScreen and virtual_keyboard.switchScreen then
			virtual_keyboard.switchScreen(returnScreen)
		end
	end

	-- X button - backspace
	if virtualJoystick.isGamepadPressedWithDelay("x") then
		if #inputValue > 0 then
			inputValue = string.sub(inputValue, 1, -2)
		end
	end
end

-- Draw the virtual keyboard
function virtual_keyboard.draw()
	-- Draw background
	background.draw()

	-- Draw header
	header.draw(headerTitle)

	-- Draw input field
	love.graphics.setColor(colors.ui.surface)
	local inputFieldY = header.getHeight() + 10
	love.graphics.rectangle("fill", 40, inputFieldY, state.screenWidth - 80, inputFieldHeight, 5, 5)

	-- Draw input text
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(state.fonts.body)
	love.graphics.printf(
		inputValue,
		40 + inputFieldPadding,
		inputFieldY + (inputFieldHeight - state.fonts.body:getHeight()) / 2,
		state.screenWidth - 80 - (inputFieldPadding * 2),
		"left"
	)

	-- Draw keyboard
	for y, row in ipairs(keyboard) do
		local xOffset = 0
		for x, key in ipairs(row) do
			-- Calculate key position
			local posX = keyboardX + xOffset
			local posY = keyboardY + (y - 1) * (keyHeight + keySpacing)

			-- Draw all keys, including empty space key
			-- Determine key width for special keys
			local actualKeyWidth = keyWidth
			if x == 2 and y == 5 then -- SPACE (now checking by position instead of label)
				actualKeyWidth = keyWidth * 5 + keySpacing * 4
			elseif x == 1 and y == 5 then -- ABC/layer switch key
				actualKeyWidth = keyWidth * 2 + keySpacing
			elseif x == 3 and y == 5 then -- OK
				actualKeyWidth = keyWidth * 3 + keySpacing * 2
			elseif key == "BACKSPACE" then
				actualKeyWidth = keyWidth
			end

			-- Draw key background (highlighted if selected)
			if x == selectedX and y == selectedY then
				love.graphics.setColor(colors.ui.accent)
			else
				love.graphics.setColor(colors.ui.surface_dim)
			end

			love.graphics.rectangle("fill", posX, posY, actualKeyWidth, keyHeight, 5, 5)

			-- Draw key text, if it has any
			if key ~= "" then
				love.graphics.setColor(colors.ui.foreground)
				love.graphics.setFont(state.fonts.body)

				local textX = posX + (actualKeyWidth - state.fonts.body:getWidth(key)) / 2
				local textY = posY + (keyHeight - state.fonts.body:getHeight()) / 2

				love.graphics.print(key, textX, textY)
			end

			-- Increment xOffset based on key width
			local keyStep = keyWidth + keySpacing
			if x == 2 and y == 5 then -- SPACE
				xOffset = xOffset + keyWidth * 5 + keySpacing * 5
			elseif x == 1 and y == 5 then -- ABC/layer switch key
				xOffset = xOffset + keyWidth * 2 + keySpacing * 2
			elseif x == 3 and y == 5 then -- OK
				xOffset = xOffset + keyWidth * 3 + keySpacing * 3
			else
				xOffset = xOffset + keyStep
			end
		end
	end

	-- Draw controls
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Cancel" },
		{ button = "x", text = "Backspace" },
		{ button = "d_pad", text = "Navigate" },
	}
	controls.draw(controlsList)
end

-- The keypressed function is no longer needed since we're using the input module
-- This prevents duplicate input handling
function love.keypressed(key)
	-- Do nothing - input is now handled via input.virtualJoystick
end

return virtual_keyboard
