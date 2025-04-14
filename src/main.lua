--- Main application entry point

--[[
                         _                _
    /\              _   | |          _   (_)
   /  \   ____  ___| |_ | | _   ____| |_  _  ____
  / /\ \ / _  )/___)  _)| || \ / _  )  _)| |/ ___)
 | |__| ( (/ /|___ | |__| | | ( (/ /| |__| ( (___
 |______|\____|___/ \___)_| |_|\____)\___)_|\____)
--]]

local love = require("love")
local input = require("input")
local splash = require("splash")
local screens = require("screens")
local colors = require("colors")
local state = require("state")

-- Input delay handling
local lastInpuSeconds = 0
local inputDelaySeconds = 0.2

function state.canProcessInput()
	return lastInpuSeconds >= inputDelaySeconds
end

function state.resetInputTimer()
	lastInpuSeconds = 0
end

function state.forceInputDelay(extraDelay)
	-- Set lastInputSeconds to a negative value to force an additional delay
	lastInpuSeconds = -extraDelay
end

local function updateInputTimer(dt)
	lastInpuSeconds = lastInpuSeconds + dt
end

local function setupFonts()
	-- Calculate font sizes based on reference resolution and aspect ratio

	-- The default muOS Pixie theme includes the following resolutions:
	-- 	640x480
	-- 	720x480
	-- 	720x576
	-- 	720x720
	-- 	1024x768
	-- 	1280x720

	-- Reference resolution is 720x720 (square display)
	local referenceWidth = 720
	local referenceHeight = 720

	-- Calculate scaling factors
	local widthRatio = state.screenWidth / referenceWidth
	local heightRatio = state.screenHeight / referenceHeight

	-- Use the smaller ratio to ensure text doesn't get too small on low-res displays
	-- Add a minimum scale factor to prevent fonts from becoming too small
	local scaleFactor = math.max(math.min(widthRatio, heightRatio), 0.8)

	-- Initialize the font name mapping
	state.initFontNameMapping()

	-- Create all fonts using the font definitions and scaling
	state.fonts = {}
	for key, def in pairs(state.fontDefs) do
		local fontSize = def.size * scaleFactor
		state.fonts[key] = love.graphics.newFont(def.path, fontSize)
	end
end

function love.load()
	-- Alternatively, use the muOS GET_VAR function (load the file containing the GET_VAR function first)
	-- 		$(GET_VAR device mux/width)
	-- 		$(GET_VAR device mux/height)
	state.screenWidth, state.screenHeight = love.graphics.getDimensions()
	state.fadeDuration = 0.5
	setupFonts()

	-- Create the callback
	local function onSplashDone()
		state.splash = nil -- Clear splash screen
		input.load()

		-- Apply RGB lighting settings when first launching application
		local rgbUtils = require("utils.rgb")
		rgbUtils.initializeFromCurrentConfig()
		rgbUtils.updateConfig()

		screens.load()
		state.fading = true -- Start the fade effect
		state.fadeTimer = 0 -- Reset fade timer
	end

	-- Initialize the splash screen with the callback and font
	local splashInstance = splash({
		onDone = onSplashDone,
		font = state.fonts.monoTitle,
	})

	state.splash = {
		update = function(_, dt)
			return splashInstance:update(dt)
		end,
		draw = function()
			return splashInstance:draw()
		end,
		onDone = onSplashDone, -- Store callback reference
	}
end

function love.update(dt)
	if state.splash then
		state.splash:update(dt)
	else
		updateInputTimer(dt)
		input.update(dt)
		screens.update(dt)
		if state.fading then
			state.fadeTimer = state.fadeTimer + dt
			if state.fadeTimer >= state.fadeDuration then
				state.fadeTimer = state.fadeDuration
				state.fading = false
			end
		end
	end
end

function love.draw()
	if state.splash then
		state.splash:draw()
	else
		-- Calculate the fade progress (0 to 1)
		local fadeProgress = state.fading and (state.fadeTimer / state.fadeDuration) or 1

		-- Set the opacity for the menu content based on fade progress
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], fadeProgress)
		screens.draw()
		love.graphics.setColor(colors.ui.foreground)

		-- Apply the fade-in overlay
		if state.fading then
			local fadeAlpha = 1 - fadeProgress
			love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], fadeAlpha)
			love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)
		end
	end
end

-- Handle application exit
function love.quit()
	-- Restore original RGB configuration if no theme was applied
	local rgbUtils = require("utils.rgb")
	if not state.themeApplied then
		rgbUtils.restoreConfig()
	end
end

return state
