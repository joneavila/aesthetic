--- Main menu screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")

local menu = {}

local switchScreen = nil
local COLORPICKERPALETTE_SCREEN = "colorpickerpalette"
local ABOUT_SCREEN = "about"

-- Error handling
local errorMessage = nil
local ERROR_DISPLAY_TIME_SECONDS = 5
local errorTimer = 0

-- Popup state variables
local showPopup = false
local popupMessage = ""
local popupButtons = { {
	text = "Exit",
	selected = true,
}, {
	text = "Back",
	selected = false,
} }

local BOTTOM_PADDING = controls.HEIGHT

-- Button dimensions and position
local BUTTON = {
	WIDTH = nil, -- Will be calculated in load()
	HEIGHT = 50,
	PADDING = 40,
	CORNER_RADIUS = 8,
	SELECTED_OUTLINE_WIDTH = 4,
	COLOR_DISPLAY_SIZE = 30,
	START_Y = nil, -- Will be calculated in load()
	HELP_SIZE = 40, -- Size of the help button
	BOTTOM_MARGIN = 100, -- Margin from bottom for the "Create theme" button
}

-- Button state
local buttons = {
	{
		text = "Background color",
		selected = true,
		colorKey = "background",
	},
	{
		text = "Font",
		selected = false,
		fontSelection = true,
	},
	{
		text = "Create theme",
		selected = false,
		isBottomButton = true,
	},
	{
		text = "?",
		selected = false,
		isHelp = true,
	},
}

-- Constants for paths
local ORIGINAL_TEMPLATE_DIR = os.getenv("TEMPLATE_DIR") or "template" -- Store original template path
local WORKING_TEMPLATE_DIR = ORIGINAL_TEMPLATE_DIR .. "_working" -- Add working directory path
local THEME_OUTPUT_DIR = WORKING_TEMPLATE_DIR

-- Font options
local FONTS = {
	{
		name = "Inter",
		file = "inter.bin",
		selected = state.selectedFont == "Inter",
	},
	{
		name = "Nunito",
		file = "nunito.bin",
		selected = state.selectedFont == "Nunito",
	},
}

-- Function to set error message
local function setError(message)
	errorMessage = message
	errorTimer = ERROR_DISPLAY_TIME_SECONDS
	print("Error: " .. message) -- Also print to console for debugging
end

-- Helper function to escape pattern special characters
local function escapePattern(str)
	-- Escape these special characters: ^$()%.[]*+-?
	return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

-- Helper function to replace color in file
local function replaceColor(filepath, replacements)
	local file = io.open(filepath, "r")
	if not file then
		setError("Cannot read theme file: " .. filepath)
		return false
	end

	local content = file:read("*all")
	if not content then
		file:close()
		setError("Failed to read content from: " .. filepath .. "\nFile may be empty or corrupted")
		return false
	end
	file:close()

	-- Replace each color placeholder
	local newContent = content
	local totalReplacements = 0

	for placeholder, hexColor in pairs(replacements) do
		local escapedPlaceholder = escapePattern(placeholder)
		local pattern = "%%{" .. escapedPlaceholder .. "}"
		local count
		newContent, count = string.gsub(newContent, pattern, hexColor)
		totalReplacements = totalReplacements + count
	end

	-- Write updated content
	file = io.open(filepath, "w")
	if not file then
		setError("Cannot write to theme file: " .. filepath)
		return false
	end

	local success = file:write(newContent)
	file:close()

	if not success then
		setError("Failed to write updated content to: " .. filepath)
		return false
	end

	return true
end

-- Function to check if file exists
local function fileExists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end
	return false
end

-- Function to find next available filename
local function getNextAvailableFilename(basePath)
	-- Try without number first
	if not fileExists(basePath) then
		return basePath
	end

	-- Add numbers until an unused name is found
	local baseName = basePath:gsub("%.zip$", "")
	local i = 1
	while true do
		local newPath = string.format("%s (%d).zip", baseName, i)
		if not fileExists(newPath) then
			return newPath
		end
		i = i + 1
		local maxAttempts = 100
		if i > maxAttempts then
			setError("Failed to find available filename after " .. maxAttempts .. " attempts")
			return nil
		end
	end
end

-- Helper function to create ZIP archive
local function createZipArchive(sourceDir, outputPath)
	-- Validate inputs
	if not sourceDir or not outputPath then
		setError("Invalid arguments to createZipArchive")
		return false
	end

	-- Get next available filename
	local finalPath = getNextAvailableFilename(outputPath)
	if not finalPath then
		setError("Failed to get available filename")
		return false
	end

	-- Use zip command line tool with error capture
	local cmd = string.format('cd "%s" && zip -r "%s" *', sourceDir, finalPath)
	local handle = io.popen(cmd .. " 2>&1")
	if not handle then
		setError("Failed to execute zip command")
		return false
	end

	local result = handle:read("*a")
	if not result then
		handle:close()
		setError("Failed to read command output")
		return false
	end

	local success = handle:close()
	if not success then
		setError("ZIP command failed: " .. result)
		return false
	end

	return true
end

-- Helper function to copy directory contents
local function copyDir(src, dest)
	-- Create destination directory
	os.execute('mkdir -p "' .. dest .. '"')

	-- Copy all contents from source to destination
	local cmd = string.format('cp -r "%s/"* "%s/"', src, dest)
	local success = os.execute(cmd)

	return success == 0 or success == true
end

-- Function to create a preview image with the selected background color and "muOS" text
local function createPreviewImage(outputPath, colorKey)
	-- Image dimensions
	local width, height = 288, 216

	-- Create a new image data object
	local imageData = love.image.newImageData(width, height)

	-- Get the background color
	local bgColor = colors[colorKey] or colors.bg

	-- Fill the image with the background color
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			imageData:setPixel(x, y, bgColor[1], bgColor[2], bgColor[3], 1)
		end
	end

	-- Create a canvas to draw text on the image
	local canvas = love.graphics.newCanvas(width, height)
	love.graphics.setCanvas(canvas)

	-- Clear the canvas with the background color
	love.graphics.clear(bgColor[1], bgColor[2], bgColor[3], 1)

	local selectedFontName = state.selectedFont

	-- Draw "muOS" text in white, centered
	love.graphics.setColor(1, 1, 1, 1) -- White color

	-- Use the selected font for the preview
	if selectedFontName == "Inter" then
		love.graphics.setFont(state.fonts.body)
	else
		love.graphics.setFont(state.fonts.nunito)
	end

	local text = "muOS"
	local textWidth = love.graphics.getFont():getWidth(text)
	local textHeight = love.graphics.getFont():getHeight()
	love.graphics.print(text, (width - textWidth) / 2, (height - textHeight) / 2)

	-- Reset canvas
	love.graphics.setCanvas()

	-- Get image data from canvas
	local canvasData = canvas:newImageData()

	-- Encode the image data as PNG
	local fileData = canvasData:encode("png")

	-- Save to a temporary file in the save directory first
	local tempFilename = "preview_temp.png"
	local success, message = love.filesystem.write(tempFilename, fileData:getString())

	if not success then
		print("Failed to save temporary preview image: " .. (message or "unknown error"))
		return false
	end

	-- Get the full path to the temporary file
	local tempPath = love.filesystem.getSaveDirectory() .. "/" .. tempFilename

	-- Move the temporary file to the final location
	local cmd = string.format('cp "%s" "%s"', tempPath, outputPath)
	local result = os.execute(cmd)

	-- Clean up the temporary file
	love.filesystem.remove(tempFilename)

	return result == 0 or result == true
end

-- Function to create theme
local function createTheme()
	-- Clean up any existing working directory
	os.execute('rm -rf "' .. WORKING_TEMPLATE_DIR .. '"')

	-- Create fresh copy of template
	if not copyDir(ORIGINAL_TEMPLATE_DIR, WORKING_TEMPLATE_DIR) then
		setError("Failed to prepare working template directory")
		return false
	end

	-- Convert selected colors to hex
	local hexColors = {}
	local colorMappings = {
		background = state.colors.background,
		foreground = state.colors.foreground,
	}

	for key, color in pairs(colorMappings) do
		local hex = colors.toHex(color)
		if not hex then
			setError("Could not convert color to hex: " .. color)
			return false
		end
		hexColors[key] = hex:gsub("^#", "") -- Remove the # from hex colors
	end

	-- Replace colors in both theme files
	local themeFiles = { THEME_OUTPUT_DIR .. "/scheme/default.txt" }

	for _, filepath in ipairs(themeFiles) do
		if not replaceColor(filepath, hexColors) then
			print("Failed to update: " .. filepath)
			return false
		end
	end

	-- Find the selected font file based on state.selectedFont
	local selectedFontFile = nil
	for _, font in ipairs(FONTS) do
		if font.name == state.selectedFont then
			selectedFontFile = font.file
			break
		end
	end

	-- Copy the selected font file as default.bin
	if selectedFontFile then
		local fontSourcePath = ORIGINAL_TEMPLATE_DIR .. "/font/" .. selectedFontFile
		local fontDestPath = THEME_OUTPUT_DIR .. "/font/default.bin"

		-- Ensure the font directory exists
		os.execute('mkdir -p "' .. THEME_OUTPUT_DIR .. '/font"')

		-- Remove any existing default.bin that might have been copied from the template
		os.execute('rm -f "' .. fontDestPath .. '"')

		-- Copy the selected font file as default.bin
		local cmd = string.format('cp "%s" "%s"', fontSourcePath, fontDestPath)
		local success = os.execute(cmd)

		if not (success == 0 or success == true) then
			setError("Failed to copy font file: " .. selectedFontFile)
			return false
		end
	else
		setError("No font selected")
		return false
	end

	-- Create preview image
	local previewPath = THEME_OUTPUT_DIR .. "/preview.png"

	-- Ensure the directory exists
	local previewDir = string.match(previewPath, "(.*)/[^/]*$")
	if previewDir then
		os.execute('mkdir -p "' .. previewDir .. '"')
	end

	-- Remove any existing preview image that might have been copied from the template
	os.execute('rm -f "' .. previewPath .. '"')

	local success = createPreviewImage(previewPath, state.colors.background)
	if not success then
		setError("Failed to create preview image")
		return false
	end

	-- Try SD card location first
	local sdcardThemeDir = "/mnt/sdcard/MUOS/theme"
	local outputPath = sdcardThemeDir .. "/Custom Theme.zip"

	-- Try to create SD card directory
	os.execute('mkdir -p "' .. sdcardThemeDir .. '"')

	-- Attempt to write to SD card first
	local success = createZipArchive(THEME_OUTPUT_DIR, outputPath)
	if success then
		return true -- If SD card write succeeds, we're done
	end

	-- If SD card fails, try internal storage
	local themeDir = os.getenv("THEME_DIR")
	if not themeDir then
		setError("THEME_DIR environment variable not set")
		return false
	end

	-- Create and move ZIP archive to internal storage
	outputPath = themeDir .. "/Custom Theme.zip"
	success = createZipArchive(THEME_OUTPUT_DIR, outputPath)

	if not success then
		setError("Failed to create theme archive in both SD card and internal storage")
		return false
	end

	return true
end

function menu.load()
	BUTTON.WIDTH = state.screenWidth - (BUTTON.PADDING * 2)

	-- Count regular buttons (not "Help" or "Create theme" button)
	local regularButtonCount = 0
	for _, button in ipairs(buttons) do
		if not button.isHelp and not button.isBottomButton then
			regularButtonCount = regularButtonCount + 1
		end
	end

	-- Calculate total height needed for regular buttons
	local totalButtonHeight = (regularButtonCount * BUTTON.HEIGHT) + ((regularButtonCount - 1) * BUTTON.PADDING)
	local availableHeight = state.screenHeight - BOTTOM_PADDING - BUTTON.BOTTOM_MARGIN
	local topMargin = (availableHeight - totalButtonHeight) / 2
	BUTTON.START_Y = topMargin

	-- Initialize font selection based on state
	for _, font in ipairs(FONTS) do
		font.selected = (font.name == state.selectedFont)
	end
end

local function drawButton(button, x, y, isSelected)
	if button.isHelp then
		-- Draw help button as a circle
		local radius = BUTTON.HELP_SIZE / 2

		-- Draw button background
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], isSelected and 0.3 or 0.2)
		love.graphics.circle("fill", x + radius, y + radius, radius)

		-- Draw button outline
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], isSelected and 1 or 0.5)
		love.graphics.setLineWidth(isSelected and BUTTON.SELECTED_OUTLINE_WIDTH or 2)
		love.graphics.circle("line", x + radius, y + radius, radius)

		-- Draw question mark
		love.graphics.setFont(state.fonts.body)
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
		local textWidth = state.fonts.body:getWidth("?")
		local textHeight = state.fonts.body:getHeight()
		love.graphics.print("?", x + radius - textWidth / 2, y + radius - textHeight / 2)
		return
	end

	-- Draw button background
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 0.2)
	love.graphics.rectangle("fill", x, y, BUTTON.WIDTH, BUTTON.HEIGHT, BUTTON.CORNER_RADIUS)

	-- Draw button outline (thicker if selected)
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], isSelected and 1 or 0.5)
	love.graphics.setLineWidth(isSelected and BUTTON.SELECTED_OUTLINE_WIDTH or 2)
	love.graphics.rectangle("line", x, y, BUTTON.WIDTH, BUTTON.HEIGHT, BUTTON.CORNER_RADIUS)

	-- Draw button text
	love.graphics.setFont(state.fonts.body)
	local textHeight = state.fonts.body:getHeight()
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
	love.graphics.print(button.text, x + 20, y + (BUTTON.HEIGHT - textHeight) / 2)

	-- If this is a color selection button
	if button.colorKey then
		-- Get the color from state
		local selectedColor = state.colors[button.colorKey]

		-- Only draw color display if we have a valid color
		if selectedColor and colors[selectedColor] then
			-- Draw color square on the right side of the button
			local colorX = x + BUTTON.WIDTH - BUTTON.COLOR_DISPLAY_SIZE - 20
			local colorY = y + (BUTTON.HEIGHT - BUTTON.COLOR_DISPLAY_SIZE) / 2

			-- Draw color square
			love.graphics.setColor(colors[selectedColor][1], colors[selectedColor][2], colors[selectedColor][3], 1)
			love.graphics.rectangle("fill", colorX, colorY, BUTTON.COLOR_DISPLAY_SIZE, BUTTON.COLOR_DISPLAY_SIZE, 4)

			-- Draw border around color square
			love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
			love.graphics.setLineWidth(1)
			love.graphics.rectangle("line", colorX, colorY, BUTTON.COLOR_DISPLAY_SIZE, BUTTON.COLOR_DISPLAY_SIZE, 4)

			-- Draw color name
			local nameWidth = state.fonts.body:getWidth(colors.names[selectedColor])
			love.graphics.print(
				colors.names[selectedColor],
				colorX - nameWidth - 10,
				y + (BUTTON.HEIGHT - textHeight) / 2
			)
		end
	-- If this is a font selection button
	elseif button.fontSelection then
		-- Get the selected font name from state
		local selectedFontName = state.selectedFont

		-- Calculate the right edge position
		local rightEdge = x + BUTTON.WIDTH - 20

		-- Use the appropriate font for measurement and display
		if selectedFontName == "Inter" then
			love.graphics.setFont(state.fonts.body)
		else
			love.graphics.setFont(state.fonts.nunito)
		end

		-- Calculate font name width for positioning
		local fontNameWidth = love.graphics.getFont():getWidth(selectedFontName)

		-- Calculate positions for all elements
		local arrowWidth = 10
		local arrowSpacing = 15

		-- Fix: Add extra spacing to the right arrow to balance the visual gaps
		local rightArrowExtraSpacing = 8

		-- Position elements at the right edge
		local arrowY = y + (BUTTON.HEIGHT / 2)

		-- Calculate total width needed
		local totalWidth = fontNameWidth + (2 * arrowSpacing) + rightArrowExtraSpacing + (2 * arrowWidth)

		-- Calculate starting position from right edge
		local startX = rightEdge - totalWidth

		-- Position each element with exact spacing
		local leftArrowX = startX
		local fontNameX = leftArrowX + arrowWidth + arrowSpacing
		local rightArrowX = fontNameX + fontNameWidth + arrowSpacing + rightArrowExtraSpacing

		local fontNameY = y + (BUTTON.HEIGHT - love.graphics.getFont():getHeight()) / 2

		-- Draw left arrow
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
		love.graphics.polygon(
			"fill",
			leftArrowX,
			arrowY,
			leftArrowX + arrowWidth,
			arrowY - arrowWidth,
			leftArrowX + arrowWidth,
			arrowY + arrowWidth
		)

		-- Draw font name
		love.graphics.print(selectedFontName, fontNameX, fontNameY)

		-- Draw right arrow
		love.graphics.polygon(
			"fill",
			rightArrowX,
			arrowY,
			rightArrowX - arrowWidth,
			arrowY - arrowWidth,
			rightArrowX - arrowWidth,
			arrowY + arrowWidth
		)

		-- Reset font
		love.graphics.setFont(state.fonts.body)
	end
end

-- Popup drawing function
local function drawPopup()
	-- Draw semi-transparent background
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)

	-- Calculate popup dimensions based on text
	local padding = 40
	local maxWidth = state.screenWidth * 0.9 -- Maximum width is 90% of screen width
	local minWidth = math.min(state.screenWidth * 0.8, maxWidth) -- Minimum width is 80% of screen width, but not more than maxWidth
	local minHeight = state.screenHeight * 0.3

	-- Set font for text measurement
	love.graphics.setFont(state.fonts.body)

	-- Calculate available width for text
	local availableTextWidth = minWidth - (padding * 2)

	-- Get wrapped text info
	local _, lines = state.fonts.body:getWrap(popupMessage, availableTextWidth)
	local textHeight = #lines * state.fonts.body:getHeight()

	-- Calculate final popup dimensions
	local popupWidth = minWidth -- Always use the minimum width to ensure consistent wrapping
	local popupHeight = math.max(minHeight, textHeight + (padding * 4) + 50) -- Extra space for buttons

	local x = (state.screenWidth - popupWidth) / 2
	local y = (state.screenHeight - popupHeight) / 2

	-- Draw popup background
	love.graphics.setColor(colors.bg[1], colors.bg[2], colors.bg[3], 1)
	love.graphics.rectangle("fill", x, y, popupWidth, popupHeight, 10)

	-- Draw popup border
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, popupWidth, popupHeight, 10)

	-- Draw message with wrapping
	local textY = y + padding
	love.graphics.printf(popupMessage, x + padding, textY, availableTextWidth, "center")

	-- Draw buttons
	local buttonWidth = 150
	local buttonHeight = 40
	local buttonY = y + popupHeight - buttonHeight - padding
	local spacing = 20
	local totalButtonsWidth = (#popupButtons * buttonWidth) + ((#popupButtons - 1) * spacing)
	local buttonX = (state.screenWidth - totalButtonsWidth) / 2

	for _, button in ipairs(popupButtons) do
		-- Draw button background
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], button.selected and 0.3 or 0.1)
		love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

		-- Draw button border
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], button.selected and 1 or 0.5)
		love.graphics.setLineWidth(button.selected and 3 or 1)
		love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5)

		-- Draw button text
		love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 1)
		love.graphics.printf(
			button.text,
			buttonX,
			buttonY + (buttonHeight - state.fonts.body:getHeight()) / 2,
			buttonWidth,
			"center"
		)

		buttonX = buttonX + buttonWidth + spacing
	end
end

function menu.draw()
	-- Set background
	love.graphics.setColor(colors.bg)
	love.graphics.clear()

	-- Draw regular buttons
	local regularButtonCount = 0
	for i, button in ipairs(buttons) do
		if not button.isHelp and not button.isBottomButton then
			local y = BUTTON.START_Y + regularButtonCount * (BUTTON.HEIGHT + BUTTON.PADDING)
			drawButton(button, BUTTON.PADDING, y, button.selected)
			regularButtonCount = regularButtonCount + 1
		end
	end

	-- Draw "Create theme" button at the bottom
	for _, button in ipairs(buttons) do
		if button.isBottomButton then
			local y = state.screenHeight - BUTTON.BOTTOM_MARGIN
			drawButton(button, BUTTON.PADDING, y, button.selected)
			break
		end
	end

	-- Draw help button in top right
	local helpButton = nil
	for _, button in ipairs(buttons) do
		if button.isHelp then
			helpButton = button
			break
		end
	end

	if helpButton then
		drawButton(
			helpButton,
			state.screenWidth - BUTTON.PADDING - BUTTON.HELP_SIZE,
			BUTTON.PADDING,
			helpButton.selected
		)
	end

	-- Draw error message if present
	if errorMessage then
		love.graphics.push()

		-- Use a smaller font
		local smallFont = love.graphics.newFont(14)
		love.graphics.setFont(smallFont)

		-- Calculate dimensions for error box
		local padding = 10
		local maxWidth = state.screenWidth - (padding * 2)

		-- Wrap the text
		local wrappedText = love.graphics.newText(smallFont)
		wrappedText:setf(errorMessage, maxWidth, "left")
		local textHeight = wrappedText:getHeight()

		-- Draw semi-transparent background
		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.rectangle("fill", padding, padding, maxWidth, textHeight + (padding * 2))

		-- Draw error text
		love.graphics.setColor(1, 0.3, 0.3, 1) -- Red-ish color
		love.graphics.draw(wrappedText, padding * 2, padding * 2)

		love.graphics.pop()
	end

	-- Draw popup if active
	if showPopup then
		drawPopup()
	end

	controls.draw({
		{
			icon = "d_pad.png",
			text = "Navigate",
		},
		{
			icon = "a.png",
			text = "Select",
		},
		{
			icon = "b.png",
			text = "Exit",
		},
	})
end

function menu.update(dt)
	if showPopup then
		if state.canProcessInput() then
			local virtualJoystick = require("input").virtualJoystick

			-- Handle navigation
			if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
				for _, button in ipairs(popupButtons) do
					button.selected = not button.selected
				end
				state.resetInputTimer()
			end

			-- Handle selection
			if virtualJoystick:isGamepadDown("a") then
				for _, button in ipairs(popupButtons) do
					if button.selected then
						if button.text == "Exit" then
							love.event.quit()
						else
							showPopup = false
						end
						break
					end
				end
				state.resetInputTimer()
			end
		end
		return -- Don't process other input while popup is shown
	end

	if state.canProcessInput() then
		local virtualJoystick = require("input").virtualJoystick
		local moved = false

		-- Get ordered list of buttons for navigation (excluding help button)
		local navButtons = {}
		local helpButton = nil

		-- First add regular buttons
		for _, button in ipairs(buttons) do
			if not button.isHelp and not button.isBottomButton then
				table.insert(navButtons, button)
			elseif button.isHelp then
				helpButton = button
			end
		end

		-- Then add "Create theme" button
		for _, button in ipairs(buttons) do
			if button.isBottomButton then
				table.insert(navButtons, button)
				break
			end
		end

		-- Add help button
		if helpButton then
			table.insert(navButtons, helpButton)
		end

		-- Handle navigation
		if virtualJoystick:isGamepadDown("dpup") then
			for i, button in ipairs(navButtons) do
				if button.selected then
					button.selected = false
					if i > 1 then
						navButtons[i - 1].selected = true
					else
						navButtons[#navButtons].selected = true -- Wrap to last button
					end
					moved = true
					break
				end
			end
		elseif virtualJoystick:isGamepadDown("dpdown") then
			for i, button in ipairs(navButtons) do
				if button.selected then
					button.selected = false
					if i < #navButtons then
						navButtons[i + 1].selected = true
					else
						navButtons[1].selected = true -- Wrap to first button
					end
					moved = true
					break
				end
			end
		elseif virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
			-- Check if a font selection button is selected
			for _, button in ipairs(buttons) do
				if button.selected and button.fontSelection then
					-- Find the currently selected font
					local currentIndex = 1
					for i, font in ipairs(FONTS) do
						if font.selected then
							currentIndex = i
							font.selected = false
							break
						end
					end

					-- Calculate the next font index based on direction
					local nextIndex = currentIndex
					if virtualJoystick:isGamepadDown("dpleft") then
						nextIndex = currentIndex - 1
						if nextIndex < 1 then
							nextIndex = #FONTS
						end
					else -- dpright
						nextIndex = currentIndex + 1
						if nextIndex > #FONTS then
							nextIndex = 1
						end
					end

					-- Select the new font
					FONTS[nextIndex].selected = true
					state.selectedFont = FONTS[nextIndex].name
					moved = true
					break
				end
			end
		end

		-- Handle exit
		if virtualJoystick:isGamepadDown("b") then
			love.event.quit()
			return
		end

		-- Reset input timer if moved
		if moved then
			state.resetInputTimer()
		end

		-- Check for selection
		if virtualJoystick:isGamepadDown("a") then
			-- Find which button is selected
			for _, button in ipairs(buttons) do
				if button.selected then
					if button.isHelp then
						if switchScreen then
							switchScreen(ABOUT_SCREEN)
							state.resetInputTimer()
						end
					elseif button.colorKey then
						-- Any color selection button
						if switchScreen then
							state.lastSelectedButton = button.colorKey
							switchScreen(COLORPICKERPALETTE_SCREEN)
							state.resetInputTimer()
						end
					elseif button.text == "Create theme" then
						-- Start theme creation
						local success = createTheme()

						-- Show result popup
						showPopup = true
						if success then
							popupMessage =
								"Success! After exiting, apply your theme via Configuration > Customisation > muOS Themes."
						else
							popupMessage = "Error creating theme."
						end
					end
					break
				end
			end
		end
	end

	-- Update error timer
	if errorMessage and errorTimer > 0 then
		errorTimer = errorTimer - dt
		if errorTimer <= 0 then
			errorMessage = nil
		end
	end
end

function menu.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function menu.setSelectedColor(buttonType, colorKey)
	if state.colors[buttonType] then
		state.colors[buttonType] = colorKey
	end
end

function menu.onExit()
	-- Clean up working directory when leaving menu screen
	os.execute('rm -rf "' .. WORKING_TEMPLATE_DIR .. '"')
end

return menu
