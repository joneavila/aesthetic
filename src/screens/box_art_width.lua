--- Box art settings screen
local love = require("love")

local colors = require("colors")
local controls = require("controls")
local screens = require("screens")
local state = require("state")
local tween = require("tween")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List

-- Module table to export public functions
local box_art_width = {}

-- Screen switching
local MENU_SCREEN = "main_menu"

-- Box art width options will be generated dynamically in load()
local BOX_ART_WIDTH_OPTIONS = { 0 }

-- Display constants
local EDGE_PADDING = 10
-- This value should match padding applied in `scheme_configurator.lua`, `applyContentWidth` function
local RECTANGLE_SPACING = 20
local CORNER_RADIUS = 12

-- Animation variables
local animatedLeftWidth = 0
local animatedRightWidth = 0
local currentTween = nil
local ANIMATION_DURATION = 0.25
local tweenObj = { leftWidth = 0, rightWidth = 0 }

-- List handling variables
local menuList = nil
local input = nil

-- Function to get display text for a box art width value
local function getDisplayText(width)
	if width == 0 then
		return "Disabled"
	else
		return tostring(width)
	end
end

-- Generate width options from 220 to half screen width in steps of 20
local function generateWidthOptions()
	-- Clear existing numeric options but keep 0
	while #BOX_ART_WIDTH_OPTIONS > 1 do
		table.remove(BOX_ART_WIDTH_OPTIONS)
	end

	-- Calculate half of screen width and round to nearest multiple of 20
	local halfWidth = state.screenWidth / 2
	local roundedHalfWidth = math.floor(halfWidth / 20) * 20

	-- Add options from 220 to rounded half width in steps of 20
	for width = 220, roundedHalfWidth, 20 do
		table.insert(BOX_ART_WIDTH_OPTIONS, width)
	end
end

local function createMenuButtons()
	return {
		Button:new({
			text = "Box art width",
			type = ButtonTypes.INDICATORS,
			options = BOX_ART_WIDTH_OPTIONS,
			currentOptionIndex = (function()
				for i, option in ipairs(BOX_ART_WIDTH_OPTIONS) do
					if option == state.boxArtWidth then
						return i
					end
				end
				return 1
			end)(),
			screenWidth = state.screenWidth,
			getDisplayText = getDisplayText,
			context = "boxArtWidth",
		}),
	}
end

local function handleOptionCycle(button, direction)
	if button.context == "boxArtWidth" then
		local changed = button:cycleOption(direction)
		if changed then
			state.boxArtWidth = button:getCurrentOption()
			local boxArtWidth = state.boxArtWidth
			local previewWidth = state.screenWidth - (EDGE_PADDING * 2)
			local targetLeftWidth = previewWidth - boxArtWidth - (boxArtWidth > 0 and RECTANGLE_SPACING or 0)
			local targetRightWidth = boxArtWidth > 0 and boxArtWidth or 0
			local target = { leftWidth = targetLeftWidth, rightWidth = targetRightWidth }
			currentTween = tween.new(ANIMATION_DURATION, tweenObj, target, "inOutQuad")
		end
		return changed
	end
	return false
end

function box_art_width.draw()
	background.draw()
	header.draw("box art width")

	-- Draw information text below header
	local infoText = "This setting applies to the Content, Collection, and History screens and assumes you have\n"
		.. ' set muOS "Content Box Art Alignment" setting to "Bottom Right", "Middle Right", or "Top Right".'
	love.graphics.setFont(fonts.loaded.caption)
	love.graphics.setColor(colors.ui.subtext)
	local infoY = header.getContentStartY() + 2
	local infoWidth = state.screenWidth - EDGE_PADDING * 2
	love.graphics.printf(infoText, EDGE_PADDING, infoY, infoWidth, "left")
	love.graphics.setFont(fonts.loaded.body)

	-- Calculate dynamic height for info text
	local font = love.graphics.getFont()
	local _, wrappedLines = font:getWrap(infoText, infoWidth)
	local infoHeight = #wrappedLines * font:getHeight() + 10
	if menuList then
		menuList.y = header.getContentStartY() + infoHeight + 6
		menuList:draw()
	end

	-- Calculate the bottom Y of the last button in the menuList
	local previewY = header.getContentStartY() + infoHeight + 40
	if menuList then
		local listBottom = menuList.y + menuList:getContentHeight()
		previewY = listBottom + 40
	end

	local previewWidth = state.screenWidth - (EDGE_PADDING * 2)
	local currentValue = state.boxArtWidth
	local previewHeight = 100
	local boxArtWidth = currentValue
	love.graphics.setColor(colors.ui.teal)
	love.graphics.rectangle(
		"fill",
		EDGE_PADDING,
		previewY,
		animatedLeftWidth,
		previewHeight,
		CORNER_RADIUS,
		CORNER_RADIUS
	)
	if animatedRightWidth > 0 then
		love.graphics.setColor(colors.ui.lavender)
		love.graphics.rectangle(
			"fill",
			EDGE_PADDING + animatedLeftWidth + RECTANGLE_SPACING,
			previewY,
			animatedRightWidth,
			previewHeight,
			CORNER_RADIUS,
			CORNER_RADIUS
		)
	end
	if boxArtWidth > 0 then
		love.graphics.setColor(colors.ui.background)
		love.graphics.printf(
			"Text",
			EDGE_PADDING,
			previewY + previewHeight / 2 - fonts.loaded.caption:getHeight() / 2,
			animatedLeftWidth,
			"center"
		)
		if boxArtWidth >= 70 then
			love.graphics.printf(
				"Box art",
				EDGE_PADDING + animatedLeftWidth + RECTANGLE_SPACING,
				previewY + previewHeight / 2 - fonts.loaded.caption:getHeight() / 2,
				animatedRightWidth,
				"center"
			)
		end
	else
		love.graphics.setColor(colors.ui.background)
		love.graphics.printf(
			"Text",
			EDGE_PADDING,
			previewY + previewHeight / 2 - fonts.loaded.caption:getHeight() / 2,
			previewWidth,
			"center"
		)
	end
	controls.draw({
		{ button = "b", text = "Save" },
	})
end

function box_art_width.update(dt)
	if currentTween then
		local completed = currentTween:update(dt)
		if completed then
			currentTween = nil
		end
		animatedLeftWidth = tweenObj.leftWidth
		animatedRightWidth = tweenObj.rightWidth
	end

	-- Handle B button to return to main menu
	if input and input.isPressed and input.isPressed("b") then
		screens.switchTo(MENU_SCREEN)
		return
	end

	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end
end

function box_art_width.onEnter()
	-- Initialize input handler
	input = inputHandler.create()

	generateWidthOptions()

	-- Create menu list
	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - header.getContentStartY() - 60,
		items = createMenuButtons(),
		onItemSelect = function(_item)
			-- No-op for this screen
		end,
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})

	-- Initialize animation state
	local boxArtWidth = state.boxArtWidth
	local previewWidth = state.screenWidth - (EDGE_PADDING * 2)
	tweenObj.leftWidth = previewWidth - boxArtWidth - (boxArtWidth > 0 and RECTANGLE_SPACING or 0)
	tweenObj.rightWidth = boxArtWidth > 0 and boxArtWidth or 0
	animatedLeftWidth = tweenObj.leftWidth
	animatedRightWidth = tweenObj.rightWidth
end

function box_art_width.onExit() end

return box_art_width
