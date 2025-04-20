local love = require("love")
local state = require("state")
local colors = require("colors")
local controls = {}

-- Constants
controls.HEIGHT = 42
local PADDING = 14
local RIGHT_PADDING = 4
local BUTTON_TEXT_SPACING = 4
local SEPARATOR = " - " -- Separator between button and action text

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
	-- Set up graphics state
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.setFont(state.fonts.caption)

	-- Calculate total width needed for all controls
	local totalWidth = 0
	for _, control in ipairs(controls_list) do
		local textWidth = state.fonts.caption:getWidth(control.text)
		local buttonTextWidth = 0
		local separatorWidth = state.fonts.caption:getWidth(SEPARATOR)

		if type(control.button) == "table" then
			-- Multiple buttons with "/" between them
			for i, buttonKey in ipairs(control.button) do
				local buttonLabel = BUTTON_LABELS[buttonKey] or buttonKey
				buttonTextWidth = buttonTextWidth + state.fonts.caption:getWidth(buttonLabel)

				-- Add width for "/" separator if not the last button
				if i < #control.button then
					buttonTextWidth = buttonTextWidth + state.fonts.caption:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			-- Single button
			local buttonLabel = BUTTON_LABELS[control.button] or control.button
			buttonTextWidth = state.fonts.caption:getWidth(buttonLabel)
		end

		totalWidth = totalWidth + buttonTextWidth + separatorWidth + textWidth + PADDING
	end

	-- Start drawing from the right side, accounting for padding
	local x = state.screenWidth - totalWidth - RIGHT_PADDING
	local y = state.screenHeight - controls.HEIGHT + (controls.HEIGHT - state.fonts.caption:getHeight()) / 2

	-- Draw each control
	for _, control in ipairs(controls_list) do
		local startX = x

		if type(control.button) == "table" then
			-- Draw multiple buttons with "/" between them
			for i, buttonKey in ipairs(control.button) do
				-- Get button label
				local buttonLabel = BUTTON_LABELS[buttonKey] or buttonKey

				-- Draw button text
				love.graphics.print(buttonLabel, x, y)
				x = x + state.fonts.caption:getWidth(buttonLabel)

				-- Draw separator if not the last button
				if i < #control.button then
					love.graphics.print("/", x + BUTTON_TEXT_SPACING, y)
					x = x + state.fonts.caption:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			-- Draw single button text
			local buttonLabel = BUTTON_LABELS[control.button] or control.button
			love.graphics.print(buttonLabel, x, y)
			x = x + state.fonts.caption:getWidth(buttonLabel)
		end

		-- Draw separator between button and action text
		love.graphics.print(SEPARATOR, x, y)
		x = x + state.fonts.caption:getWidth(SEPARATOR)

		-- Draw action text
		love.graphics.print(control.text, x, y)

		-- Move x position for next control
		local textWidth = state.fonts.caption:getWidth(control.text)

		if type(control.button) == "table" then
			-- Calculate width for multiple buttons
			local buttonsWidth = 0
			for _, buttonKey in ipairs(control.button) do
				local buttonLabel = BUTTON_LABELS[buttonKey] or buttonKey
				buttonsWidth = buttonsWidth + state.fonts.caption:getWidth(buttonLabel)
			end

			-- Add width for separators
			for _ = 1, #control.button - 1 do
				buttonsWidth = buttonsWidth + state.fonts.caption:getWidth("/") + BUTTON_TEXT_SPACING * 2
			end

			x = startX + buttonsWidth + state.fonts.caption:getWidth(SEPARATOR) + textWidth + PADDING
		else
			-- Calculate width for single button
			local buttonLabel = BUTTON_LABELS[control.button] or control.button
			x = startX
				+ state.fonts.caption:getWidth(buttonLabel)
				+ state.fonts.caption:getWidth(SEPARATOR)
				+ textWidth
				+ PADDING
		end
	end
end

return controls
