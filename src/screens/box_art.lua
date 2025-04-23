--- Box art settings screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local ui_button = require("ui.button")
local header = require("ui.header")
local background = require("ui.background")

-- Module table to export public functions
local box_art = {}

-- Screen switching
local switchScreen = nil
local MENU_SCREEN = "menu"

-- Button dimensions and position
local BUTTON = {
	WIDTH = nil, -- Will be calculated in load()
	HEIGHT = 50,
	PADDING = 20,
	START_Y = nil, -- Will be calculated in load()
}

-- Box art width options will be generated dynamically in load()
local BOX_ART_WIDTH_OPTIONS = { "Disabled" }

-- Buttons in this screen
local BUTTONS = {
	{
		text = "Box art width",
		selected = true,
		value = "Disabled", -- Default value, will be updated in load() based on state
		options = BOX_ART_WIDTH_OPTIONS,
		currentOption = 1, -- Will be updated in load() based on state
	},
}

-- Initialize box art width in state if it doesn't exist
if state.boxArtWidth == nil then
	state.boxArtWidth = BOX_ART_WIDTH_OPTIONS[1] -- Default to first option
end

-- Generate width options from 220 to half screen width in steps of 20
local function generateWidthOptions()
	-- Clear existing numeric options but keep "Disabled"
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
	BUTTON.WIDTH = state.screenWidth - (BUTTON.PADDING * 2)
	BUTTON.START_Y = BUTTON.PADDING

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

	-- If the stored width is not in the options (possibly due to screen size change),
	-- default to "Disabled"
	if not found then
		state.boxArtWidth = BOX_ART_WIDTH_OPTIONS[1]
		BUTTONS[1].currentOption = 1
	end
end

function box_art.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("Box art width")

	-- Set font
	love.graphics.setFont(state.fonts.body)

	-- Draw the button
	local button = BUTTONS[1]
	local y = BUTTON.START_Y + header.HEIGHT

	-- Get current value and format it
	local currentValue = BOX_ART_WIDTH_OPTIONS[button.currentOption]
	local valueText = tostring(currentValue)
	if valueText == "Disabled" then
		valueText = "0 (Disabled)"
	end

	-- Draw the button with triangles using the UI button helper
	ui_button.drawWithIndicators(
		button.text,
		0,
		y,
		button.selected,
		button.disabled,
		state.screenWidth,
		state.fonts.body,
		valueText
	)

	-- Draw preview rectangles
	local previewHeight = 100
	local previewYOffset = 40
	local previewY = y + BUTTON.HEIGHT + previewYOffset

	-- Draw labels for the preview
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.setFont(state.fonts.body)
	love.graphics.printf(
		"Preview",
		BUTTON.PADDING,
		y + BUTTON.HEIGHT + 10,
		state.screenWidth - BUTTON.PADDING * 2,
		"left"
	)

	-- Determine box art width from current selection
	local boxArtWidth = 0 -- Default width for "Disabled"
	if type(currentValue) == "number" then
		boxArtWidth = currentValue
	end

	-- Calculate left rectangle width
	local leftRectWidth = state.screenWidth - boxArtWidth

	-- Draw left rectangle (green)
	love.graphics.setColor(colors.ui.green)
	love.graphics.rectangle("fill", 0, previewY, leftRectWidth, previewHeight)

	-- Draw right rectangle (red)
	love.graphics.setColor(colors.ui.red)
	love.graphics.rectangle("fill", leftRectWidth, previewY, boxArtWidth, previewHeight)

	if boxArtWidth > 0 then
		-- Draw labels for content and box art areas with background color
		love.graphics.setColor(colors.ui.background)
		love.graphics.printf(
			"Text width",
			0,
			previewY + previewHeight / 2 - state.fonts.caption:getHeight() / 2,
			leftRectWidth,
			"center"
		)

		-- Only show box art label if there's enough space
		if boxArtWidth >= 70 then
			love.graphics.printf(
				"Box art width",
				leftRectWidth,
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
			0,
			previewY + previewHeight / 2 - state.fonts.caption:getHeight() / 2,
			state.screenWidth,
			"center"
		)
	end

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Navigate / Change value" },
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
		local button = BUTTONS[1]

		-- Calculate new option index
		local newIndex = button.currentOption + direction

		-- Wrap around if needed
		if newIndex < 1 then
			newIndex = #button.options
		elseif newIndex > #button.options then
			newIndex = 1
		end

		-- Update current option
		button.currentOption = newIndex

		-- Update state with selected option
		state.boxArtWidth = button.options[button.currentOption]

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

	-- If the stored width is not in the options (possibly due to screen size change),
	-- default to "Disabled"
	if not found then
		state.boxArtWidth = BOX_ART_WIDTH_OPTIONS[1]
		BUTTONS[1].currentOption = 1
	end
end

return box_art
