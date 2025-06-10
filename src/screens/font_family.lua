--- Font selection screen
local love = require("love")

local colors = require("colors")
local controls = require("control_hints")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List

-- Module table to export public functions
local font = {}

-- Local variables for this module
local menuList
local input

-- Constants specific to the font preview
local FONT_PREVIEW = {
	PREVIEW_TEXT = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890!@#$%^&*()_+-=[]{}|;':\",./<>?",
	PREVIEW_BG_CORNER_RADIUS = 10,
	PREVIEW_BOTTOM_MARGIN = 15, -- Margin between preview box and controls
	FONT_SIZE = 24, -- Use a consistent font size for all preview fonts
	PADDING = 12, -- Padding around the preview text
}

-- Font cache for previewing (to avoid recreating fonts every frame)
local previewFontCache = {}

-- Store the maximum preview height once calculated
local maxPreviewHeight = nil

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

-- Helper function to calculate the preview height for a specific font
local function calculatePreviewHeight(fontName)
	if not fontName then
		return 0
	end

	local previewFont = getPreviewFont(fontName)
	local _, textLines =
		previewFont:getWrap(FONT_PREVIEW.PREVIEW_TEXT, state.screenWidth - (32 * 2) - (FONT_PREVIEW.PADDING * 2))
	local height = #textLines * previewFont:getHeight() + (FONT_PREVIEW.PADDING * 2)
	return height
end

-- Helper function to calculate the maximum preview height across all fonts
local function calculateMaxPreviewHeight()
	if maxPreviewHeight then
		return maxPreviewHeight
	end

	local maxHeight = 0
	for _, fontChoice in ipairs(fonts.themeDefinitions) do
		local height = calculatePreviewHeight(fontChoice.name)
		maxHeight = math.max(maxHeight, height)
	end

	maxPreviewHeight = maxHeight
	return maxHeight
end

local function createMenuButtons()
	local buttons = {}
	for _, fontItem in ipairs(fonts.themeDefinitions) do
		table.insert(
			buttons,
			Button:new({
				text = fontItem.name,
				screenWidth = state.screenWidth,
				onClick = function()
					state.fontFamily = fontItem.name
					screens.switchTo("main_menu")
				end,
			})
		)
	end
	return buttons
end

function font.draw()
	-- Set background
	background.draw()

	-- Draw header with title using the UI component
	header.draw("Font Family")

	-- Make sure we restore the default UI font for the button list
	love.graphics.setFont(fonts.loaded.body)

	-- Ensure controls HEIGHT is calculated
	controls.calculateHeight()

	-- Use the currently focused font for preview
	local hoveredFontName = nil
	if menuList and menuList.selectedIndex and menuList.items[menuList.selectedIndex] then
		hoveredFontName = menuList.items[menuList.selectedIndex].text
	end

	-- Calculate the maximum preview height for fixed positioning
	local calculatedMaxPreviewHeight = calculateMaxPreviewHeight()
	local previewY = state.screenHeight
		- controls.HEIGHT
		- calculatedMaxPreviewHeight
		- FONT_PREVIEW.PREVIEW_BOTTOM_MARGIN

	-- Draw the list using our list component
	if menuList then
		-- Use fixed list height based on maximum preview height
		menuList.height = previewY - header.getContentStartY() - 8
		menuList:calculateDimensions()
		menuList:draw()
	end

	-- Always draw preview background with maximum height for consistency
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle(
		"fill",
		32,
		previewY,
		state.screenWidth - (32 * 2),
		calculatedMaxPreviewHeight,
		FONT_PREVIEW.PREVIEW_BG_CORNER_RADIUS
	)

	-- Draw preview text if we have a font selected
	if hoveredFontName then
		-- Get the font for preview
		local previewFont = getPreviewFont(hoveredFontName)

		-- Draw the actual preview with the selected font
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.setFont(previewFont)
		love.graphics.printf(
			FONT_PREVIEW.PREVIEW_TEXT,
			32 + FONT_PREVIEW.PADDING,
			previewY + FONT_PREVIEW.PADDING,
			state.screenWidth - (32 * 2) - (FONT_PREVIEW.PADDING * 2),
			"left"
		)
	end

	-- Draw controls
	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Save" },
	})
end

function font.update(dt)
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end
	if input.isPressed("b") then
		screens.switchTo("main_menu")
	end
end

function font.onEnter()
	-- Initialize input handler
	input = inputHandler.create()

	-- Create menu list
	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - header.getContentStartY() - 120,
		items = createMenuButtons(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		itemHeight = 40,
	})
end

function font.onExit()
	-- No-op for now
end

return font
