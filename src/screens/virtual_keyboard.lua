local love = require("love")
local state = require("state")
local colors = require("colors")
local header = require("ui.header")
local controls = require("controls")
local background = require("ui.background")

-- Virtual keyboard screen module
local virtual_keyboard = {}

--[[
Navigation behavior:
- D-pad up/down/left/right navigates the keyboard grid
- When moving down from Row 4 to Row 5:
  * z/x keys → SHIFT key
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

-- Keyboard layout (QWERTY)
local keyboard = {
	-- Row 1: Digits
	{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
	-- Row 2: QWERTY
	{ "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
	-- Row 3: ASDF
	{ "a", "s", "d", "f", "g", "h", "j", "k", "l", "'" },
	-- Row 4: ZXCV with spacing
	{ "z", "x", "c", "v", "b", "n", "m", ".", ",", "/" },
	-- Row 5: Special keys
	{ "SHIFT", "SPACE", "OK" },
}

-- Key dimensions and layout
local keyWidth = 40
local keyHeight = 40
local keySpacing = 10
local keyboardX = 0
local keyboardY = 0
local inputFieldHeight = 50
local inputFieldPadding = 10

-- Initialize the keyboard position
local function initializeKeyboard()
	-- Center the keyboard horizontally
	local totalWidth = 0
	local maxRowLength = 0

	for _, row in ipairs(keyboard) do
		if #row > maxRowLength then
			maxRowLength = #row
		end
	end

	totalWidth = maxRowLength * keyWidth + (maxRowLength - 1) * keySpacing
	keyboardX = (state.screenWidth - totalWidth) / 2

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

-- Handle user input
function virtual_keyboard.update(dt)
	-- Handle controller input with cooldown to prevent multiple inputs
	local inputCooldown = 0.15
	local currentTime = love.timer.getTime()

	if not virtual_keyboard.lastInputTime then
		virtual_keyboard.lastInputTime = 0
	end

	if currentTime - virtual_keyboard.lastInputTime > inputCooldown then
		-- D-pad navigation
		if love.keyboard.isDown("up") then
			if selectedY == 5 then
				-- Moving up from the bottom row (special keys)
				if lastRow4X and lastRow4X >= 1 and lastRow4X <= #keyboard[4] then
					-- Return to previously selected position in Row 4 if valid
					selectedY = 4
					selectedX = lastRow4X
				else
					-- Fallback to default mapping if no previous position
					if selectedX == 1 then -- SHIFT
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
			virtual_keyboard.lastInputTime = currentTime
		elseif love.keyboard.isDown("down") then
			if selectedY == 4 then
				-- Save current position in Row 4 before moving to Row 5
				lastRow4X = selectedX

				-- Moving down from the letter/number rows to special keys
				if selectedX <= 2 then -- "z" or "x"
					selectedY = 5
					selectedX = 1 -- SHIFT
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
			virtual_keyboard.lastInputTime = currentTime
		elseif love.keyboard.isDown("left") then
			selectedX = math.max(1, selectedX - 1)
			virtual_keyboard.lastInputTime = currentTime
		elseif love.keyboard.isDown("right") then
			local maxX = #keyboard[selectedY]
			selectedX = math.min(maxX, selectedX + 1)
			virtual_keyboard.lastInputTime = currentTime
		end

		-- Ensure selectedX is valid for the current row
		if selectedX > #keyboard[selectedY] then
			selectedX = #keyboard[selectedY]
		end
	end
end

-- Handle key presses
function virtual_keyboard.keypressed(key)
	-- A button - select key
	if key == "return" or key == "z" then
		local selectedKey = keyboard[selectedY][selectedX]

		if selectedKey == "OK" then
			-- Return to previous screen with the input value
			if returnScreen and virtual_keyboard.switchScreen then
				print("Returning to " .. returnScreen .. " with value `" .. inputValue .. "`")
				virtual_keyboard.switchScreen(returnScreen, nil, inputValue)
			end
		elseif selectedKey == "SPACE" then
			inputValue = inputValue .. " "
		elseif selectedKey == "SHIFT" then
			-- Implement layer switching in the future
		elseif selectedKey == "BACKSPACE" then
			if #inputValue > 0 then
				inputValue = string.sub(inputValue, 1, -2)
			end
		elseif selectedKey ~= "" then
			inputValue = inputValue .. selectedKey
		end
	end

	-- B button - go back
	if key == "escape" or key == "x" then
		if returnScreen and virtual_keyboard.switchScreen then
			virtual_keyboard.switchScreen(returnScreen)
		end
	end

	-- X button - backspace
	if key == "backspace" or key == "c" then
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

			-- Skip empty keys
			if key ~= "" then
				-- Determine key width for special keys
				local actualKeyWidth = keyWidth
				if key == "SPACE" then
					actualKeyWidth = keyWidth * 5 + keySpacing * 4
				elseif key == "SHIFT" then
					actualKeyWidth = keyWidth * 2 + keySpacing
				elseif key == "OK" then
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

				-- Draw key text
				love.graphics.setColor(colors.ui.foreground)
				love.graphics.setFont(state.fonts.caption)

				local textX = posX + (actualKeyWidth - state.fonts.caption:getWidth(key)) / 2
				local textY = posY + (keyHeight - state.fonts.caption:getHeight()) / 2

				love.graphics.print(key, textX, textY)
			end

			-- Increment xOffset based on key width
			local keyStep = keyWidth + keySpacing
			if key == "SPACE" then
				xOffset = xOffset + keyWidth * 5 + keySpacing * 5
			elseif key == "SHIFT" then
				xOffset = xOffset + keyWidth * 2 + keySpacing * 2
			elseif key == "OK" then
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

-- Register key press handler with Love2D
function love.keypressed(key)
	local screens = require("screens")
	if screens.getCurrentScreen() == "virtual_keyboard" then
		virtual_keyboard.keypressed(key)
	end
end

return virtual_keyboard
