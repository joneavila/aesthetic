--- Color picker screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local menuScreen = require("screen.menu")
local tween = require("tween")
local colorUtils = require("utils.color")
local controls = require("controls")
local constants = require("screen.color_picker.constants")

local hsv = {}

-- Constants
local EDGE_PADDING = 20
local HUE_SLIDER_WIDTH = 32
local ELEMENT_SPACING = 20
local PREVIEW_SQUARE_SPACING = 60
local PREVIEW_HEIGHT = nil -- Will be calculated in load()
local CURSOR = {
	CIRCLE_RADIUS = 12,
	CIRCLE_LINE_WIDTH = 4,
	HUE_HEIGHT = 16,
	TRIANGLE_HEIGHT = 20,
	TRIANGLE_HORIZONTAL_OFFSET = 12,
	TRIANGLE_SPACING = 1,
	CORNER_RADIUS = 4,
	TWEEN_DURATION = 0.25,
}
local CACHE_RESOLUTION_DIVIDER = 4
local HUE_UPDATE_THRESHOLD = 5 -- Only regenerate SV texture when hue changes by 5 degrees or more

-- State
local pickerState = {
	background = {
		hue = 0, -- 0 to 360
		sat = 1, -- 0 to 1
		val = 1, -- 0 to 1
		focusSquare = false, -- true = SV square, false = Hue slider
		cursor = {
			svX = nil,
			svY = nil,
			hueY = nil,
		},
	},
	foreground = {
		hue = 0, -- 0 to 360
		sat = 1, -- 0 to 1
		val = 1, -- 0 to 1
		focusSquare = false, -- true = SV square, false = Hue slider
		cursor = {
			svX = nil,
			svY = nil,
			hueY = nil,
		},
	},
	squareSize = nil, -- Will be calculated in load()
	sliderWidth = 40,
	startX = nil, -- Will be calculated in load()
	startY = nil, -- Will be calculated in load()
	contentHeight = nil,
	-- Tween objects
	tweens = {
		svCursor = nil,
		hueCursor = nil,
	},
	-- Cache for gradient textures to avoid regenerating every frame
	cache = {
		svSquare = nil, -- Stores the saturation/value gradient
		hueSlider = nil, -- Stores the hue gradient
	},
	lastRenderedHue = 0, -- Track last rendered hue to limit texture updates
	-- Animation state for wiggle effect
	animation = {
		wiggleOffset = 0,
		wiggleTween = nil,
		lastFocusSquare = false, -- Track previous focus state
	},
}

-- Store screen switching function and target screen
local switchScreen = nil
local MENU_SCREEN = "menu"

-- Texture initialization
local function initializeCachedTextures()
	-- Get current color type state
	local colorType = state.lastSelectedColorButton
	local currentState = pickerState[colorType] or pickerState.background -- Default to background if nil

	local cacheWidth = math.ceil(pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)
	local cacheHeight = math.ceil(pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)

	-- Generate the SV square texture
	local svImageData = love.image.newImageData(cacheWidth, cacheHeight)
	for y = 0, cacheHeight - 1 do
		for x = 0, cacheWidth - 1 do
			local s = x / (cacheWidth - 1)
			local v = 1 - (y / (cacheHeight - 1))
			local r, g, b = colorUtils.hsvToRgb(currentState.hue, s, v)
			svImageData:setPixel(x, y, r, g, b, 1)
		end
	end
	pickerState.cache.svSquare = love.graphics.newImage(svImageData)
	pickerState.lastRenderedHue = currentState.hue

	-- Generate the hue slider texture
	local hueImageData = love.image.newImageData(HUE_SLIDER_WIDTH, cacheHeight)
	for y = 0, cacheHeight - 1 do
		local h = (1 - y / (cacheHeight - 1)) * 360
		local r, g, b = colorUtils.hsvToRgb(h, 1, 1)
		for x = 0, HUE_SLIDER_WIDTH - 1 do
			hueImageData:setPixel(x, y, r, g, b, 1)
		end
	end
	pickerState.cache.hueSlider = love.graphics.newImage(hueImageData)
end

local function startWiggleAnimation()
	-- Cancel any existing wiggle animation
	if pickerState.animation.wiggleTween then
		pickerState.animation.wiggleTween:set(pickerState.animation.wiggleTween.duration)
	end

	-- Create a sequence of positions for the wiggle
	local sequence = {
		[0.00] = 0, -- Start position
		[0.05] = 5, -- Right/down
		[0.15] = -4, -- Left/up
		[0.25] = 3, -- Right/down
		[0.35] = -2, -- Left/up
		[0.45] = 1, -- Right/down
		[0.55] = 0, -- Back to center
	}

	-- Create the wiggle tween
	local duration = 0.6
	local initial = {
		offset = sequence[0.05], -- Start at first peak of wiggle
	}

	pickerState.animation.wiggleOffset = initial.offset -- Set initial offset
	pickerState.animation.wiggleTween = tween.new(duration, pickerState.animation, {
		wiggleOffset = 0,
	}, "outElastic")
end

function hsv.load()
	-- Calculate available space
	local availableHeight = state.screenHeight - (EDGE_PADDING * 2) - controls.HEIGHT - constants.TAB_HEIGHT
	local availableWidth = state.screenWidth - (EDGE_PADDING * 2)

	-- Calculate SV square size - should be a perfect square that fits the available height
	pickerState.squareSize = availableHeight

	-- Calculate total width needed for SV square and hue slider with triangles and spacing
	local totalFixedWidth = pickerState.squareSize -- SV square
		+ HUE_SLIDER_WIDTH -- Hue slider
		+ (CURSOR.TRIANGLE_HEIGHT * 2) -- Space for triangles on both sides of hue slider
		+ (ELEMENT_SPACING * 2) -- Spacing between elements

	-- Calculate remaining width for preview squares
	pickerState.previewWidth = availableWidth - totalFixedWidth

	pickerState.sliderWidth = HUE_SLIDER_WIDTH
	pickerState.contentHeight = availableHeight

	-- Calculate preview height
	local labelHeight = 20
	PREVIEW_HEIGHT = math.floor((availableHeight - PREVIEW_SQUARE_SPACING - (labelHeight * 2)) / 2)

	-- Calculate positions for all elements (left to right)
	-- Preview squares position (leftmost)
	local previewX = EDGE_PADDING
	-- Hue slider position (after preview)
	local hueSliderX = previewX + pickerState.previewWidth + ELEMENT_SPACING + CURSOR.TRIANGLE_HEIGHT
	-- SV square position (rightmost, ensuring consistent right edge padding)
	pickerState.startX = state.screenWidth - EDGE_PADDING - pickerState.squareSize
	-- Store all positions
	pickerState.startY = EDGE_PADDING + constants.TAB_HEIGHT
	pickerState.hueSliderX = hueSliderX
	pickerState.previewX = previewX

	-- Get current color type state
	local colorType = state.lastSelectedColorButton
	local currentState = pickerState[colorType] or pickerState.background -- Default to background if nil

	-- Initialize cursor positions
	currentState.cursor.svX = pickerState.startX + (currentState.sat * pickerState.squareSize)
	currentState.cursor.svY = pickerState.startY + ((1 - currentState.val) * pickerState.squareSize)
	currentState.cursor.hueY = pickerState.startY + ((360 - currentState.hue) / 360 * pickerState.squareSize)
	initializeCachedTextures()

	-- Start with a wiggle animation on the hue slider to indicate focus
	startWiggleAnimation()
end

function hsv.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	-- Get current color type state
	local colorType = state.lastSelectedColorButton
	local currentState = pickerState[colorType] or pickerState.background -- Default to background if nil

	local lineWidth = 4
	local halfLine = lineWidth / 2

	-- Draw current color preview
	local hexColor = state.colors[state.lastSelectedColorButton]
	local r, g, b = colorUtils.hexToRgb(hexColor)

	love.graphics.setColor(r, g, b, 1)
	love.graphics.rectangle("fill", pickerState.previewX, pickerState.startY, pickerState.previewWidth, PREVIEW_HEIGHT)

	-- Draw current color border using Relative Luminance Border Algorithm
	local borderR, borderG, borderB = colorUtils.calculateBorderColor(r, g, b)
	love.graphics.setColor({ borderR, borderG, borderB })
	love.graphics.setLineWidth(lineWidth)
	love.graphics.rectangle(
		"line",
		pickerState.previewX - halfLine,
		pickerState.startY - halfLine,
		pickerState.previewWidth + lineWidth,
		PREVIEW_HEIGHT + lineWidth,
		CURSOR.CORNER_RADIUS
	)

	-- Draw "Current" label
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 0.7)
	love.graphics.setFont(state.fonts.caption)
	love.graphics.printf(
		"Current",
		pickerState.previewX,
		pickerState.startY + PREVIEW_HEIGHT + 5,
		pickerState.previewWidth,
		"center"
	)

	-- Draw new color preview with increased spacing
	r, g, b = colorUtils.hsvToRgb(currentState.hue, currentState.sat, currentState.val)
	love.graphics.setColor(r, g, b, 1)
	love.graphics.rectangle(
		"fill",
		pickerState.previewX,
		pickerState.startY + PREVIEW_HEIGHT + PREVIEW_SQUARE_SPACING,
		pickerState.previewWidth,
		PREVIEW_HEIGHT
	)

	-- Draw new color border using Relative Luminance Border Algorithm
	local newBorderR, newBorderG, newBorderB = colorUtils.calculateBorderColor(r, g, b)
	love.graphics.setColor(newBorderR, newBorderG, newBorderB, 1)
	love.graphics.rectangle(
		"line",
		pickerState.previewX - halfLine,
		pickerState.startY + PREVIEW_HEIGHT + PREVIEW_SQUARE_SPACING - halfLine,
		pickerState.previewWidth + lineWidth,
		PREVIEW_HEIGHT + lineWidth,
		CURSOR.CORNER_RADIUS
	)

	-- Draw "New" label with adjusted position
	love.graphics.setColor(colors.white, 0.7)
	love.graphics.printf(
		"New",
		pickerState.previewX,
		pickerState.startY + PREVIEW_HEIGHT + PREVIEW_SQUARE_SPACING + PREVIEW_HEIGHT + 5,
		pickerState.previewWidth,
		"center"
	)

	local wiggleOffset = pickerState.animation.wiggleOffset

	-- Draw Hue slider with wiggle
	local hueX = pickerState.hueSliderX
	if not currentState.focusSquare then
		hueX = hueX + wiggleOffset
	end

	love.graphics.setColor(colors.white)
	love.graphics.draw(
		pickerState.cache.hueSlider,
		hueX,
		pickerState.startY,
		0,
		1,
		pickerState.squareSize / (pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)
	)

	-- Draw Hue slider outline
	love.graphics.setColor(colors.white[1], colors.white[2], colors.white[3], currentState.focusSquare and 0.2 or 1)
	love.graphics.setLineWidth(lineWidth)
	love.graphics.rectangle(
		"line",
		hueX - halfLine,
		pickerState.startY - halfLine,
		HUE_SLIDER_WIDTH + lineWidth,
		pickerState.squareSize + lineWidth,
		CURSOR.CORNER_RADIUS
	)

	-- Draw hue selection triangles
	if not currentState.focusSquare then
		love.graphics.setColor(colors.white)
	else
		love.graphics.setColor(colors.white[1], colors.white[2], colors.white[3], 0.2)
	end

	-- Left triangle
	love.graphics.polygon(
		"fill",
		hueX - CURSOR.TRIANGLE_HORIZONTAL_OFFSET - CURSOR.TRIANGLE_SPACING - lineWidth,
		currentState.cursor.hueY - CURSOR.TRIANGLE_HEIGHT / 2,
		hueX - CURSOR.TRIANGLE_HORIZONTAL_OFFSET - CURSOR.TRIANGLE_SPACING - lineWidth,
		currentState.cursor.hueY + CURSOR.TRIANGLE_HEIGHT / 2,
		hueX - CURSOR.TRIANGLE_SPACING - lineWidth,
		currentState.cursor.hueY
	)

	-- Right triangle
	love.graphics.polygon(
		"fill",
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_HORIZONTAL_OFFSET + CURSOR.TRIANGLE_SPACING + lineWidth,
		currentState.cursor.hueY - CURSOR.TRIANGLE_HEIGHT / 2,
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_HORIZONTAL_OFFSET + CURSOR.TRIANGLE_SPACING + lineWidth,
		currentState.cursor.hueY + CURSOR.TRIANGLE_HEIGHT / 2,
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_SPACING + lineWidth,
		currentState.cursor.hueY
	)

	-- Draw SV square with wiggle
	local svX = pickerState.startX
	if currentState.focusSquare then
		svX = svX + wiggleOffset
	end

	love.graphics.setColor(colors.white)
	love.graphics.draw(
		pickerState.cache.svSquare,
		svX,
		pickerState.startY,
		0,
		pickerState.squareSize / (pickerState.squareSize / CACHE_RESOLUTION_DIVIDER),
		pickerState.squareSize / (pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)
	)

	-- Draw SV square outline
	love.graphics.setColor(1, 1, 1, currentState.focusSquare and 1 or 0.2)
	love.graphics.setLineWidth(lineWidth)
	love.graphics.rectangle(
		"line",
		svX - halfLine,
		pickerState.startY - halfLine,
		pickerState.squareSize + lineWidth,
		pickerState.squareSize + lineWidth,
		CURSOR.CORNER_RADIUS
	)

	-- Draw SV cursor
	if currentState.focusSquare then
		love.graphics.setColor(colors.white)
	else
		love.graphics.setColor(colors.white[1], colors.white[2], colors.white[3], 0.2)
	end
	love.graphics.setLineWidth(CURSOR.CIRCLE_LINE_WIDTH)
	love.graphics.circle("line", currentState.cursor.svX, currentState.cursor.svY, CURSOR.CIRCLE_RADIUS)

	-- Draw controls
	controls.draw({
		{
			icon = { "l1.png", "r1.png" },
			text = "Switch Tabs",
		},
		{
			icon = "d_pad.png",
			text = "Cursor",
		},
		{
			icon = "y.png",
			text = "HS/V",
		},
		{
			icon = "a.png",
			text = "Confirm",
		},
		{
			icon = "b.png",
			text = "Back",
		},
	})
end

-- Only regenerates the texture when necessary and at reduced resolution
local function updateSVSquare()
	-- Get current color type state
	local colorType = state.lastSelectedColorButton
	local currentState = pickerState[colorType] or pickerState.background -- Default to background if nil

	-- Skip updates if hue hasn't changed enough to be noticeable
	-- This prevents unnecessary texture regeneration
	local hueDiff = math.abs(currentState.hue - pickerState.lastRenderedHue)
	if hueDiff < HUE_UPDATE_THRESHOLD then
		return
	end

	local cacheWidth = math.ceil(pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)
	local cacheHeight = math.ceil(pickerState.contentHeight / CACHE_RESOLUTION_DIVIDER)

	local svImageData = love.image.newImageData(cacheWidth, cacheHeight)
	for y = 0, cacheHeight - 1 do
		for x = 0, cacheWidth - 1 do
			local s = x / (cacheWidth - 1)
			local v = 1 - (y / (cacheHeight - 1))
			local r, g, b = colorUtils.hsvToRgb(currentState.hue, s, v)
			svImageData:setPixel(x, y, r, g, b, 1)
		end
	end
	pickerState.cache.svSquare = love.graphics.newImage(svImageData)
	pickerState.lastRenderedHue = currentState.hue
end

function hsv.update(dt)
	-- Update any active tweens
	if pickerState.tweens.svCursor then
		pickerState.tweens.svCursor:update(dt)
	end
	if pickerState.tweens.hueCursor then
		pickerState.tweens.hueCursor:update(dt)
	end
	if pickerState.animation.wiggleTween then
		pickerState.animation.wiggleTween:update(dt)
	end

	if state.canProcessInput() then
		local virtualJoystick = require("input").virtualJoystick
		local moved = false

		-- Get current color type state
		local colorType = state.lastSelectedColorButton
		local currentState = pickerState[colorType] or pickerState.background -- Default to background if nil

		-- Handle Y button for cursor swapping
		if virtualJoystick:isGamepadDown("y") then
			currentState.focusSquare = not currentState.focusSquare
			startWiggleAnimation() -- Start animation immediately after focus change
			moved = true
		end

		if currentState.focusSquare then
			-- Handle SV square navigation
			local step = 0.03
			local newSat, newVal = currentState.sat, currentState.val

			if virtualJoystick:isGamepadDown("dpleft") then
				newSat = math.max(0, newSat - step)
				moved = true
			elseif virtualJoystick:isGamepadDown("dpright") then
				newSat = math.min(1, newSat + step)
				moved = true
			end
			if virtualJoystick:isGamepadDown("dpup") then
				newVal = math.min(1, newVal + step)
				moved = true
			elseif virtualJoystick:isGamepadDown("dpdown") then
				newVal = math.max(0, newVal - step)
				moved = true
			end

			if moved then
				currentState.sat = newSat
				currentState.val = newVal

				-- Create new tween for SV cursor
				local targetX = pickerState.startX + (newSat * pickerState.squareSize)
				local targetY = pickerState.startY + ((1 - newVal) * pickerState.contentHeight)
				pickerState.tweens.svCursor = tween.new(CURSOR.TWEEN_DURATION, currentState.cursor, {
					svX = targetX,
					svY = targetY,
				}, "outQuad")
			end
		else
			-- Handle Hue slider navigation
			local step = 6
			if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
				local newHue = currentState.hue
				if virtualJoystick:isGamepadDown("dpup") then
					newHue = (newHue + step) % 360
				else
					newHue = (newHue - step) % 360
				end

				currentState.hue = newHue
				-- Update the SV square when hue changes
				updateSVSquare()

				-- Calculate new cursor Y position
				local baseY = pickerState.startY + ((360 - newHue) / 360 * pickerState.contentHeight)
				local sliderBottom = pickerState.startY + pickerState.contentHeight

				-- Handle wrapping when cursor goes halfway off either end
				if baseY < pickerState.startY - (CURSOR.HUE_HEIGHT / 2) then
					-- Wrap from top to bottom
					baseY = sliderBottom - (CURSOR.HUE_HEIGHT / 2)
				elseif baseY > sliderBottom + (CURSOR.HUE_HEIGHT / 2) then
					-- Wrap from bottom to top
					baseY = pickerState.startY + (CURSOR.HUE_HEIGHT / 2)
				end

				-- Create new tween for hue cursor
				pickerState.tweens.hueCursor = tween.new(CURSOR.TWEEN_DURATION, currentState.cursor, {
					hueY = baseY,
				}, "outQuad")

				moved = true
			end
		end

		-- Handle selection
		if virtualJoystick:isGamepadDown("a") then
			local r, g, b = colorUtils.hsvToRgb(currentState.hue, currentState.sat, currentState.val)

			-- Create hex code using the utility function
			local hexCode = colorUtils.rgbToHex(r, g, b)

			-- Pass the hex code to menu
			menuScreen.setSelectedColor(state.lastSelectedColorButton, hexCode)

			-- Switch back to menu
			if switchScreen then
				switchScreen(MENU_SCREEN)
				state.resetInputTimer()
			end
			moved = true
		end

		if moved then
			state.resetInputTimer()
		end
	end
end

function hsv.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- Function to be called when entering this screen
function hsv.onEnter()
	-- Get current color type state
	local colorType = state.lastSelectedColorButton
	local currentState = pickerState[colorType] or pickerState.background -- Default to background if nil

	-- Initialize cursor positions if they haven't been set
	if currentState.cursor.svX == nil then
		currentState.cursor.svX = pickerState.startX + (currentState.sat * pickerState.squareSize)
	end
	if currentState.cursor.svY == nil then
		currentState.cursor.svY = pickerState.startY + ((1 - currentState.val) * pickerState.squareSize)
	end
	if currentState.cursor.hueY == nil then
		currentState.cursor.hueY = pickerState.startY + ((360 - currentState.hue) / 360 * pickerState.squareSize)
	end

	-- Update the SV square texture based on the current hue
	updateSVSquare()

	-- Start with a wiggle animation on the appropriate control based on focus
	startWiggleAnimation()
end

return hsv
