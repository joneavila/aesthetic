--- Box art settings screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local button = require("ui.button")
local tween = require("tween")

-- Module table to export public functions
local box_art = {}

-- Screen switching
local switchScreen = nil
local MENU_SCREEN = "main_menu"

-- Box art width options will be generated dynamically in load()
local BOX_ART_WIDTH_OPTIONS = { 0 }

-- Display constants
local EDGE_PADDING = 10
-- This value should match padding applied in `scheme_configurator.lua`, `applyContentWidth` function
local RECTANGLE_SPACING = 20
local CORNER_RADIUS = 12
local PREVIEW_BOTTOM_PADDING = 15

-- Animation variables
local animatedLeftWidth = 0
local animatedRightWidth = 0
local currentTween = nil
local ANIMATION_DURATION = 0.25
local tweenObj = { leftWidth = 0, rightWidth = 0 }

-- List handling variables
local scrollPosition = 0

-- Buttons in this screen
local BUTTONS = {
	{
		text = "Box art width",
		selected = true,
		options = BOX_ART_WIDTH_OPTIONS,
		currentOption = 1, -- Will be updated in load() based on state
	},
}

-- Initialize box art width in state if it doesn't exist
if state.boxArtWidth == nil then
	state.boxArtWidth = BOX_ART_WIDTH_OPTIONS[1] -- Default to first option (0)
end

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

function box_art.load()
	-- Generate width options
	generateWidthOptions()

	-- Set the correct current option index based on state.boxArtWidth
	local found = false
	for i, option in ipairs(BOX_ART_WIDTH_OPTIONS) do
		if option == state.boxArtWidth then
			BUTTONS[1].currentOption = i
			found = true
			break
		end
	end

	-- If the stored width is not in the options (possibly due to screen size change), default to 0
	if not found then
		state.boxArtWidth = BOX_ART_WIDTH_OPTIONS[1]
		BUTTONS[1].currentOption = 1
	end

	-- Initialize animation values
	local boxArtWidth = BOX_ART_WIDTH_OPTIONS[BUTTONS[1].currentOption]
	local previewWidth = state.screenWidth - (EDGE_PADDING * 2)
	tweenObj.leftWidth = previewWidth - boxArtWidth - (boxArtWidth > 0 and RECTANGLE_SPACING or 0)
	tweenObj.rightWidth = boxArtWidth > 0 and boxArtWidth or 0
	animatedLeftWidth = tweenObj.leftWidth
	animatedRightWidth = tweenObj.rightWidth
end

function box_art.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("BOX ART WIDTH")

	-- Set font
	love.graphics.setFont(state.fonts.body)

	-- Calculate start Y position for the list
	local startY = header.getHeight()

	-- Draw the list using our list component
	list.draw({
		items = BUTTONS,
		startY = startY,
		itemHeight = button.calculateHeight(),
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = state.screenHeight,
		drawItemFunc = function(item, _index, y)
			if item.options then
				-- For items with multiple options
				local currentValue = item.options[item.currentOption]
				local displayText = getDisplayText(currentValue)
				button.drawWithIndicators(item.text, 0, y, item.selected, item.disabled, state.screenWidth, displayText)
			else
				button.draw(item.text, 0, y, item.selected, state.screenWidth)
			end
		end,
	})

	-- Calculate where the list ends
	local totalListHeight = #BUTTONS * (button.calculateHeight() + button.BUTTON.SPACING)
	local endY = startY + totalListHeight

	-- Draw preview rectangles
	local previewY = endY + button.BUTTON.SPACING
	local previewWidth = state.screenWidth - (EDGE_PADDING * 2)

	-- Get current value for preview
	local currentValue = BOX_ART_WIDTH_OPTIONS[BUTTONS[1].currentOption]

	-- Draw preview rectangles
	local previewHeight = 100
	local previewYOffset = 40

	previewY = previewY + previewYOffset

	-- Determine box art width from current selection
	local boxArtWidth = currentValue

	-- Draw left rectangle with teal color
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

	-- Draw right rectangle with lavender color, only if box art is enabled
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
		-- Draw labels for content and box art areas with background color
		love.graphics.setColor(colors.ui.background)
		love.graphics.printf(
			"Text",
			EDGE_PADDING,
			previewY + previewHeight / 2 - state.fonts.caption:getHeight() / 2,
			animatedLeftWidth,
			"center"
		)

		-- Only show box art label if there's enough space
		if boxArtWidth >= 70 then
			love.graphics.printf(
				"Box art",
				EDGE_PADDING + animatedLeftWidth + RECTANGLE_SPACING,
				previewY + previewHeight / 2 - state.fonts.caption:getHeight() / 2,
				animatedRightWidth,
				"center"
			)
		end
	else
		-- If disabled, show simple text label in the center with background color
		love.graphics.setColor(colors.ui.background)
		love.graphics.printf(
			"Text",
			EDGE_PADDING,
			previewY + previewHeight / 2 - state.fonts.caption:getHeight() / 2,
			previewWidth,
			"center"
		)
	end

	-- Draw controls
	controls.draw({
		{ button = "b", text = "Save" },
	})
end

function box_art.update(dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Update tween animation if it exists
	if currentTween then
		local completed = currentTween:update(dt)
		if completed then
			currentTween = nil
		end
		-- Update animated values from tween object
		animatedLeftWidth = tweenObj.leftWidth
		animatedRightWidth = tweenObj.rightWidth
	end

	-- Handle left/right to change box art width value
	local pressedLeft = virtualJoystick.isGamepadPressedWithDelay("dpleft")
	local pressedRight = virtualJoystick.isGamepadPressedWithDelay("dpright")

	if pressedLeft or pressedRight then
		local direction = pressedLeft and -1 or 1
		local btn = BUTTONS[1]

		-- Calculate new option index
		local newIndex = btn.currentOption + direction

		-- Wrap around if needed
		if newIndex < 1 then
			newIndex = #btn.options
		elseif newIndex > #btn.options then
			newIndex = 1
		end

		-- Update current option
		btn.currentOption = newIndex

		-- Update state with selected option
		state.boxArtWidth = btn.options[btn.currentOption]

		-- Create animation tween for the transition
		local boxArtWidth = state.boxArtWidth
		local previewWidth = state.screenWidth - (EDGE_PADDING * 2)
		local targetLeftWidth = previewWidth - boxArtWidth - (boxArtWidth > 0 and RECTANGLE_SPACING or 0)
		local targetRightWidth = boxArtWidth > 0 and boxArtWidth or 0

		-- Target object for the animation
		local target = {
			leftWidth = targetLeftWidth,
			rightWidth = targetRightWidth,
		}

		-- Create tween with current values as starting point - using inOutQuad for ease in ease out
		currentTween = tween.new(ANIMATION_DURATION, tweenObj, target, "inOutQuad")
	end

	-- Handle B button to return to menu
	if virtualJoystick.isGamepadPressedWithDelay("b") and switchScreen then
		switchScreen(MENU_SCREEN)
	end
end

function box_art.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function box_art.onEnter()
	-- Regenerate width options in case screen size has changed
	generateWidthOptions()

	-- Set the correct current option index based on state.boxArtWidth
	local found = false
	for i, option in ipairs(BOX_ART_WIDTH_OPTIONS) do
		if option == state.boxArtWidth then
			BUTTONS[1].currentOption = i
			found = true
			break
		end
	end

	-- If the stored width is not in the options (possibly due to screen size change), default to 0
	if not found then
		state.boxArtWidth = BOX_ART_WIDTH_OPTIONS[1]
		BUTTONS[1].currentOption = 1
	end
end

return box_art
