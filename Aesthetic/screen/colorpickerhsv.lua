--- Color picker screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local menuScreen = require("screen.menu")
local tween = require("tween")
local colorUtils = require("utils.color")
local controls = require("controls")

local colorpickerhsv = {}

-- Constants
local EDGE_PADDING = 20
local CONTROLS_HEIGHT = controls.HEIGHT
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
	TWEEN_DURATION = 0.1,
}
local CACHE_RESOLUTION_DIVIDER = 4
local HUE_UPDATE_THRESHOLD = 5 -- Only regenerate SV texture when hue changes by 5 degrees or more

-- State
local pickerState = {
	hue = 0, -- 0 to 360
	sat = 1, -- 0 to 1
	val = 1, -- 0 to 1
	focusSquare = true, -- true = SV square, false = Hue slider
	squareSize = nil, -- Will be calculated in load()
	sliderWidth = 40,
	startX = nil, -- Will be calculated in load()
	startY = nil, -- Will be calculated in load()
	contentHeight = nil,
	cursor = {
		svX = nil,
		svY = nil,
		hueY = nil,
	},
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
		lastFocusSquare = true, -- Track previous focus state
	},
}

-- Store screen switching function and target screen
local switchScreen = nil
local COLORPICKERPALETTE_SCREEN = "colorpickerpalette"

-- Helper function to convert HSV to RGB
local function hsvToRgb(h, s, v)
	h = h / 360
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)

	i = i % 6

	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	else
		return v, p, q
	end
end

-- Texture initialization
local function initializeCachedTextures()
	local cacheWidth = math.ceil(pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)
	local cacheHeight = math.ceil(pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)

	-- Generate the SV square texture
	local svImageData = love.image.newImageData(cacheWidth, cacheHeight)
	for y = 0, cacheHeight - 1 do
		for x = 0, cacheWidth - 1 do
			local s = x / (cacheWidth - 1)
			local v = 1 - (y / (cacheHeight - 1))
			local r, g, b = hsvToRgb(pickerState.hue, s, v)
			svImageData:setPixel(x, y, r, g, b, 1)
		end
	end
	pickerState.cache.svSquare = love.graphics.newImage(svImageData)
	pickerState.lastRenderedHue = pickerState.hue

	-- Generate the hue slider texture
	local hueImageData = love.image.newImageData(HUE_SLIDER_WIDTH, cacheHeight)
	for y = 0, cacheHeight - 1 do
		local h = (1 - y / (cacheHeight - 1)) * 360
		local r, g, b = hsvToRgb(h, 1, 1)
		for x = 0, HUE_SLIDER_WIDTH - 1 do
			hueImageData:setPixel(x, y, r, g, b, 1)
		end
	end
	pickerState.cache.hueSlider = love.graphics.newImage(hueImageData)
end

function colorpickerhsv.load()
	-- Calculate available space after removing edge padding and controls
	local availableHeight = state.screenHeight - (EDGE_PADDING * 2) - CONTROLS_HEIGHT
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
	pickerState.startY = EDGE_PADDING
	pickerState.hueSliderX = hueSliderX
	pickerState.previewX = previewX

	-- Initialize cursor positions
	pickerState.cursor.svX = pickerState.startX + (pickerState.sat * pickerState.squareSize)
	pickerState.cursor.svY = pickerState.startY + ((1 - pickerState.val) * pickerState.squareSize)
	pickerState.cursor.hueY = pickerState.startY + ((360 - pickerState.hue) / 360 * pickerState.squareSize)

	initializeCachedTextures()
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

function colorpickerhsv.draw()
	-- Set background
	love.graphics.setColor(colors.bg)
	love.graphics.clear()

	local lineWidth = 4
	local halfLine = lineWidth / 2

	-- Draw current color preview
	local currentColor = colors[state.colors[state.lastSelectedButton]]
	love.graphics.setColor(currentColor)
	love.graphics.rectangle("fill", pickerState.previewX, EDGE_PADDING, pickerState.previewWidth, PREVIEW_HEIGHT)

	-- Draw current color border using Relative Luminance Border Algorithm
	local borderR, borderG, borderB = colorUtils.calculateBorderColor(currentColor[1], currentColor[2], currentColor[3])
	love.graphics.setColor({ borderR, borderG, borderB })
	love.graphics.setLineWidth(lineWidth)
	love.graphics.rectangle(
		"line",
		pickerState.previewX - halfLine,
		EDGE_PADDING - halfLine,
		pickerState.previewWidth + lineWidth,
		PREVIEW_HEIGHT + lineWidth,
		CURSOR.CORNER_RADIUS
	)

	-- Draw "Current" label
	love.graphics.setColor(colors.fg, 0.7)
	love.graphics.setFont(state.fonts.caption)
	love.graphics.printf(
		"Current",
		pickerState.previewX,
		EDGE_PADDING + PREVIEW_HEIGHT + 5,
		pickerState.previewWidth,
		"center"
	)

	-- Draw new color preview with increased spacing
	local r, g, b = hsvToRgb(pickerState.hue, pickerState.sat, pickerState.val)
	love.graphics.setColor(r, g, b, 1)
	love.graphics.rectangle(
		"fill",
		pickerState.previewX,
		EDGE_PADDING + PREVIEW_HEIGHT + PREVIEW_SQUARE_SPACING,
		pickerState.previewWidth,
		PREVIEW_HEIGHT
	)

	-- Draw new color border using Relative Luminance Border Algorithm
	local newBorderR, newBorderG, newBorderB = colorUtils.calculateBorderColor(r, g, b)
	love.graphics.setColor(newBorderR, newBorderG, newBorderB, 1)
	love.graphics.rectangle(
		"line",
		pickerState.previewX - halfLine,
		EDGE_PADDING + PREVIEW_HEIGHT + PREVIEW_SQUARE_SPACING - halfLine,
		pickerState.previewWidth + lineWidth,
		PREVIEW_HEIGHT + lineWidth,
		CURSOR.CORNER_RADIUS
	)

	-- Draw "New" label with adjusted position
	love.graphics.setColor(colors.white, 0.7)
	love.graphics.printf(
		"New",
		pickerState.previewX,
		EDGE_PADDING + PREVIEW_HEIGHT + PREVIEW_SQUARE_SPACING + PREVIEW_HEIGHT + 5,
		pickerState.previewWidth,
		"center"
	)

	local wiggleOffset = pickerState.animation.wiggleOffset

	-- Draw Hue slider with wiggle
	local hueX = pickerState.hueSliderX
	if not pickerState.focusSquare then
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
	love.graphics.setColor(colors.white[1], colors.white[2], colors.white[3], pickerState.focusSquare and 0.2 or 1)
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
	if not pickerState.focusSquare then
		love.graphics.setColor(colors.white)
	else
		love.graphics.setColor(colors.white[1], colors.white[2], colors.white[3], 0.2)
	end

	-- Left triangle
	love.graphics.polygon(
		"fill",
		hueX - CURSOR.TRIANGLE_HORIZONTAL_OFFSET - CURSOR.TRIANGLE_SPACING - lineWidth,
		pickerState.cursor.hueY - CURSOR.TRIANGLE_HEIGHT / 2,
		hueX - CURSOR.TRIANGLE_HORIZONTAL_OFFSET - CURSOR.TRIANGLE_SPACING - lineWidth,
		pickerState.cursor.hueY + CURSOR.TRIANGLE_HEIGHT / 2,
		hueX - CURSOR.TRIANGLE_SPACING - lineWidth,
		pickerState.cursor.hueY
	)

	-- Right triangle
	love.graphics.polygon(
		"fill",
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_HORIZONTAL_OFFSET + CURSOR.TRIANGLE_SPACING + lineWidth,
		pickerState.cursor.hueY - CURSOR.TRIANGLE_HEIGHT / 2,
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_HORIZONTAL_OFFSET + CURSOR.TRIANGLE_SPACING + lineWidth,
		pickerState.cursor.hueY + CURSOR.TRIANGLE_HEIGHT / 2,
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_SPACING + lineWidth,
		pickerState.cursor.hueY
	)

	-- Draw SV square with wiggle
	local svX = pickerState.startX
	if pickerState.focusSquare then
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
	love.graphics.setColor(1, 1, 1, pickerState.focusSquare and 1 or 0.2)
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
	if pickerState.focusSquare then
		love.graphics.setColor(colors.white)
	else
		love.graphics.setColor(colors.white[1], colors.white[2], colors.white[3], 0.2)
	end
	love.graphics.setLineWidth(CURSOR.CIRCLE_LINE_WIDTH)
	love.graphics.circle("line", pickerState.cursor.svX, pickerState.cursor.svY, CURSOR.CIRCLE_RADIUS)

	-- Draw controls
	controls.draw({
		{
			icon = "d_pad.png",
			text = "Move cursor",
		},
		{
			icon = "y.png",
			text = "Swap cursor",
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
	-- Skip updates if hue hasn't changed enough to be noticeable
	-- This prevents unnecessary texture regeneration
	local hueDiff = math.abs(pickerState.hue - pickerState.lastRenderedHue)
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
			local r, g, b = hsvToRgb(pickerState.hue, s, v)
			svImageData:setPixel(x, y, r, g, b, 1)
		end
	end
	pickerState.cache.svSquare = love.graphics.newImage(svImageData)
	pickerState.lastRenderedHue = pickerState.hue
end

function colorpickerhsv.update(dt)
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

		-- Handle Y button for cursor swapping
		if virtualJoystick:isGamepadDown("y") then
			pickerState.focusSquare = not pickerState.focusSquare
			startWiggleAnimation() -- Start animation immediately after focus change
			moved = true
		end

		if pickerState.focusSquare then
			-- Handle SV square navigation
			local step = 0.04
			local newSat, newVal = pickerState.sat, pickerState.val

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
				pickerState.sat = newSat
				pickerState.val = newVal

				-- Create new tween for SV cursor
				local targetX = pickerState.startX + (newSat * pickerState.squareSize)
				local targetY = pickerState.startY + ((1 - newVal) * pickerState.contentHeight)
				pickerState.tweens.svCursor = tween.new(CURSOR.TWEEN_DURATION, pickerState.cursor, {
					svX = targetX,
					svY = targetY,
				}, "linear")
			end
		else
			-- Handle Hue slider navigation
			local step = 8
			if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
				local newHue = pickerState.hue
				if virtualJoystick:isGamepadDown("dpup") then
					newHue = (newHue + step) % 360
				else
					newHue = (newHue - step) % 360
				end

				pickerState.hue = newHue
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
				pickerState.tweens.hueCursor = tween.new(CURSOR.TWEEN_DURATION, pickerState.cursor, {
					hueY = baseY,
				}, "linear")

				moved = true
			end
		end

		-- Handle selection
		if virtualJoystick:isGamepadDown("a") then
			local r, g, b = hsvToRgb(pickerState.hue, pickerState.sat, pickerState.val)
			local colorKey = colors:addCustomColor(r, g, b)
			menuScreen.setSelectedColor(state.lastSelectedButton, colorKey)

			-- Switch back to menu
			if switchScreen then
				switchScreen("menu")
				state.resetInputTimer()
			end
			moved = true
		end

		-- Handle cancel
		if virtualJoystick:isGamepadDown("b") then
			if switchScreen then
				switchScreen(COLORPICKERPALETTE_SCREEN)
				state.resetInputTimer()
			end
			return
		end

		if moved then
			state.resetInputTimer()
		end
	end
end

function colorpickerhsv.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

return colorpickerhsv
