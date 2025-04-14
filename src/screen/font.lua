--- Font selection screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")

local constants = require("screen.menu.constants")

-- Module table to export public functions
local font = {}

-- Screen switching
local switchScreen = nil

-- Constants for font screen
local FONT_SCREEN = {
	PADDING = 20,
	ITEM_HEIGHT = 50,
	PREVIEW_PADDING = 20,
	PREVIEW_TEXT = "The quick brown fox jumps over the lazy dog. 0123456789 !@#$%^&*()_+-=[]{};:'\",.\\<>/?`~",
	PREVIEW_BG_CORNER_RADIUS = 10,
	PREVIEW_BOTTOM_MARGIN = 15, -- Margin between preview box and controls
}

-- Font items with their selected state
local fontItems = {}

-- Initialize font items based on constants.FONTS
local function initFontItems()
	fontItems = {}
	for _, fontItem in ipairs(constants.FONTS) do
		table.insert(fontItems, {
			name = fontItem.name,
			selected = fontItem.name == state.selectedFont,
		})
	end
end

function font.load()
	initFontItems()
end

function font.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	-- Draw font items (moved upward by removing title)
	local startY = FONT_SCREEN.PADDING

	for i, item in ipairs(fontItems) do
		local y = startY + (i - 1) * (FONT_SCREEN.ITEM_HEIGHT + FONT_SCREEN.PADDING)

		-- Draw item background if selected
		if item.selected then
			love.graphics.setColor(colors.ui.surface)
			love.graphics.rectangle("fill", 0, y, state.screenWidth, FONT_SCREEN.ITEM_HEIGHT, 0)
		end

		-- Draw item text in its own font
		love.graphics.setColor(colors.ui.foreground)

		-- Use the appropriate font for the item
		if item.name == "Inter" then
			love.graphics.setFont(state.fonts.body)
		elseif item.name == "Cascadia Code" then
			love.graphics.setFont(state.fonts.monoBody)
		elseif item.name == "Retro Pixel" then
			love.graphics.setFont(state.fonts.retroPixel)
		else
			love.graphics.setFont(state.fonts.nunito)
		end

		local textHeight = love.graphics.getFont():getHeight()
		love.graphics.print(item.name, FONT_SCREEN.PADDING, y + (FONT_SCREEN.ITEM_HEIGHT - textHeight) / 2)
	end

	-- Find the currently hovered font
	local hoveredFontName = state.selectedFont -- Default to selected font
	for _, item in ipairs(fontItems) do
		if item.selected then
			hoveredFontName = item.name
			break
		end
	end

	-- Set the font for preview text based on the hovered font
	if hoveredFontName == "Inter" then
		love.graphics.setFont(state.fonts.body)
	elseif hoveredFontName == "Cascadia Code" then
		love.graphics.setFont(state.fonts.monoBody)
	elseif hoveredFontName == "Retro Pixel" then
		love.graphics.setFont(state.fonts.retroPixel)
	else
		love.graphics.setFont(state.fonts.nunito)
	end

	-- Calculate preview text area dimensions
	local previewWidth = state.screenWidth - (FONT_SCREEN.PADDING * 2)

	-- Calculate preview text height for background
	local _, textLines =
		love.graphics.getFont():getWrap(FONT_SCREEN.PREVIEW_TEXT, previewWidth - (FONT_SCREEN.PADDING * 2))
	local textHeight = #textLines * love.graphics.getFont():getHeight() + FONT_SCREEN.PADDING * 2

	-- Calculate preview position at bottom of screen, above controls
	local previewY = state.screenHeight - controls.HEIGHT - textHeight - FONT_SCREEN.PREVIEW_BOTTOM_MARGIN

	-- Draw rounded background for preview text
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle(
		"fill",
		FONT_SCREEN.PADDING,
		previewY,
		previewWidth,
		textHeight,
		FONT_SCREEN.PREVIEW_BG_CORNER_RADIUS
	)

	-- Draw preview text
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.printf(
		FONT_SCREEN.PREVIEW_TEXT,
		FONT_SCREEN.PADDING * 2,
		previewY + FONT_SCREEN.PADDING,
		previewWidth - (FONT_SCREEN.PADDING * 2),
		"left"
	)

	-- Draw controls
	controls.draw({
		{ icon = "d_pad.png", text = "Navigate" },
		{ icon = "a.png", text = "Select" },
		{ icon = "b.png", text = "Back" },
	})
end

function font.update(_dt)
	if not state.canProcessInput() then
		return
	end

	local virtualJoystick = require("input").virtualJoystick
	local moved = false

	-- Handle D-pad up/down navigation
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		local direction = virtualJoystick:isGamepadDown("dpup") and -1 or 1

		-- Find currently selected item
		local currentIndex = 1
		for i, item in ipairs(fontItems) do
			if item.selected then
				currentIndex = i
				item.selected = false
				break
			end
		end

		-- Calculate new index with wrapping
		local newIndex = currentIndex + direction
		if newIndex < 1 then
			newIndex = #fontItems
		elseif newIndex > #fontItems then
			newIndex = 1
		end

		-- Select new item
		fontItems[newIndex].selected = true
		moved = true
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
				state.selectedFont = item.name

				-- Update constants.FONTS to match
				for _, fontItem in ipairs(constants.FONTS) do
					fontItem.selected = (fontItem.name == item.name)
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

	-- Reset input timer if moved
	if moved then
		state.resetInputTimer()
	end
end

function font.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- Function called when entering this screen
function font.onEnter()
	-- Reinitialize font items to ensure they match the current state
	initFontItems()
end

return font
