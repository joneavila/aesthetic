local love = require("love")

local colors = require("colors")
local state = require("state")
local fonts = require("ui.fonts")
local svg = require("utils.svg")
local paths = require("paths")

local controlHints = {}

-- Constants
local CONTROL_SPACING = 12 -- Horizontal spacing between different control groups
local SCREEN_EDGE_PADDING = 16 -- Padding from edge of screen
local BUTTON_TEXT_SPACING = 2 -- Spacing used for separator between multiple buttons
local BUTTON_HORIZONTAL_PADDING = 4 -- Horizontal padding inside button background
local BUTTON_VERTICAL_PADDING = 2 -- Vertical padding inside button background
local ACTION_TEXT_SPACING = 2 -- Space between button and action text
local CONTROL_BAR_TOP_PADDING = 0 -- Top padding for the control bar
local CONTROL_BAR_BOTTOM_PADDING = 4 -- Bottom padding for the control bar
local ALIGNMENT = "right" -- Controls alignment: "left" or "right"
local ICON_SIZE = 20 -- Size for control hint icons'
local font = fonts.loaded.caption

local function titleCase(str)
	return str:gsub("(%a)([%w_']*)", function(first, rest)
		return first:upper() .. rest:lower()
	end)
end

-- Function to calculate the HEIGHT based on font size and padding
function controlHints.calculateHeight()
	local fontHeight = font:getHeight()
	controlHints.HEIGHT = fontHeight
		+ (BUTTON_VERTICAL_PADDING * 2)
		+ CONTROL_BAR_TOP_PADDING
		+ CONTROL_BAR_BOTTOM_PADDING

	return controlHints.HEIGHT
end

-- Initialize HEIGHT
controlHints.HEIGHT = 42 -- Default value that will be recalculated when fonts are available

-- Button to SVG icon mapping
local BUTTON_ICONS = {
	a = "steam_button_a",
	b = "steam_button_b",
	x = "steam_button_x",
	y = "steam_button_y",
	start = "steam_button_start_custom",
	d_pad = "playstation_dpad_all",
	leftshoulder = "playstation_trigger_l1",
	rightshoulder = "playstation_trigger_r1",
	menu = "steamdeck_button_menu_custom",
}

-- Helper to get icon for a button key
local function getButtonIcon(buttonKey)
	local iconName = BUTTON_ICONS[buttonKey]
	if iconName then
		return svg.loadIcon(iconName, ICON_SIZE, paths.CONTROL_HINTS_SOURCE_DIR .. "/")
	end
	return nil
end

-- Draw the controls area at the bottom of the screen
-- Supports both single buttons (control.button = "a") and lists of buttons
-- (control.button = {"leftshoulder", "rightshoulder"})
-- When a list of buttons is provided, they are drawn in sequence with a "/" separator between them
function controlHints.draw(controls_list)
	controlHints.calculateHeight()

	local color = colors.ui.subtext

	-- Calculate total width needed for all controls
	local totalWidth = 0
	for i, control in ipairs(controls_list) do
		-- Calculate the action text in title case
		local displayText = titleCase(control.text)
		local textWidth = font:getWidth(displayText)
		local buttonsWidth = 0

		if type(control.button) == "table" then
			for btn, buttonKey in ipairs(control.button) do
				local icon = getButtonIcon(buttonKey)
				if icon then
					buttonsWidth = buttonsWidth + ICON_SIZE + (BUTTON_HORIZONTAL_PADDING * 2)
				end
				if btn < #control.button then
					buttonsWidth = buttonsWidth + font:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			local icon = getButtonIcon(control.button)
			if icon then
				buttonsWidth = ICON_SIZE + (BUTTON_HORIZONTAL_PADDING * 2)
			end
		end

		totalWidth = totalWidth + buttonsWidth + ACTION_TEXT_SPACING + textWidth
		if i < #controls_list then
			totalWidth = totalWidth + CONTROL_SPACING
		end
	end

	-- Set starting X position based on alignment
	local x = SCREEN_EDGE_PADDING
	if ALIGNMENT == "right" then
		x = state.screenWidth - totalWidth - SCREEN_EDGE_PADDING
	end

	local y = state.screenHeight - controlHints.HEIGHT + (controlHints.HEIGHT - font:getHeight()) / 2

	for i, control in ipairs(controls_list) do
		if type(control.button) == "table" then
			for btn, buttonKey in ipairs(control.button) do
				local icon = getButtonIcon(buttonKey)
				svg.drawIcon(icon, x + BUTTON_HORIZONTAL_PADDING + ICON_SIZE / 2, y + ICON_SIZE / 2, color)
				x = x + ICON_SIZE + (BUTTON_HORIZONTAL_PADDING * 2)
				if btn < #control.button then
					love.graphics.setColor(color)
					love.graphics.setFont(font)
					love.graphics.print("/", x + BUTTON_TEXT_SPACING, y)
					x = x + font:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			local icon = getButtonIcon(control.button)
			svg.drawIcon(icon, x + BUTTON_HORIZONTAL_PADDING + ICON_SIZE / 2, y + ICON_SIZE / 2, color)
			x = x + ICON_SIZE + (BUTTON_HORIZONTAL_PADDING * 2)
		end

		-- Draw action text (with spacing)
		love.graphics.setColor(color)
		love.graphics.setFont(font)
		x = x + ACTION_TEXT_SPACING
		local displayText = titleCase(control.text)
		love.graphics.print(displayText, x, y - 2)
		x = x + font:getWidth(displayText)

		if i < #controls_list then
			x = x + CONTROL_SPACING
		end
	end
end

return controlHints
