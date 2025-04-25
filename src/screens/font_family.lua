--- Font selection screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local fontDefs = require("ui.font_defs")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local UI_CONSTANTS = require("ui.constants")

-- Module table to export public functions
local font = {}

-- Screen switching
local switchScreen = nil

-- Constants specific to the font preview
local FONT_PREVIEW = {
	PREVIEW_TEXT = "The quick brown fox jumps over the lazy dog. 0123456789 !@#$%^&*()_+-=[]{};:'\",.\\<>/?`~",
	PREVIEW_BG_CORNER_RADIUS = 10,
	PREVIEW_BOTTOM_MARGIN = 15, -- Margin between preview box and controls
}

-- Font items with their selected state
local fontItems = {}
local scrollPosition = 0
local visibleCount = 0

-- Initialize font items based on fontDefs.FONTS
local function initFontItems()
	fontItems = {}
	local foundSelected = false

	for _, fontItem in ipairs(fontDefs.FONTS) do
		local isSelected = fontItem.name == state.selectedFont

		if isSelected then
			foundSelected = true
		end

		table.insert(fontItems, {
			text = fontItem.name,
			selected = isSelected,
			value = fontItem.name,
		})
	end

	-- If no font was selected, select the first one by default
	if not foundSelected and #fontItems > 0 then
		fontItems[1].selected = true
	end
end

function font.load()
	initFontItems()
end

-- Custom draw function for font items to use their own font
local function drawFontItem(item, index, x, y)
	-- The button background and standard text is already drawn by the list component
	-- Here we just need to override the text with the custom font

	-- First, clear the area where the standard text was drawn
	-- Match the area with the exact standard text dimensions
	local textHeight = state.fonts.body:getHeight()
	local textWidth = state.fonts.body:getWidth(item.text)
	love.graphics.setColor(item.selected and colors.ui.surface or colors.ui.background)
	love.graphics.rectangle("fill", x + 20, y + (UI_CONSTANTS.BUTTON.HEIGHT - textHeight) / 2, textWidth, textHeight)

	-- Now draw the text with the custom font
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(state.getFontByName(item.text))

	-- Get the text height for vertical centering with the new font
	local customTextHeight = love.graphics.getFont():getHeight()

	-- Draw the text with proper padding (the same as standard buttons)
	love.graphics.print(item.text, x + 20, y + (UI_CONSTANTS.BUTTON.HEIGHT - customTextHeight) / 2)
end

function font.draw()
	-- Set background
	background.draw()

	-- Draw header with title using the UI component
	header.draw("Font family")

	-- Calculate available space for list
	local startY = header.HEIGHT + UI_CONSTANTS.BUTTON.PADDING

	-- Calculate preview position at bottom of screen, above controls
	local previewHeight = 0

	-- Find the currently hovered font
	local hoveredFontName = state.selectedFont
	for _, item in ipairs(fontItems) do
		if item.selected then
			hoveredFontName = item.text
			break
		end
	end

	-- Set the font for preview text using getFontByName
	love.graphics.setFont(state.getFontByName(hoveredFontName))

	-- Calculate preview text height for background
	local _, textLines = love.graphics
		.getFont()
		:getWrap(FONT_PREVIEW.PREVIEW_TEXT, state.screenWidth - (UI_CONSTANTS.BUTTON.PADDING * 2))
	previewHeight = #textLines * love.graphics.getFont():getHeight() + UI_CONSTANTS.BUTTON.PADDING * 2

	local previewY = state.screenHeight - controls.HEIGHT - previewHeight - FONT_PREVIEW.PREVIEW_BOTTOM_MARGIN

	-- Calculate available space for the list
	local availableHeight = previewY - startY

	-- Draw the font list
	local result = list.draw({
		items = fontItems,
		startY = startY,
		itemHeight = UI_CONSTANTS.BUTTON.HEIGHT,
		itemPadding = UI_CONSTANTS.BUTTON.PADDING,
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		customDrawFunc = drawFontItem,
		visibleCount = math.floor(availableHeight / (UI_CONSTANTS.BUTTON.HEIGHT + UI_CONSTANTS.BUTTON.PADDING)),
	})

	visibleCount = result.visibleCount

	-- Draw rounded background for preview text
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle(
		"fill",
		UI_CONSTANTS.BUTTON.PADDING,
		previewY,
		state.screenWidth - (UI_CONSTANTS.BUTTON.PADDING * 2),
		previewHeight,
		FONT_PREVIEW.PREVIEW_BG_CORNER_RADIUS
	)

	-- Draw preview text
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.printf(
		FONT_PREVIEW.PREVIEW_TEXT,
		UI_CONSTANTS.BUTTON.PADDING * 2,
		previewY + UI_CONSTANTS.BUTTON.PADDING,
		state.screenWidth - (UI_CONSTANTS.BUTTON.PADDING * 4),
		"left"
	)

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Navigate" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function font.update(_dt)
	if not state.canProcessInput() then
		return
	end

	local virtualJoystick = require("input").virtualJoystick

	-- Handle D-pad up/down navigation
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		local direction = virtualJoystick:isGamepadDown("dpup") and -1 or 1

		-- Use the list navigation helper
		local selectedIndex = list.navigate(fontItems, direction)

		-- Update scroll position
		scrollPosition = list.adjustScrollPosition({
			selectedIndex = selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleCount,
		})

		state.resetInputTimer()
	end

	-- Handle B button (Back to menu)
	if virtualJoystick:isGamepadDown("b") and switchScreen then
		switchScreen("menu")
		state.resetInputTimer()
		state.forceInputDelay(0.2) -- Add extra delay when switching screens
		return
	end

	-- Handle A button (Select font)
	if virtualJoystick:isGamepadDown("a") then
		-- Find which font is selected
		for _, item in ipairs(fontItems) do
			if item.selected then
				-- Update the selected font in state
				state.selectedFont = item.text

				-- Update fontDefs.FONTS to match
				for _, fontItem in ipairs(fontDefs.FONTS) do
					fontItem.selected = (fontItem.name == item.text)
				end

				-- Return to menu
				if switchScreen then
					switchScreen("menu")
					state.resetInputTimer()
					state.forceInputDelay(0.2) -- Add extra delay when switching screens
				end
				break
			end
		end
	end
end

function font.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- Function called when entering this screen
function font.onEnter()
	-- Reinitialize font items to ensure they match the current state
	initFontItems()
	scrollPosition = 0
end

return font
