--- Control Hints System
--- Automatically displays control hints based on focused components and global context

local love = require("love")
local colors = require("colors")
local state = require("state")
local paths = require("paths")
local svg = require("utils.svg")
local fonts = require("ui.fonts")

local controlHints = {}

-- Constants
local CONTROL_SPACING = 14 -- Horizontal spacing between different control groups
local SCREEN_EDGE_PADDING = 16 -- Padding from edge of screen
local ACTION_TEXT_SPACING = 6 -- Space between button and action text
local CONTROL_BAR_TOP_PADDING = 0 -- Top padding for the control bar
local CONTROL_BAR_BOTTOM_PADDING = 16 -- Bottom padding for the control bar
local ALIGNMENT = "left" -- Controls alignment: "left" or "right"
local ICON_SIZE = 20 -- Size for control hint icons

-- Height calculation
controlHints.HEIGHT = 42 -- Default value

-- Internal state
local globalHints = {} -- Global hints that are always shown
local componentHints = {} -- Component-specific hints
local currentFocusedComponent = nil

-- Component type to hint mapping
local DEFAULT_HINTS = {
	-- Button hints based on type
	button_basic = { icon = "steam_button_a.svg", text = "SELECT" },
	button_color = { icon = "steam_button_a.svg", text = "SELECT" },
	button_gradient = { icon = "steam_button_a.svg", text = "SELECT" },
	button_text_preview = { icon = "steam_button_a.svg", text = "SELECT" },
	button_accented = { icon = "steam_button_a.svg", text = "SELECT" },
	button_indicators = { icon = "playstation_dpad_horizontal_outline.svg", text = "CYCLE" },
	-- List hints
	list = { icon = "playstation_dpad_vertical_outline.svg", text = "SCROLL" },
}

-- Function to calculate the HEIGHT based on font size and padding
function controlHints.calculateHeight()
	if fonts and fonts.loaded and fonts.loaded.caption then
		local fontHeight = fonts.loaded.caption:getHeight()
		controlHints.HEIGHT = fontHeight + CONTROL_BAR_TOP_PADDING + CONTROL_BAR_BOTTOM_PADDING
	end
	return controlHints.HEIGHT
end

-- Preload commonly used control hint icons
function controlHints.init()
	local iconNames = {
		"steam_button_a",
		"steam_button_b",
		"steam_button_start_icon",
		"steam_button_y",
		"steam_bumper_left",
		"steam_bumper_right",
		"playstation_dpad_horizontal_outline",
		"playstation_dpad_vertical_outline",
	}

	-- Preload icons from the control prompts directory
	for _, iconName in ipairs(iconNames) do
		svg.loadIcon(iconName, ICON_SIZE, paths.FOOTER_GLYPHS_SOURCE_DIR .. "/")
	end
end

-- Set global hints that are always shown regardless of focused component
function controlHints.setGlobalHints(hints)
	globalHints = hints or {}
end

-- Add a global hint
function controlHints.addGlobalHint(hint)
	table.insert(globalHints, hint)
end

-- Clear all global hints
function controlHints.clearGlobalHints()
	globalHints = {}
end

-- Register control hints for a specific component
function controlHints.registerComponent(component, hints)
	componentHints[component] = hints or {}
end

-- Unregister a component
function controlHints.unregisterComponent(component)
	componentHints[component] = nil
end

-- Set the currently focused component
function controlHints.setFocusedComponent(component)
	currentFocusedComponent = component
end

-- Get hints for a component based on its type
function controlHints.getDefaultHintsForComponent(component)
	if not component then
		return {}
	end

	local hints = {}

	-- Check if it's a button and get hints based on type
	if component.type then
		local buttonType = "button_" .. component.type
		local defaultHint = DEFAULT_HINTS[buttonType]
		if defaultHint then
			table.insert(hints, defaultHint)
		end
	elseif component.__index and component.__index.navigate then
		-- It's a list component
		local defaultHint = DEFAULT_HINTS.list
		if defaultHint then
			table.insert(hints, defaultHint)
		end
	end

	return hints
end

-- Get current control hints to display
function controlHints.getCurrentHints()
	local hints = {}
	local usedIcons = {} -- Track which icons are already used to prevent duplicates

	-- Add global hints first
	for _, hint in ipairs(globalHints) do
		table.insert(hints, hint)
		if hint.icon then
			usedIcons[hint.icon] = true
		end
	end

	-- Add component-specific hints if component is focused
	if currentFocusedComponent then
		-- Check for registered custom hints first
		local customHints = componentHints[currentFocusedComponent]
		if customHints and #customHints > 0 then
			for _, hint in ipairs(customHints) do
				-- Only add if this icon isn't already used by global hints
				if not hint.icon or not usedIcons[hint.icon] then
					table.insert(hints, hint)
				end
			end
		else
			-- Fall back to default hints based on component type
			local defaultHints = controlHints.getDefaultHintsForComponent(currentFocusedComponent)
			for _, hint in ipairs(defaultHints) do
				-- Only add if this icon isn't already used by global hints
				if not hint.icon or not usedIcons[hint.icon] then
					table.insert(hints, hint)
				end
			end
		end
	end

	return hints
end

-- Draw a single control hint (icon + text)
function controlHints.drawHint(hint, x, y)
	local iconWidth = 0

	-- Draw icon if provided
	if hint.icon then
		local icon = svg.loadIcon(hint.icon:gsub("%.svg$", ""), ICON_SIZE, paths.FOOTER_GLYPHS_SOURCE_DIR .. "/")
		if icon then
			-- Calculate icon position (centered vertically)
			local iconX = x + ICON_SIZE / 2
			local iconY = y + controlHints.HEIGHT / 2

			-- Draw icon
			svg.drawIcon(icon, iconX, iconY, colors.ui.surface_bright)
			iconWidth = ICON_SIZE
		end
	end

	-- Draw text if provided
	if hint.text then
		local textX = x + iconWidth + ACTION_TEXT_SPACING
		local textY = y + (controlHints.HEIGHT - fonts.loaded.caption:getHeight()) / 2

		love.graphics.setColor(colors.ui.surface_bright)
		love.graphics.setFont(fonts.loaded.caption)
		love.graphics.print(string.upper(hint.text), textX, textY)

		local textWidth = fonts.loaded.caption:getWidth(string.upper(hint.text))
		return iconWidth + ACTION_TEXT_SPACING + textWidth
	end

	return iconWidth
end

-- Draw all current control hints at the bottom of the screen
function controlHints.draw()
	-- Ensure HEIGHT is calculated
	controlHints.calculateHeight()

	local hints = controlHints.getCurrentHints()
	if #hints == 0 then
		return
	end

	-- Calculate total width needed for all hints
	local totalWidth = 0
	for i, hint in ipairs(hints) do
		-- Calculate icon width
		local iconWidth = 0
		if hint.icon then
			iconWidth = ICON_SIZE
		end

		-- Calculate text width
		local textWidth = 0
		if hint.text then
			textWidth = fonts.loaded.caption:getWidth(string.upper(hint.text))
		end

		totalWidth = totalWidth + iconWidth + ACTION_TEXT_SPACING + textWidth

		-- Add spacing between hints (except after the last one)
		if i < #hints then
			totalWidth = totalWidth + CONTROL_SPACING
		end
	end

	-- Set starting X position based on alignment
	local x
	if ALIGNMENT == "right" then
		x = state.screenWidth - totalWidth - SCREEN_EDGE_PADDING
	else -- left alignment
		x = SCREEN_EDGE_PADDING
	end

	local y = state.screenHeight - controlHints.HEIGHT + (controlHints.HEIGHT - fonts.loaded.caption:getHeight()) / 2

	-- Draw each hint
	for i, hint in ipairs(hints) do
		local hintWidth = controlHints.drawHint(hint, x, y)
		x = x + hintWidth

		-- Add spacing between hints (except after the last one)
		if i < #hints then
			x = x + CONTROL_SPACING
		end
	end
end

return controlHints
