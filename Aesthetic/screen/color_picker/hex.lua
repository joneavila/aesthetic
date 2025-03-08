--- Hex color picker screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")

local hex = {}

-- Store screen switching function
local switchScreen = nil

-- Constants
local EDGE_PADDING = 20
local TOP_PADDING = 20
local PREVIEW_HEIGHT = 80
local INPUT_HEIGHT = 60
local GRID_PADDING = 10
local LAST_COLUMN_EXTRA_PADDING = 20 -- Extra padding before the last column
local BUTTON_CORNER_RADIUS = 8
local BUTTON_OUTLINE_WIDTH = 2
local BUTTON_HOVER_OUTLINE_WIDTH = 4
local INPUT_RECT_WIDTH = 30
local INPUT_RECT_HEIGHT = 40
local INPUT_RECT_SPACING = 5
local ICON_SIZE = 24

-- Icon coloring shader
local iconShader = nil

-- State
local hexState = {
	input = "",
	selectedButton = { row = 1, col = 1 }, -- Default selection
	maxInputLength = 6,
}

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
		local path = "assets/icons/" .. name
		iconCache[name] = love.graphics.newImage(path)
	end
	return iconCache[name]
end

-- Helper function to draw an icon with the specified color
local function drawColoredIcon(icon, x, y, color, scale)
	-- Check if shader is available
	if not iconShader then
		-- Fallback to regular drawing if shader is not available
		love.graphics.setColor(color)
		love.graphics.draw(icon, x, y, 0, scale, scale)
		return
	end

	-- Save current shader
	local prevShader = love.graphics.getShader()

	-- Set our icon shader and its parameters
	love.graphics.setShader(iconShader)

	-- Ensure color values are valid
	local r = color[1] or 1
	local g = color[2] or 1
	local b = color[3] or 1
	local a = color[4] or 1

	-- Send color values to shader
	if iconShader.send then
		iconShader:send("tint", { r, g, b, a })
	end

	-- Draw the icon
	love.graphics.setColor(1, 1, 1, 1) -- Reset color to white for shader to work properly
	love.graphics.draw(icon, x, y, 0, scale, scale)

	-- Restore previous shader
	love.graphics.setShader(prevShader)
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

-- Helper function to convert hex string to RGB color
local function hexToRgb(hexString)
	local r = tonumber(hexString:sub(1, 2), 16) / 255
	local g = tonumber(hexString:sub(3, 4), 16) / 255
	local b = tonumber(hexString:sub(5, 6), 16) / 255
	return r, g, b
end

-- Helper function to get button dimensions
local function getButtonDimensions()
	local gridWidth = state.screenWidth - (2 * EDGE_PADDING) - LAST_COLUMN_EXTRA_PADDING
	local availableHeight = state.screenHeight
		- state.TAB_HEIGHT
		- TOP_PADDING
		- PREVIEW_HEIGHT
		- INPUT_HEIGHT
		- state.CONTROLS_HEIGHT
		- (2 * GRID_PADDING)

	local buttonWidth = (gridWidth - (4 * GRID_PADDING)) / 5
	local buttonHeight = (availableHeight - (3 * GRID_PADDING)) / 4

	return buttonWidth, buttonHeight
end

-- Helper function to get button position
local function getButtonPosition(row, col)
	local buttonWidth, buttonHeight = getButtonDimensions()
	local startX = EDGE_PADDING
	local startY = state.TAB_HEIGHT + TOP_PADDING + PREVIEW_HEIGHT + INPUT_HEIGHT + GRID_PADDING

	local x = startX + (col - 1) * (buttonWidth + GRID_PADDING)

	-- Add extra padding before the last column (special buttons)
	if col == 5 then
		x = x + LAST_COLUMN_EXTRA_PADDING
	end

	local y = startY + (row - 1) * (buttonHeight + GRID_PADDING)

	return x, y, buttonWidth, buttonHeight
end

function hex.load()
	-- Initialize state
	hexState.input = ""
	hexState.selectedButton = { row = 1, col = 1 }

	-- Create shader for icon coloring
	local success, result = pcall(function()
		return love.graphics.newShader([[
			extern vec4 tint;
			vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
				vec4 pixel = Texel(texture, texture_coords);
				// Use the alpha channel from the texture but the RGB from the tint
				return vec4(tint.rgb, pixel.a * tint.a);
			}
		]])
	end)

	if success then
		iconShader = result
	else
		print("Warning: Failed to create shader: " .. tostring(result))
		iconShader = nil
	end

	-- Preload icons
	-- Lucide icons were generated using stroke width 3px, size 48px.
	pcall(function()
		loadIcon("delete.png")
		loadIcon("trash.png")
		loadIcon("check.png")
	end)
end

function hex.draw()
	-- Set background
	love.graphics.setColor(colors.bg)
	love.graphics.clear()

	-- Draw color preview rectangle
	local previewX = EDGE_PADDING
	local previewY = state.TAB_HEIGHT + TOP_PADDING
	local previewWidth = state.screenWidth - (2 * EDGE_PADDING)

	-- Draw preview rectangle outline
	love.graphics.setColor(colors.fg)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", previewX, previewY, previewWidth, PREVIEW_HEIGHT, 8, 8)

	-- Fill with color if input is valid
	if isValidHex(hexState.input) then
		local r, g, b = hexToRgb(hexState.input)
		love.graphics.setColor(r, g, b)
		love.graphics.rectangle("fill", previewX, previewY, previewWidth, PREVIEW_HEIGHT, 8, 8)
	end

	-- Draw input indicator
	local inputStartX = previewX + (previewWidth - ((INPUT_RECT_WIDTH * 6) + (INPUT_RECT_SPACING * 5))) / 2
	local inputY = previewY + PREVIEW_HEIGHT + 10

	-- Draw # symbol
	love.graphics.setColor(colors.fg)
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
		local char = (i <= #hexState.input) and hexState.input:sub(i, i):upper() or "_"
		local charWidth = state.fonts.header:getWidth(char)
		local charX = rectX + (INPUT_RECT_WIDTH - charWidth) / 2

		love.graphics.setColor(colors.fg)
		love.graphics.print(char, charX, charY)
	end

	-- Draw button grid
	for row = 1, #buttons do
		for col = 1, #buttons[row] do
			local buttonText = buttons[row][col]
			if buttonText ~= "" then
				local x, y, width, height = getButtonPosition(row, col)
				local isSelected = (hexState.selectedButton.row == row and hexState.selectedButton.col == col)
				local isConfirmButton = (buttonText == "CONFIRM")
				local isConfirmDisabled = isConfirmButton and not isValidHex(hexState.input)

				-- Draw button background with transparency for disabled confirm button
				if isConfirmDisabled then
					love.graphics.setColor(0.2, 0.2, 0.2, 0.4) -- More transparent when disabled
				else
					love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
				end
				love.graphics.rectangle("fill", x, y, width, height, BUTTON_CORNER_RADIUS, BUTTON_CORNER_RADIUS)

				-- Draw button outline
				love.graphics.setLineWidth(isSelected and BUTTON_HOVER_OUTLINE_WIDTH or BUTTON_OUTLINE_WIDTH)
				if isConfirmDisabled then
					-- Use semi-transparent outline for disabled confirm button
					love.graphics.setColor(
						isSelected and { colors.fg[1], colors.fg[2], colors.fg[3], 0.5 } or { 0.5, 0.5, 0.5, 0.5 }
					)
				else
					love.graphics.setColor(isSelected and colors.fg or { 0.5, 0.5, 0.5 })
				end
				love.graphics.rectangle("line", x, y, width, height, BUTTON_CORNER_RADIUS, BUTTON_CORNER_RADIUS)

				-- Determine icon color - use semi-transparent if confirm button is disabled
				local iconColor
				if isConfirmDisabled then
					iconColor = { colors.fg[1], colors.fg[2], colors.fg[3], 0.5 }
				else
					iconColor = colors.fg
				end

				-- Special handling for icon buttons
				if buttonText == "BACKSPACE" then
					-- Backspace icon
					local success, icon = pcall(loadIcon, "delete.png")
					if success then
						local scale = ICON_SIZE / icon:getWidth()
						drawColoredIcon(
							icon,
							x + (width - ICON_SIZE) / 2,
							y + (height - ICON_SIZE) / 2,
							iconColor,
							scale
						)
					else
						-- Fallback to text if icon fails to load
						love.graphics.setColor(iconColor)
						love.graphics.setFont(state.fonts.body)
						local textWidth = state.fonts.body:getWidth("⌫")
						local textHeight = state.fonts.body:getHeight()
						love.graphics.print("⌫", x + (width - textWidth) / 2, y + (height - textHeight) / 2)
					end
				elseif buttonText == "CLEAR" then
					-- Trash icon
					local success, icon = pcall(loadIcon, "trash.png")
					if success then
						local scale = ICON_SIZE / icon:getWidth()
						drawColoredIcon(
							icon,
							x + (width - ICON_SIZE) / 2,
							y + (height - ICON_SIZE) / 2,
							iconColor,
							scale
						)
					else
						-- Fallback to text if icon fails to load
						love.graphics.setColor(iconColor)
						love.graphics.setFont(state.fonts.body)
						local textWidth = state.fonts.body:getWidth("🗑️")
						local textHeight = state.fonts.body:getHeight()
						love.graphics.print("🗑️", x + (width - textWidth) / 2, y + (height - textHeight) / 2)
					end
				elseif buttonText == "CONFIRM" then
					-- Check icon (confirm)
					local success, icon = pcall(loadIcon, "check.png")
					if success then
						local scale = ICON_SIZE / icon:getWidth()
						drawColoredIcon(
							icon,
							x + (width - ICON_SIZE) / 2,
							y + (height - ICON_SIZE) / 2,
							iconColor,
							scale
						)
					else
						-- Fallback to text if icon fails to load
						love.graphics.setColor(iconColor)
						love.graphics.setFont(state.fonts.body)
						local textWidth = state.fonts.body:getWidth("✅")
						local textHeight = state.fonts.body:getHeight()
						love.graphics.print("✅", x + (width - textWidth) / 2, y + (height - textHeight) / 2)
					end
				else
					-- Regular text button
					love.graphics.setColor(iconColor)
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
		{ icon = "l1.png", text = "Prev. Tab" },
		{ icon = "r1.png", text = "Next Tab" },
		{ icon = "d_pad.png", text = "Navigate" },
		{ icon = "a.png", text = "Select" },
		{ icon = "b.png", text = "Back" },
	})
end

function hex.update(_dt)
	if state.canProcessInput() then
		local virtualJoystick = require("input").virtualJoystick

		-- Handle D-pad navigation
		if virtualJoystick:isGamepadDown("dpup") then
			hexState.selectedButton.row = math.max(1, hexState.selectedButton.row - 1)

			-- Skip empty buttons
			while buttons[hexState.selectedButton.row][hexState.selectedButton.col] == "" do
				hexState.selectedButton.col = hexState.selectedButton.col - 1
				if hexState.selectedButton.col < 1 then
					hexState.selectedButton.col = #buttons[hexState.selectedButton.row]
				end
			end

			state.resetInputTimer()
		elseif virtualJoystick:isGamepadDown("dpdown") then
			hexState.selectedButton.row = math.min(#buttons, hexState.selectedButton.row + 1)

			-- Skip empty buttons
			while
				hexState.selectedButton.col > #buttons[hexState.selectedButton.row]
				or buttons[hexState.selectedButton.row][hexState.selectedButton.col] == ""
			do
				hexState.selectedButton.col =
					math.min(hexState.selectedButton.col, #buttons[hexState.selectedButton.row])
				if buttons[hexState.selectedButton.row][hexState.selectedButton.col] == "" then
					hexState.selectedButton.col = hexState.selectedButton.col - 1
				end
			end

			state.resetInputTimer()
		elseif virtualJoystick:isGamepadDown("dpleft") then
			hexState.selectedButton.col = hexState.selectedButton.col - 1
			if hexState.selectedButton.col < 1 then
				hexState.selectedButton.col = #buttons[hexState.selectedButton.row]
			end

			-- Skip empty buttons
			while buttons[hexState.selectedButton.row][hexState.selectedButton.col] == "" do
				hexState.selectedButton.col = hexState.selectedButton.col - 1
				if hexState.selectedButton.col < 1 then
					hexState.selectedButton.col = #buttons[hexState.selectedButton.row]
				end
			end

			state.resetInputTimer()
		elseif virtualJoystick:isGamepadDown("dpright") then
			hexState.selectedButton.col = hexState.selectedButton.col + 1
			if hexState.selectedButton.col > #buttons[hexState.selectedButton.row] then
				hexState.selectedButton.col = 1
			end

			-- Skip empty buttons
			while buttons[hexState.selectedButton.row][hexState.selectedButton.col] == "" do
				hexState.selectedButton.col = hexState.selectedButton.col + 1
				if hexState.selectedButton.col > #buttons[hexState.selectedButton.row] then
					hexState.selectedButton.col = 1
				end
			end

			state.resetInputTimer()
		end

		-- Handle button press (A button)
		if virtualJoystick:isGamepadDown("a") then
			local selectedButton = buttons[hexState.selectedButton.row][hexState.selectedButton.col]

			if selectedButton == "BACKSPACE" then
				-- Backspace - remove last character
				if #hexState.input > 0 then
					hexState.input = hexState.input:sub(1, -2)
				end
			elseif selectedButton == "CLEAR" then
				-- Clear - remove all characters
				hexState.input = ""
			elseif selectedButton == "CONFIRM" then
				-- Confirm - only if input is valid
				if isValidHex(hexState.input) and switchScreen then
					-- Set the custom color
					local r, g, b = hexToRgb(hexState.input)
					local colorKey = colors:addCustomColor(r, g, b)

					-- Return to menu and apply the color
					if switchScreen then
						switchScreen("menu")
						local menuScreen = require("screen.menu")
						menuScreen.setSelectedColor(state.lastSelectedColorButton, colorKey)
					end
				end
			else
				-- Add character if not at max length
				if #hexState.input < hexState.maxInputLength then
					hexState.input = hexState.input .. selectedButton
				end
			end

			state.resetInputTimer()
		end
	end
end

function hex.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

return hex
