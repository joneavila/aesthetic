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
local colors = require("colors")
local state = require("state")
local settings = require("utils.settings")
-- Remove the circular dependency by loading the screens module after state is initialized

-- Input delay handling
local lastInpuSeconds = 0
local inputDelaySeconds = 0.2
local screens = nil -- Will hold the screens module after initialization

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

	local widthRatio = state.screenWidth / referenceWidth
	local heightRatio = state.screenHeight / referenceHeight

	-- Use the smaller ratio to ensure text doesn't get too small on low-res displays
	-- Add a minimum scale factor to prevent fonts from becoming too small
	local scaleFactor = math.max(math.min(widthRatio, heightRatio), 1.0)

	-- Initialize the font name mapping
	state.initFontNameMapping()

	-- Create all fonts using the font definitions and scaling
	state.fonts = {}
	for key, def in pairs(state.fontDefs) do
		local fontSize = def.size * scaleFactor
		state.fonts[key] = love.graphics.newFont(def.path, fontSize)
	end

	-- Set the default font
	state.setDefaultFont()
end

-- Function to load settings from file
local function loadSettings()
	-- Try to load settings from file
	local success = settings.loadFromFile()

	-- We'll update the font selection state later when the menu screen is loaded
	-- This avoids circular dependencies

	return success
end

-- Function to save settings to file
local function saveSettings()
	return settings.saveToFile()
end

function love.load()
	-- Alternatively, use the muOS GET_VAR function (load the file containing the GET_VAR function first)
	-- 		$(GET_VAR device mux/width)
	-- 		$(GET_VAR device mux/height)
	state.screenWidth, state.screenHeight = love.graphics.getDimensions()
	state.fadeDuration = 0.5
	setupFonts()

	-- Apply default RGB lighting settings when first launching application
	input.load()

	-- Load user settings if they exist
	loadSettings()

	local rgbUtils = require("utils.rgb")
	rgbUtils.backupCurrentConfig() -- Backup the current RGB config if it exists
	rgbUtils.updateConfig() -- Apply RGB settings from state

	-- Now that state is initialized, load the screens module
	screens = require("screens")

	-- Load all screens
	screens.load()

	-- Start with the splash screen
	screens.switchTo("splash")

	state.fading = false -- Fade effect will be handled after splash screen completes
end

function love.update(dt)
	updateInputTimer(dt)
	input.update(dt)

	-- Use the screens module that was loaded in love.load
	if screens then
		screens.update(dt)
	end

	if state.fading then
		state.fadeTimer = state.fadeTimer + dt
		if state.fadeTimer >= state.fadeDuration then
			state.fadeTimer = state.fadeDuration
			state.fading = false
		end
	end
end

function love.draw()
	-- Draw the current screen using the screens module loaded in love.load
	if screens then
		screens.draw()
	end

	-- Apply the fade-in overlay if needed
	if state.fading then
		local fadeProgress = state.fadeTimer / state.fadeDuration
		local fadeAlpha = 1 - fadeProgress
		love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], fadeAlpha)
		love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)
	end
end

-- Handle application exit
function love.quit()
	-- Save current settings before exiting
	saveSettings()

	-- Restore original RGB configuration if no theme was applied
	local rgbUtils = require("utils.rgb")
	if not state.themeApplied then
		rgbUtils.restoreConfig()
	end
end

return state
