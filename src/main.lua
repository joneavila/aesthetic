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

-- Fade duration for screen transitions
local fadeDuration = 0.5

function love.load()
	state.screenWidth = tonumber(system.getEnvironmentVariable("WIDTH"))
	state.screenHeight = tonumber(system.getEnvironmentVariable("HEIGHT"))
	logger.info("Screen dimensions: " .. state.screenWidth .. "x" .. state.screenHeight)

	fonts.initializeFonts(state.screenWidth, state.screenHeight)
	input.load()
	settings.loadFromFile()

	-- Check if device has RGB support before performing RGB operations
	state.hasRGBSupport = system.hasRGBSupport()

	if state.hasRGBSupport then
		rgbUtils.backupConfig()
		rgbUtils.updateConfig()
	end

	-- Initialize system version state
	state.systemVersion = system.getSystemVersion()

	-- Load UI components that require initialization
	screens = require("screens")
	screens.load()

	-- Start with the splash screen
	screens.switchTo("splash")

	-- Fade effect will be handled after splash screen completes
	state.fading = false
end

-- Function to handle window resize
function love.resize(width, height)
	logger.debug("Window resized to: " .. width .. "x" .. height)
	state.screenWidth, state.screenHeight = width, height

	-- Recalculate and reload fonts
	fonts.initializeFonts(state.screenWidth, state.screenHeight)

	-- Reload the current screen to update layout
	local currentScreen = screens.getCurrentScreen()
	logger.debug("Reloading screen: " .. currentScreen)
	screens.switchTo(currentScreen)
end

function love.update(dt)
	input.update(dt)

	screens.update(dt)

	if state.fading then
		state.fadeTimer = state.fadeTimer + dt
		if state.fadeTimer >= fadeDuration then
			state.fadeTimer = fadeDuration
			state.fading = false
		end
	end
end

function love.draw()
	love.graphics.origin() -- TODO: Reset coordinate system to default does not fix TrimUI Brick GOOSE bug
	screens.draw()

	-- Debug: Draw a red square at 0,0
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("fill", 0, 0, 10, 10)

	-- Apply the fade-in overlay
	if state.fading then
		local fadeProgress = state.fadeTimer / fadeDuration
		local fadeAlpha = 1 - fadeProgress
		love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], fadeAlpha)
		love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)
	end
end

-- Handle application exit
function love.quit()
	logger.debug("Application quitting")
	settings.saveToFile()

	-- Restore original RGB configuration if no theme was applied
	if state.hasRGBSupport and not state.themeApplied then
		rgbUtils.restoreConfig()
	end
end

return state
