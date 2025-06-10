--- Status Settings Screen
-- NOTE: The status screen (status.lua) and navigation screen (navigation.lua) share layout,
-- so any changes made here should be made to the other screen.
local love = require("love")

local colors = require("colors")
local controls = require("control_hints")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")

local statusScreen = {}

-- UI Components
local alignmentButton = nil
local input = nil

-- Constants
local EDGE_PADDING = 18
local COMPONENT_SPACING = 10
local WARNING_TEXT = "Note: Status alignment setting may conflict with time alignment and header alignment settings."
local WARNING_TEXT_FONT = fonts.loaded.caption

-- Add menuList variable
local menuList = nil

-- Create the alignment selection button
local function createAlignmentButton()
	local alignmentOptions = { "Left", "Center", "Right" }
	local currentIndex = ({ ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 })[state.statusAlignment] or 1

	return Button:new({
		text = "Alignment",
		type = ButtonTypes.INDICATORS,
		options = alignmentOptions,
		currentOptionIndex = currentIndex,
		screenWidth = state.screenWidth,
		context = "statusAlignment",
	})
end

-- Handle option cycling for alignment button
local function handleAlignmentOptionCycle(direction)
	if not alignmentButton then
		return false
	end

	local changed = alignmentButton:cycleOption(direction)
	if not changed then
		return false
	end

	local newValue = alignmentButton:getCurrentOption()
	state.statusAlignment = newValue

	return true
end

-- Calculate warning text height properly accounting for wrapping
local function calculateWarningHeight()
	local warningWidth = state.screenWidth - (EDGE_PADDING * 2)
	local _, wrappedLines = WARNING_TEXT_FONT:getWrap(WARNING_TEXT, warningWidth)
	return #wrappedLines * WARNING_TEXT_FONT:getHeight()
end

function statusScreen.draw()
	background.draw()
	header.draw("Status")

	-- Draw warning text below header
	love.graphics.setFont(WARNING_TEXT_FONT)
	love.graphics.setColor(colors.ui.subtext)
	local warningY = header.getContentStartY() + 2
	local warningWidth = state.screenWidth - (EDGE_PADDING * 2)
	love.graphics.printf(WARNING_TEXT, EDGE_PADDING, warningY, warningWidth, "left")
	love.graphics.setFont(fonts.loaded.body)
	love.graphics.setColor(colors.ui.foreground)

	if menuList then
		menuList:draw()
	end

	-- Draw preview rectangle
	local previewY = 0
	if menuList then
		previewY = menuList.y + menuList:getContentHeight() + 20
	else
		previewY = header.getContentStartY() + 120
	end
	local previewHeight = 100
	local previewWidth = state.screenWidth - 80

	-- Get background color from state and draw rectangle at full opacity
	local bgColor = state.getColorValue("background")
	local bgR, bgG, bgB = love.math.colorFromBytes(
		tonumber(bgColor:sub(2, 3), 16),
		tonumber(bgColor:sub(4, 5), 16),
		tonumber(bgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(bgR, bgG, bgB, 1.0)
	love.graphics.rectangle("fill", 40, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw "Preview" text with alignment matching the current setting
	local fgColor = state.getColorValue("foreground")
	local fgR, fgG, fgB = love.math.colorFromBytes(
		tonumber(fgColor:sub(2, 3), 16),
		tonumber(fgColor:sub(4, 5), 16),
		tonumber(fgColor:sub(6, 7), 16)
	)
	love.graphics.setColor(fgR, fgG, fgB, 1.0)

	-- Determine text alignment based on status alignment setting
	local textAlign = "center" -- default
	local textPadding = 0
	local currentAlignment = state.statusAlignment or "Center"
	if currentAlignment == "Left" then
		textAlign = "left"
		textPadding = 16 -- Add left padding
	elseif currentAlignment == "Center" then
		textAlign = "center"
	elseif currentAlignment == "Right" then
		textAlign = "right"
		textPadding = 16 -- Add right padding by reducing width
	end

	love.graphics.printf(
		"Preview",
		40 + textPadding,
		previewY + (previewHeight / 2) - (fonts.loaded.body:getHeight() / 2),
		previewWidth - (textPadding * 2), -- Reduce width for both left and right padding
		textAlign
	)

	-- Draw border around preview
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", 40, previewY, previewWidth, previewHeight, 8, 8)

	-- Draw controls
	controls.draw({
		{ button = "b", text = "Back" },
	})
end

function statusScreen.update(dt)
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end
	if input.isPressed("b") then
		screens.switchTo("main_menu")
	end
end

function statusScreen.onEnter(_data)
	input = inputHandler.create()

	local startY = header.getContentStartY()
	local warningHeight = calculateWarningHeight()
	local listY = startY + warningHeight + COMPONENT_SPACING

	local items = {
		createAlignmentButton(),
	}

	menuList = require("ui.list").List:new({
		x = 0,
		y = listY,
		width = state.screenWidth,
		height = state.screenHeight - listY - 60,
		items = items,
		onItemOptionCycle = function(button, direction)
			if button.context == "statusAlignment" then
				local changed = button:cycleOption(direction)
				if changed then
					local newValue = button:getCurrentOption()
					state.statusAlignment = newValue
				end
				return changed
			end
			return false
		end,
	})
end

function statusScreen.onExit()
	menuList = nil
end

return statusScreen
