--- Color picker screen
local love = require("love")

local colors = require("colors")
local controls = require("control_hints")
local screens = require("screens")
local state = require("state")
local tween = require("tween")

local colorUtils = require("utils.color")

local constants = require("screens.color_picker.constants")

local background = require("ui.background")
local fonts = require("ui.fonts")

local hsv = {}

-- Constants
local EDGE_PADDING = 10
local HUE_SLIDER_WIDTH = 32
local ELEMENT_SPACING = 10
local PREVIEW_SQUARE_SPACING = 30
local PREVIEW_HEIGHT = nil -- Will be calculated in load()
local OPACITY_UNFOCUSED = 0.2

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

-- Helper function to get current HSV state from central state manager
local function getCurrentHsvState()
	local colorType = state.activeColorContext
	local context = state.getColorContext(colorType)
	return context.hsv -- Return the HSV specific state for this color context
end

-- Texture initialization
local function initializeCachedTextures()
	-- Get current color type state
	local currentState = getCurrentHsvState()

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

function hsv.draw()
	background.draw()

	-- Get current color type state
	local currentState = getCurrentHsvState()

	-- Draw current color preview
	local hexColor = state.getColorValue(state.activeColorContext)
	local r, g, b = colorUtils.hexToRgb(hexColor)

	love.graphics.setColor(r, g, b, 1)
	love.graphics.rectangle("fill", pickerState.previewX, pickerState.startY, pickerState.previewWidth, PREVIEW_HEIGHT)

	-- Draw current color border using Relative Luminance Border Algorithm
	local borderR, borderG, borderB = colorUtils.calculateContrastingColor(r, g, b)
	love.graphics.setColor({ borderR, borderG, borderB })
	love.graphics.setLineWidth(constants.OUTLINE.NORMAL_WIDTH)
	local halfLine = constants.OUTLINE.NORMAL_WIDTH / 2
	love.graphics.rectangle(
		"line",
		pickerState.previewX - halfLine,
		pickerState.startY - halfLine,
		pickerState.previewWidth + constants.OUTLINE.NORMAL_WIDTH,
		PREVIEW_HEIGHT + constants.OUTLINE.NORMAL_WIDTH,
		CURSOR.CORNER_RADIUS
	)

	-- Draw "Current" label
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(fonts.loaded.caption)
	love.graphics.printf(
		"Old",
		pickerState.previewX,
		pickerState.startY + PREVIEW_HEIGHT + 5,
		pickerState.previewWidth,
		"center"
	)

	local labelPadding = 15

	-- Draw new color preview with increased spacing
	r, g, b = colorUtils.hsvToRgb(currentState.hue, currentState.sat, currentState.val)
	love.graphics.setColor(r, g, b, 1)
	love.graphics.rectangle(
		"fill",
		pickerState.previewX,
		pickerState.startY + PREVIEW_HEIGHT + PREVIEW_SQUARE_SPACING + labelPadding,
		pickerState.previewWidth,
		PREVIEW_HEIGHT
	)

	-- Draw new color border using Relative Luminance Border Algorithm
	local newBorderR, newBorderG, newBorderB = colorUtils.calculateContrastingColor(r, g, b)
	love.graphics.setColor(newBorderR, newBorderG, newBorderB, 1)
	love.graphics.setLineWidth(constants.OUTLINE.NORMAL_WIDTH)
	halfLine = constants.OUTLINE.NORMAL_WIDTH / 2
	love.graphics.rectangle(
		"line",
		pickerState.previewX - halfLine,
		pickerState.startY + PREVIEW_HEIGHT + PREVIEW_SQUARE_SPACING + labelPadding - halfLine,
		pickerState.previewWidth + constants.OUTLINE.NORMAL_WIDTH,
		PREVIEW_HEIGHT + constants.OUTLINE.NORMAL_WIDTH,
		CURSOR.CORNER_RADIUS
	)

	-- Draw "New" label with adjusted position
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.printf(
		"New",
		pickerState.previewX,
		pickerState.startY + PREVIEW_HEIGHT + PREVIEW_SQUARE_SPACING + labelPadding + PREVIEW_HEIGHT + 5,
		pickerState.previewWidth,
		"center"
	)

	local wiggleOffset = pickerState.animation.wiggleOffset

	-- Draw Hue slider with wiggle
	local hueX = pickerState.hueSliderX
	if not currentState.focusSquare then
		hueX = hueX + wiggleOffset
	end

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.draw(
		pickerState.cache.hueSlider,
		hueX,
		pickerState.startY,
		0,
		1,
		pickerState.squareSize / (pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)
	)

	-- Draw Hue slider outline
	love.graphics.setColor(
		colors.ui.foreground[1],
		colors.ui.foreground[2],
		colors.ui.foreground[3],
		currentState.focusSquare and OPACITY_UNFOCUSED or 1
	)
	love.graphics.setLineWidth(
		currentState.focusSquare and constants.OUTLINE.NORMAL_WIDTH or constants.OUTLINE.SELECTED_WIDTH
	)
	local hueOutlineWidth = currentState.focusSquare and constants.OUTLINE.NORMAL_WIDTH
		or constants.OUTLINE.SELECTED_WIDTH
	halfLine = hueOutlineWidth / 2
	love.graphics.rectangle(
		"line",
		hueX - halfLine,
		pickerState.startY - halfLine,
		HUE_SLIDER_WIDTH + hueOutlineWidth,
		pickerState.squareSize + hueOutlineWidth,
		CURSOR.CORNER_RADIUS
	)

	-- Draw hue selection triangles
	if not currentState.focusSquare then
		love.graphics.setColor(colors.ui.foreground)
	else
		love.graphics.setColor(
			colors.ui.foreground[1],
			colors.ui.foreground[2],
			colors.ui.foreground[3],
			OPACITY_UNFOCUSED
		)
	end

	-- Left triangle
	love.graphics.polygon(
		"fill",
		hueX - CURSOR.TRIANGLE_HORIZONTAL_OFFSET - CURSOR.TRIANGLE_SPACING - halfLine,
		currentState.cursor.hueY - CURSOR.TRIANGLE_HEIGHT / 2,
		hueX - CURSOR.TRIANGLE_HORIZONTAL_OFFSET - CURSOR.TRIANGLE_SPACING - halfLine,
		currentState.cursor.hueY + CURSOR.TRIANGLE_HEIGHT / 2,
		hueX - CURSOR.TRIANGLE_SPACING - halfLine,
		currentState.cursor.hueY
	)

	-- Right triangle
	love.graphics.polygon(
		"fill",
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_HORIZONTAL_OFFSET + CURSOR.TRIANGLE_SPACING + halfLine,
		currentState.cursor.hueY - CURSOR.TRIANGLE_HEIGHT / 2,
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_HORIZONTAL_OFFSET + CURSOR.TRIANGLE_SPACING + halfLine,
		currentState.cursor.hueY + CURSOR.TRIANGLE_HEIGHT / 2,
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_SPACING + halfLine,
		currentState.cursor.hueY
	)

	-- Draw SV square with wiggle
	local svX = pickerState.startX
	if currentState.focusSquare then
		svX = svX + wiggleOffset
	end

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.draw(
		pickerState.cache.svSquare,
		svX,
		pickerState.startY,
		0,
		pickerState.squareSize / (pickerState.squareSize / CACHE_RESOLUTION_DIVIDER),
		pickerState.squareSize / (pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)
	)

	-- Draw SV square outline
	love.graphics.setColor(1, 1, 1, currentState.focusSquare and 1 or OPACITY_UNFOCUSED)
	love.graphics.setLineWidth(
		currentState.focusSquare and constants.OUTLINE.SELECTED_WIDTH or constants.OUTLINE.NORMAL_WIDTH
	)
	local svOutlineWidth = currentState.focusSquare and constants.OUTLINE.SELECTED_WIDTH
		or constants.OUTLINE.NORMAL_WIDTH
	halfLine = svOutlineWidth / 2
	love.graphics.rectangle(
		"line",
		svX - halfLine,
		pickerState.startY - halfLine,
		pickerState.squareSize + svOutlineWidth,
		pickerState.squareSize + svOutlineWidth,
		CURSOR.CORNER_RADIUS
	)

	-- Draw SV cursor
	if currentState.focusSquare then
		love.graphics.setColor(colors.ui.foreground)
	else
		love.graphics.setColor(
			colors.ui.foreground[1],
			colors.ui.foreground[2],
			colors.ui.foreground[3],
			OPACITY_UNFOCUSED
		)
	end
	love.graphics.setLineWidth(CURSOR.CIRCLE_LINE_WIDTH)
	love.graphics.circle("line", currentState.cursor.svX, currentState.cursor.svY, CURSOR.CIRCLE_RADIUS)

	-- Draw controls
	controls.draw({
		{
			button = { "leftshoulder", "rightshoulder" },
			text = "Switch Tabs",
		},
		{
			button = "y",
			text = "HS/V",
		},
		{
			button = "a",
			text = "Confirm",
		},
		{
			button = "b",
			text = "Back",
		},
	})
end

-- Only regenerates the texture when necessary and at reduced resolution
local function updateSVSquare()
	-- Get current color type state
	local currentState = getCurrentHsvState()

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

-- Helper function to update all active tweens
local function updateTweens(dt)
	if pickerState.tweens.svCursor then
		pickerState.tweens.svCursor:update(dt)
	end
	if pickerState.tweens.hueCursor then
		pickerState.tweens.hueCursor:update(dt)
	end
end

-- Helper function to update wiggle animation
local function updateWiggleAnimation(dt)
	if pickerState.animation.wiggleTween then
		pickerState.animation.wiggleTween:update(dt)
	end
end

function hsv.update(dt)
	-- Get current color type state
	local currentState = getCurrentHsvState()

	-- Update tweens
	updateTweens(dt)

	-- Update wiggle animation
	updateWiggleAnimation(dt)

	local virtualJoystick = require("input").virtualJoystick
	local moved = false

	-- Handle Y button for cursor swapping
	if virtualJoystick.isGamepadPressedWithDelay("y") then
		currentState.focusSquare = not currentState.focusSquare
		startWiggleAnimation() -- Start animation immediately after focus change
		moved = true
	end

	-- Get left stick values if joystick is connected
	local leftX, leftY = 0, 0
	local joystick = love.joystick.getJoysticks()[1]
	if joystick and joystick:isConnected() then
		-- Gamepad axes are typically:
		-- leftx = axis 1, lefty = axis 2
		if joystick:isGamepad() then
			leftX = joystick:getGamepadAxis("leftx")
			leftY = joystick:getGamepadAxis("lefty")
		else
			-- Fallback for non-gamepad joysticks
			leftX = joystick:getAxis(1)
			leftY = joystick:getAxis(2)
		end
	end

	if currentState.focusSquare then
		-- Handle SV square navigation
		local step = 0.03
		local newSat, newVal = currentState.sat, currentState.val

		-- D-pad controls
		if virtualJoystick.isGamepadPressedWithDelay("dpleft") then
			newSat = math.max(0, newSat - step)
			moved = true
		elseif virtualJoystick.isGamepadPressedWithDelay("dpright") then
			newSat = math.min(1, newSat + step)
			moved = true
		end
		if virtualJoystick.isGamepadPressedWithDelay("dpup") then
			newVal = math.min(1, newVal + step)
			moved = true
		elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
			newVal = math.max(0, newVal - step)
			moved = true
		end

		-- Left joystick controls
		if leftX ~= 0 then
			newSat = math.max(0, math.min(1, newSat + leftX * step))
			moved = true
		end
		if leftY ~= 0 then
			newVal = math.max(0, math.min(1, newVal - leftY * step))
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
		local newHue = currentState.hue
		local hueChanged = false

		-- D-pad UP: move cursor up on slider (increase hue value)
		if virtualJoystick.isGamepadPressedWithDelay("dpup") then
			newHue = (newHue + step) % 360
			hueChanged = true
		end

		-- D-pad DOWN: move cursor down on slider (decrease hue value)
		if virtualJoystick.isGamepadPressedWithDelay("dpdown") then
			newHue = (newHue - step) % 360
			hueChanged = true
		end

		if hueChanged then
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
		end

		-- Left joystick Y-axis controls for hue
		if leftY ~= 0 then
			newHue = (newHue - leftY * step) % 360

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
		end
	end

	-- Handle selection
	if virtualJoystick.isGamepadPressedWithDelay("a") then
		local r, g, b = colorUtils.hsvToRgb(currentState.hue, currentState.sat, currentState.val)

		-- Create hex code using the utility function
		local hexCode = colorUtils.rgbToHex(r, g, b)

		-- Store in the central state
		local context = state.getColorContext(state.activeColorContext)
		context.currentColor = hexCode

		-- Set the color value in state
		state.setColorValue(state.activeColorContext, hexCode)

		screens.switchTo(state.previousScreen)
	end
end

function hsv.onEnter()
	-- Initialize layout if not already done
	if not pickerState.squareSize then
		local contentArea = constants.calculateContentArea()

		-- Calculate available space
		local availableHeight = contentArea.height - (EDGE_PADDING * 2)
		local availableWidth = contentArea.width - (EDGE_PADDING * 2)

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
		local labelPadding = 15 -- Match the value used in draw function
		PREVIEW_HEIGHT = math.floor((availableHeight - PREVIEW_SQUARE_SPACING - labelPadding - (labelHeight * 2)) / 2)

		-- Calculate positions for all elements (left to right)
		-- Preview squares position (leftmost)
		local previewX = EDGE_PADDING
		-- Hue slider position (after preview)
		local hueSliderX = previewX + pickerState.previewWidth + ELEMENT_SPACING + CURSOR.TRIANGLE_HEIGHT
		-- SV square position (rightmost, ensuring consistent right edge padding)
		pickerState.startX = contentArea.width - EDGE_PADDING - pickerState.squareSize
		-- Store all positions
		pickerState.startY = contentArea.y + EDGE_PADDING
		pickerState.hueSliderX = hueSliderX
		pickerState.previewX = previewX

		initializeCachedTextures()
	end

	-- Get current color type state
	local currentState = getCurrentHsvState()

	-- Initialize cursor positions
	currentState.cursor.svX = pickerState.startX + (currentState.sat * pickerState.squareSize)
	currentState.cursor.svY = pickerState.startY + ((1 - currentState.val) * pickerState.squareSize)
	currentState.cursor.hueY = pickerState.startY + ((360 - currentState.hue) / 360 * pickerState.squareSize)

	-- Update the SV square texture based on the current hue
	updateSVSquare()

	-- Start with a wiggle animation on the appropriate control based on focus
	startWiggleAnimation()
end

return hsv
