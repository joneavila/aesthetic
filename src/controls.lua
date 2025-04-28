local love = require("love")
local state = require("state")
local colors = require("colors")
local controls = {}

-- Constants
controls.HEIGHT = 42
local PADDING = 14
local RIGHT_PADDING = 4
local BUTTON_TEXT_SPACING = 4
local BUTTON_RADIUS = 4
local BUTTON_HORIZONTAL_PADDING = 8 -- Horizontal padding inside button background
local BUTTON_VERTICAL_PADDING = 2 -- Vertical padding inside button background
local ACTION_TEXT_SPACING = 6 -- Space between button and action text

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
	-- Calculate total width needed for all controls
	local totalWidth = 0
	for _, control in ipairs(controls_list) do
		local textWidth = state.fonts.caption:getWidth(control.text)
		local buttonsWidth = 0

		if type(control.button) == "table" then
			-- Multiple buttons with "/" between them
			for i, buttonKey in ipairs(control.button) do
				local buttonLabel = BUTTON_LABELS[buttonKey] or buttonKey
				local buttonTextWidth = state.fonts.caption:getWidth(buttonLabel)
				buttonsWidth = buttonsWidth + buttonTextWidth + (BUTTON_HORIZONTAL_PADDING * 2)

				-- Add width for "/" separator if not the last button
				if i < #control.button then
					buttonsWidth = buttonsWidth + state.fonts.caption:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			-- Single button
			local buttonLabel = BUTTON_LABELS[control.button] or control.button
			local buttonTextWidth = state.fonts.caption:getWidth(buttonLabel)
			buttonsWidth = buttonTextWidth + (BUTTON_HORIZONTAL_PADDING * 2)
		end

		totalWidth = totalWidth + buttonsWidth + textWidth + ACTION_TEXT_SPACING + PADDING
	end

	-- Start drawing from the right side, accounting for padding
	local x = state.screenWidth - totalWidth - RIGHT_PADDING
	local y = state.screenHeight - controls.HEIGHT + (controls.HEIGHT - state.fonts.caption:getHeight()) / 2

	-- Draw each control
	for _, control in ipairs(controls_list) do
		if type(control.button) == "table" then
			-- Draw multiple buttons with "/" between them
			for i, buttonKey in ipairs(control.button) do
				-- Get button label
				local buttonLabel = BUTTON_LABELS[buttonKey] or buttonKey
				local buttonTextWidth = state.fonts.caption:getWidth(buttonLabel)
				local buttonHeight = state.fonts.caption:getHeight()

				-- Draw button background
				love.graphics.setColor(colors.ui.overlay)
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
				if i < #control.button then
					love.graphics.setColor(colors.ui.overlay)
					love.graphics.setFont(state.fonts.caption)
					love.graphics.print("/", x + BUTTON_TEXT_SPACING, y)
					x = x + state.fonts.caption:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			-- Draw single button background and text
			local buttonLabel = BUTTON_LABELS[control.button] or control.button
			local buttonTextWidth = state.fonts.caption:getWidth(buttonLabel)
			local buttonHeight = state.fonts.caption:getHeight()

			-- Draw button background
			love.graphics.setColor(colors.ui.overlay)
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
		love.graphics.setColor(colors.ui.overlay)
		love.graphics.setFont(state.fonts.caption)
		x = x + ACTION_TEXT_SPACING
		love.graphics.print(control.text, x, y)

		-- Move x position for next control
		local textWidth = state.fonts.caption:getWidth(control.text)
		x = x + textWidth + PADDING
	end
end

return controls
