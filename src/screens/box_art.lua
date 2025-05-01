--- Box art settings screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local button = require("ui.button")

-- Module table to export public functions
local box_art = {}

-- Screen switching
local switchScreen = nil
local MENU_SCREEN = "main_menu"

-- Box art width options will be generated dynamically in load()
local BOX_ART_WIDTH_OPTIONS = { 0 }

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
		itemPadding = button.BUTTON.SPACING,
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
	local previewWidth = state.screenWidth - button.BUTTON.EDGE_MARGIN * 2

	-- Get current value for preview
	local currentValue = BOX_ART_WIDTH_OPTIONS[BUTTONS[1].currentOption]

	-- Draw preview rectangles
	local previewHeight = 100
	local previewYOffset = 40
	previewY = previewY + previewYOffset

	-- Draw labels for the preview
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.setFont(state.fonts.body)
	love.graphics.printf(
		"Preview",
		button.BUTTON.EDGE_MARGIN,
		previewY + previewHeight / 2 - state.fonts.caption:getHeight() / 2,
		previewWidth,
		"left"
	)

	-- Determine box art width from current selection
	local boxArtWidth = currentValue

	-- Calculate left rectangle width
	local leftRectWidth = previewWidth - boxArtWidth

	-- Draw left rectangle (green)
	love.graphics.setColor(colors.ui.green)
	love.graphics.rectangle("fill", button.BUTTON.EDGE_MARGIN, previewY, leftRectWidth, previewHeight)

	-- Draw right rectangle (red)
	love.graphics.setColor(colors.ui.red)
	love.graphics.rectangle("fill", leftRectWidth + button.BUTTON.EDGE_MARGIN, previewY, boxArtWidth, previewHeight)

	if boxArtWidth > 0 then
		-- Draw labels for content and box art areas with background color
		love.graphics.setColor(colors.ui.background)
		love.graphics.printf(
			"Text width",
			button.BUTTON.EDGE_MARGIN,
			previewY + previewHeight / 2 - state.fonts.caption:getHeight() / 2,
			leftRectWidth,
			"center"
		)

		-- Only show box art label if there's enough space
		if boxArtWidth >= 70 then
			love.graphics.printf(
				"Box art width",
				leftRectWidth + button.BUTTON.EDGE_MARGIN,
				previewY + previewHeight / 2 - state.fonts.caption:getHeight() / 2,
				boxArtWidth,
				"center"
			)
		end
	else
		-- If disabled, show "Box art disabled" in the center with background color
		love.graphics.setColor(colors.ui.background)
		love.graphics.printf(
			"Text width (box art disabled)",
			button.BUTTON.EDGE_MARGIN,
			previewY + previewHeight / 2 - state.fonts.caption:getHeight() / 2,
			previewWidth,
			"center"
		)
	end

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Change value" },
		{ button = "b", text = "Back" },
	})
end

function box_art.update(_dt)
	local virtualJoystick = require("input").virtualJoystick

	if not state.canProcessInput() then
		return
	end

	-- Handle left/right to change box art width value
	if virtualJoystick:isGamepadDown("dpleft") or virtualJoystick:isGamepadDown("dpright") then
		local direction = virtualJoystick:isGamepadDown("dpleft") and -1 or 1
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

		state.resetInputTimer()
	end

	-- Handle B button to return to menu
	if virtualJoystick:isGamepadDown("b") and switchScreen then
		switchScreen(MENU_SCREEN)
		state.resetInputTimer()
		state.forceInputDelay(0.2) -- Add extra delay when switching screens
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
