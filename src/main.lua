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
local system = require("utils.system")

-- Screens module will be initialized after loading
local screens = nil

-- Function to load settings from file
local function loadSettings()
	return settings.loadFromFile()
end

-- Function to save settings to file
local function saveSettings()
	return settings.saveToFile()
end

function love.load()
	local envWidth = tonumber(os.getenv("WIDTH"))
	local envHeight = tonumber(os.getenv("HEIGHT"))
	if envWidth and envHeight and envWidth > 0 and envHeight > 0 then
		state.screenWidth = envWidth
		state.screenHeight = envHeight
		logger.debug("Using environment dimensions: " .. envWidth .. "x" .. envHeight)
	else
		logger.warning("Using default dimensions")
	end

	logger.info("Screen dimensions: " .. state.screenWidth .. "x" .. state.screenHeight)
	state.fadeDuration = 0.5

	fonts.initializeFonts(state.screenWidth, state.screenHeight)

	input.load()

	-- Load user settings if they exist
	loadSettings()

	-- Check if device has RGB support before performing RGB operations
	state.hasRGBSupport = system.hasRGBSupport()
	logger.info("RGB support: " .. (state.hasRGBSupport and "enabled" or "disabled"))

	if state.hasRGBSupport then
		-- Backup the current RGB config if it exists
		local backupSuccess = rgbUtils.backupCurrentConfig()
		if not backupSuccess then
			errorHandler.setError("Failed to backup current RGB config")
		end
		rgbUtils.updateConfig() -- Apply RGB settings from state
	else
		logger.info("Skipping RGB operations - device does not support RGB lighting")
	end

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
	logger.debug("Window resized to: " .. w .. "x" .. h)
	-- Update screen dimensions in state
	state.screenWidth, state.screenHeight = w, h

	-- Recalculate and reload fonts
	fonts.initializeFonts(state.screenWidth, state.screenHeight)

	-- Reload the current screen to update layout
	if screens then
		local currentScreen = screens.getCurrentScreen()
		if currentScreen then
			logger.debug("Reloading screen: " .. currentScreen)
			screens.switchTo(currentScreen)
		end
	end
end

function love.update(dt)
	input.update(dt)

	-- Use the screens module that was loaded in love.load
	if screens then
		screens.update(dt)
	else
		logger.error("screens module is nil in love.update")
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
	else
		logger.error("screens module is nil in love.draw")
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
	logger.debug("Application quitting")
	saveSettings()

	-- Restore original RGB configuration if no theme was applied
	if state.hasRGBSupport and not state.themeApplied then
		logger.debug("Restoring original RGB config")
		rgbUtils.restoreConfig()
	end
end

return state
