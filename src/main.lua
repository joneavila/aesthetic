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
local fonts = require("ui.fonts")
local settings = require("utils.settings")
local logger = require("utils.logger")
local errorHandler = require("error_handler")
local rgbUtils = require("utils.rgb")

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

-- Function to setup fonts based on reference resolution and aspect ratio
local function setupFonts()
	-- Reference resolution is 720x720
	local referenceWidth = 720
	local referenceHeight = 720

	local widthRatio = state.screenWidth / referenceWidth
	local heightRatio = state.screenHeight / referenceHeight

	-- Use the smaller ratio to ensure text doesn't get too small on low-res displays
	-- Add a minimum scale factor to prevent fonts from becoming too small
	-- TODO: Change value from 1.0 or remove scaling
	local scaleFactor = math.max(math.min(widthRatio, heightRatio), 1.0)

	-- Update font sizes based on scale factor
	for _, def in pairs(fonts.definitions) do
		def.size = def.size * scaleFactor
	end

	fonts.loadFonts()

	-- Ensure font name mapping is initialized
	state.initFontNameMapping()

	fonts.setDefault()
end

-- Function to load settings from file
local function loadSettings()
	return settings.loadFromFile()
end

-- Function to save settings to file
local function saveSettings()
	return settings.saveToFile()
end

function love.load()
	state.screenWidth, state.screenHeight = love.graphics.getDimensions()
	state.fadeDuration = 0.5
	setupFonts()

	-- Apply default RGB lighting settings when first launching application
	input.load()

	-- Load user settings if they exist
	loadSettings()

	-- Backup the current RGB config if it exists
	local backupSuccess = rgbUtils.backupCurrentConfig()
	if not backupSuccess then
		errorHandler.setError("Failed to backup current RGB config")
	end
	rgbUtils.updateConfig() -- Apply RGB settings from state

	-- Load UI components that require initialization
	local button = require("ui.button")
	button.load()

	-- Now that state is initialized, load the screens module
	screens = require("screens")

	screens.load()

	-- Start with the splash screen
	screens.switchTo("splash")

	-- Fade effect will be handled after splash screen completes
	state.fading = false
end

-- Function to handle window resize
function love.resize(w, h)
	-- Update screen dimensions in state
	state.screenWidth, state.screenHeight = w, h

	-- Recalculate and reload fonts
	setupFonts()

	-- Reload the current screen to update layout
	if screens then
		local currentScreen = screens.getCurrentScreen()
		if currentScreen then
			screens.switchTo(currentScreen)
		end
	end
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
	saveSettings()

	-- Restore original RGB configuration if no theme was applied
	if not state.themeApplied then
		rgbUtils.restoreConfig()
	end
end

return state
