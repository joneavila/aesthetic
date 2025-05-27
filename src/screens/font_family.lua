--- Font selection screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local fonts = require("ui.fonts")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local button = require("ui.button")
local controls = require("controls")
local logger = require("utils.logger")
local screens = require("screens")

-- Module table to export public functions
local font = {}

-- Constants specific to the font preview
local FONT_PREVIEW = {
	PREVIEW_TEXT = "The quick brown fox jumps over the lazy dog. 0123456789 !@#$%^&*()_+-=[]{};:'\",.\\<>/?`~",
	PREVIEW_BG_CORNER_RADIUS = 10,
	PREVIEW_BOTTOM_MARGIN = 15, -- Margin between preview box and controls
	FONT_SIZE = 24, -- Use a consistent font size for all preview fonts
	PADDING = 12, -- Padding around the preview text
}

-- Font cache for previewing (to avoid recreating fonts every frame)
local previewFontCache = {}

-- Store the maximum preview height once calculated
local maxPreviewHeight = nil

-- Font items with their selected state
local fontItems = {}
local savedSelectedIndex = 1 -- Track the last selected index

-- Helper function to get a consistent preview font
local function getPreviewFont(fontName)
	-- Check if we already have this font in our cache
	if previewFontCache[fontName] then
		return previewFontCache[fontName]
	end

	local previewFont

	-- Find the font info from fonts.themeDefinitions
	local fontInfo = nil
	for _, choice in ipairs(fonts.themeDefinitions) do
		if choice.name == fontName then
			fontInfo = choice
			break
		end
	end

	if fontInfo and fontInfo.path then
		previewFont = love.graphics.newFont(fontInfo.path, FONT_PREVIEW.FONT_SIZE)
	else
		-- Fallback to the state's font loading for unknown fonts
		previewFont = fonts.getByName(fontName)
	end

	-- Cache the font for future use
	previewFontCache[fontName] = previewFont
	return previewFont
end

-- Helper function to calculate the maximum preview height across all fonts
local function calculateMaxPreviewHeight()
	if maxPreviewHeight then
		return maxPreviewHeight
	end

	local maxHeight = 0
	for _, fontChoice in ipairs(fonts.themeDefinitions) do
		local previewFont = getPreviewFont(fontChoice.name)
		local _, textLines = previewFont:getWrap(
			FONT_PREVIEW.PREVIEW_TEXT,
			state.screenWidth - (button.BUTTON.HORIZONTAL_PADDING * 2) - (FONT_PREVIEW.PADDING * 2)
		)
		local height = #textLines * previewFont:getHeight() + (FONT_PREVIEW.PADDING * 2)
		maxHeight = math.max(maxHeight, height)
	end

	maxPreviewHeight = maxHeight
	return maxHeight
end

-- Initialize font items based on fonts.themeDefinitions
local function initFontItems()
	fontItems = {}
	local foundSelected = false

	for _, fontItem in ipairs(fonts.themeDefinitions) do
		local isSelected = fontItem.name == state.selectedFont

		if isSelected then
			foundSelected = true
		end

		table.insert(fontItems, {
			text = fontItem.name,
			selected = isSelected,
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

function font.draw()
	-- Set background
	background.draw()

	-- Draw header with title using the UI component
	header.draw("font family")

	-- Make sure we restore the default UI font for the button list
	love.graphics.setFont(state.fonts.body)

	-- Ensure controls HEIGHT is calculated
	controls.calculateHeight()

	-- Calculate the preview height and position
	local previewHeight = calculateMaxPreviewHeight()
	local previewY = state.screenHeight - controls.HEIGHT - previewHeight - FONT_PREVIEW.PREVIEW_BOTTOM_MARGIN

	-- Calculate start Y position for the list and available height
	local startY = header.getContentStartY()

	-- Find the currently hovered font
	local hoveredFontName = state.selectedFont
	for _, item in ipairs(fontItems) do
		if item.selected then
			hoveredFontName = item.text
			break
		end
	end

	-- Get current scroll position from list module
	local scrollPosition = list.getScrollPosition()

	-- Draw the list using our list component
	list.draw({
		items = fontItems,
		startY = startY,
		itemHeight = button.calculateHeight(),
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = previewY, -- Set the maximum height for the list
		drawItemFunc = function(item, _index, y)
			button.draw(item.text, 0, y, item.selected, state.screenWidth)
		end,
	})

	-- Draw rounded background for preview text
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle(
		"fill",
		button.BUTTON.EDGE_MARGIN,
		previewY,
		state.screenWidth - (button.BUTTON.EDGE_MARGIN * 2),
		previewHeight,
		FONT_PREVIEW.PREVIEW_BG_CORNER_RADIUS
	)

	-- Draw preview text if a font is selected
	if hoveredFontName then
		-- Get the font for preview
		local previewFont = getPreviewFont(hoveredFontName)

		-- Draw the actual preview with the selected font
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.setFont(previewFont)
		love.graphics.printf(
			FONT_PREVIEW.PREVIEW_TEXT,
			button.BUTTON.EDGE_MARGIN + FONT_PREVIEW.PADDING,
			previewY + FONT_PREVIEW.PADDING,
			state.screenWidth - (button.BUTTON.EDGE_MARGIN * 2) - (FONT_PREVIEW.PADDING * 2),
			"left"
		)
	end

	-- Draw controls
	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Save" },
	})
end

function font.update(_dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Handle B button (Back to menu)
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		screens.switchTo("main_menu")
		return
	end

	-- Use the enhanced list input handler for navigation and selection
	list.handleInput({
		items = fontItems,
		virtualJoystick = virtualJoystick,

		-- Handle item selection (A button)
		handleItemSelect = function(item)
			savedSelectedIndex = list.getSelectedIndex()

			-- Update the selected font in state
			state.selectedFont = item.text

			-- Return to menu
			screens.switchTo("main_menu")
		end,
	})
end

function font.onEnter(data)
	initFontItems()

	-- Reset list state and restore selection
	list.onScreenEnter("font_family", fontItems, savedSelectedIndex)
	logger.debug("Font family screen entered")
end

function font.onExit()
	-- Save the current selected index
	savedSelectedIndex = list.onScreenExit()
end

return font
