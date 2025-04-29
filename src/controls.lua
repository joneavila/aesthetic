local love = require("love")
local state = require("state")
local colors = require("colors")
local controls = {}

-- Constants
local CONTROL_SPACING = 14 -- Horizontal spacing between different control groups
local SCREEN_EDGE_PADDING = 20 -- Padding from right edge of screen
local BUTTON_TEXT_SPACING = 4 -- Spacing used for separator between multiple buttons
local BUTTON_RADIUS = 4 -- Corner radius of button background
local BUTTON_HORIZONTAL_PADDING = 6 -- Horizontal padding inside button background
local BUTTON_VERTICAL_PADDING = 1 -- Vertical padding inside button background
local ACTION_TEXT_SPACING = 6 -- Space between button and action text
local CONTROL_BAR_VERTICAL_PADDING = 10 -- Additional padding for the control bar (top and bottom combined)

-- Function to calculate the HEIGHT based on font size and padding
function controls.calculateHeight()
	if state.fonts and state.fonts.caption then
		local fontHeight = state.fonts.caption:getHeight()
		controls.HEIGHT = fontHeight + (BUTTON_VERTICAL_PADDING * 2) + CONTROL_BAR_VERTICAL_PADDING
	end
	return controls.HEIGHT
end

-- Initialize HEIGHT
controls.HEIGHT = 42 -- Default value that will be recalculated when fonts are available

-- Button label mapping
local BUTTON_LABELS = {
	["a"] = "A",
	["b"] = "B",
	["x"] = "X",
	["y"] = "Y",
	["start"] = "Start",
	["d_pad"] = "D-pad",
	["leftshoulder"] = "L1",
	["l1"] = "L1",
	["rightshoulder"] = "R1",
	["r1"] = "R1",
	["menu"] = "Menu",
	["stick_l"] = "LS",
}

-- Draw the controls area at the bottom of the screen
-- Supports both single buttons (control.button = "a") and lists of buttons (control.button = {"l1", "r1"})
-- When a list of buttons is provided, they are drawn in sequence with a "/" separator between them
function controls.draw(controls_list)
	-- Ensure HEIGHT is calculated
	controls.calculateHeight()

	local globalColor = colors.ui.surface_dim

	-- Calculate total width needed for all controls
	local totalWidth = 0
	for i, control in ipairs(controls_list) do
		-- Uppercase the text for width calculation to match the displayed text
		local uppercaseText = string.upper(control.text)
		local textWidth = state.fonts.caption:getWidth(uppercaseText)
		local buttonsWidth = 0

		if type(control.button) == "table" then
			-- Multiple buttons with "/" between them
			for btn, buttonKey in ipairs(control.button) do
				local buttonLabel = BUTTON_LABELS[buttonKey] or buttonKey
				buttonLabel = string.upper(buttonLabel)
				local buttonTextWidth = state.fonts.caption:getWidth(buttonLabel)
				buttonsWidth = buttonsWidth + buttonTextWidth + (BUTTON_HORIZONTAL_PADDING * 2)

				-- Add width for "/" separator if not the last button
				if btn < #control.button then
					buttonsWidth = buttonsWidth + state.fonts.caption:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			-- Single button
			local buttonLabel = BUTTON_LABELS[control.button] or control.button
			buttonLabel = string.upper(buttonLabel)
			local buttonTextWidth = state.fonts.caption:getWidth(buttonLabel)
			buttonsWidth = buttonTextWidth + (BUTTON_HORIZONTAL_PADDING * 2)
		end

		totalWidth = totalWidth + buttonsWidth + textWidth + ACTION_TEXT_SPACING

		-- Add spacing between controls (except after the last one)
		if i < #controls_list then
			totalWidth = totalWidth + CONTROL_SPACING
		end
	end

	-- Start drawing from the right side, accounting for padding
	local x = state.screenWidth - totalWidth - SCREEN_EDGE_PADDING
	local y = state.screenHeight - controls.HEIGHT + (controls.HEIGHT - state.fonts.caption:getHeight()) / 2

	-- Draw each control
	for i, control in ipairs(controls_list) do
		if type(control.button) == "table" then
			-- Draw multiple buttons with "/" between them
			for btn, buttonKey in ipairs(control.button) do
				-- Get button label
				local buttonLabel = BUTTON_LABELS[buttonKey] or buttonKey
				buttonLabel = string.upper(buttonLabel)
				local buttonTextWidth = state.fonts.caption:getWidth(buttonLabel)
				local buttonHeight = state.fonts.caption:getHeight()

				-- Draw button background
				love.graphics.setColor(globalColor)
				love.graphics.rectangle(
					"fill",
					x,
					y - BUTTON_VERTICAL_PADDING,
					buttonTextWidth + (BUTTON_HORIZONTAL_PADDING * 2),
					buttonHeight + (BUTTON_VERTICAL_PADDING * 2),
					BUTTON_RADIUS,
					BUTTON_RADIUS
				)

				-- Draw button text
				love.graphics.setFont(state.fonts.caption)
				love.graphics.setColor(colors.ui.background)
				love.graphics.print(buttonLabel, x + BUTTON_HORIZONTAL_PADDING, y)

				x = x + buttonTextWidth + (BUTTON_HORIZONTAL_PADDING * 2)

				-- Draw separator if not the last button
				if btn < #control.button then
					love.graphics.setColor(globalColor)
					love.graphics.setFont(state.fonts.caption)
					love.graphics.print("/", x + BUTTON_TEXT_SPACING, y)
					x = x + state.fonts.caption:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			-- Draw single button background and text
			local buttonLabel = BUTTON_LABELS[control.button] or control.button
			buttonLabel = string.upper(buttonLabel)
			local buttonTextWidth = state.fonts.caption:getWidth(buttonLabel)
			local buttonHeight = state.fonts.caption:getHeight()

			-- Draw button background
			love.graphics.setColor(globalColor)
			love.graphics.rectangle(
				"fill",
				x,
				y - BUTTON_VERTICAL_PADDING,
				buttonTextWidth + (BUTTON_HORIZONTAL_PADDING * 2),
				buttonHeight + (BUTTON_VERTICAL_PADDING * 2),
				BUTTON_RADIUS,
				BUTTON_RADIUS
			)

			-- Draw button text
			love.graphics.setFont(state.fonts.caption)
			love.graphics.setColor(colors.ui.background)
			love.graphics.print(buttonLabel, x + BUTTON_HORIZONTAL_PADDING, y)

			x = x + buttonTextWidth + (BUTTON_HORIZONTAL_PADDING * 2)
		end

		-- Draw action text (with spacing)
		love.graphics.setColor(globalColor)
		love.graphics.setFont(state.fonts.caption)
		x = x + ACTION_TEXT_SPACING
		local uppercaseText = string.upper(control.text)
		love.graphics.print(uppercaseText, x, y)

		-- Move x position for next control
		local textWidth = state.fonts.caption:getWidth(uppercaseText)
		x = x + textWidth

		-- Add spacing between controls (except after the last one)
		if i < #controls_list then
			x = x + CONTROL_SPACING
		end
	end
end

return controls
