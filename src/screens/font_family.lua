--- Font selection screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local fonts = require("ui.fonts")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local button = require("ui.button")

-- Module table to export public functions
local font = {}

-- Screen switching
local switchScreen = nil

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

-- Helper function to get a consistent preview font
local function getPreviewFont(fontName)
	-- Check if we already have this font in our cache
	if previewFontCache[fontName] then
		return previewFontCache[fontName]
	end

	local previewFont
	if fontName == "Inter" then
		-- For Inter, create a font directly from the file to avoid UI font scaling issues
		previewFont = love.graphics.newFont("assets/fonts/inter/inter_24pt_semibold.ttf", FONT_PREVIEW.FONT_SIZE)
	elseif fontName == "Nunito" then
		previewFont = love.graphics.newFont("assets/fonts/nunito/nunito_bold.ttf", FONT_PREVIEW.FONT_SIZE)
	elseif fontName == "JetBrains Mono" then
		previewFont =
			love.graphics.newFont("assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", FONT_PREVIEW.FONT_SIZE)
	elseif fontName == "Retro Pixel" then
		previewFont = love.graphics.newFont("assets/fonts/retro_pixel/retro_pixel_thick.ttf", FONT_PREVIEW.FONT_SIZE)
	elseif fontName == "Cascadia Code" then
		previewFont = love.graphics.newFont("assets/fonts/cascadia_code/cascadia_code_bold.ttf", FONT_PREVIEW.FONT_SIZE)
	else
		-- Fallback to the state's font loading for unknown fonts
		previewFont = state.getFontByName(fontName)
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
	for _, fontChoice in ipairs(fonts.choices) do
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

-- Font items with their selected state
local fontItems = {}
local scrollPosition = 0
local visibleCount = 0

-- Initialize font items based on fonts.choices
local function initFontItems()
	fontItems = {}
	local foundSelected = false

	for _, fontItem in ipairs(fonts.choices) do
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
	header.draw("Font family")

	-- Make sure we restore the default UI font for the button list
	love.graphics.setFont(state.fonts.body)

	-- Calculate the preview height and position
	local previewHeight = calculateMaxPreviewHeight()
	local previewY = state.screenHeight - controls.HEIGHT - previewHeight - FONT_PREVIEW.PREVIEW_BOTTOM_MARGIN

	-- Calculate start Y position for the list and available height
	local startY = header.getHeight() + button.BUTTON.TOP_MARGIN
	local availableHeight = previewY - startY

	-- Find the currently hovered font
	local hoveredFontName = state.selectedFont
	for _, item in ipairs(fontItems) do
		if item.selected then
			hoveredFontName = item.text
			break
		end
	end

	-- Draw the list using our list component
	local result = list.draw({
		items = fontItems,
		startY = startY,
		itemHeight = button.calculateHeight(),
		itemPadding = button.BUTTON.SPACING,
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = previewY, -- Set the maximum height for the list
		drawItemFunc = function(item, _index, y)
			button.draw(item.text, 0, y, item.selected, state.screenWidth)
		end,
	})

	visibleCount = result.visibleCount

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
		switchScreen("main_menu")
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

				-- Return to menu
				if switchScreen then
					switchScreen("main_menu")
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

-- Function called when exiting this screen
function font.onExit()
	-- Clear the font cache and preview height cache to free memory
	previewFontCache = {}
	maxPreviewHeight = nil
end

return font
