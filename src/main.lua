--- Main application entry point

--[[
  LÖVE Graphics State Best Practices
  - Always use `love.graphics.push("all")` and `love.graphics.pop()` in top-level screen draw functions to avoid state
    leakage.
  - Each component should also manage its own graphics state if it changes color, scissor, stencil, etc.
  - Unbalanced `push`/`pop` or early returns can cause subtle rendering bugs after screen transitions.
]]

--[[
                         _                _
    /\              _   | |          _   (_)
   /  \   ____  ___| |_ | | _   ____| |_  _  ____
  / /\ \ / _  )/___)  _)| || \ / _  )  _)| |/ ___)
 | |__| ( (/ /|___ | |__| | | ( (/ /| |__| ( (___
 |______|\____|___/ \___)_| |_|\____)\___)_|\____)
--]]

local love = require("love")

local colors = require("colors")
local input = require("input")
local state = require("state")
-- local font_calibration = require("font_calibration")

local fonts = require("ui.fonts")
local InputManager = require("ui.controllers.input_manager")
local FocusManager = require("ui.controllers.focus_manager")

local logger = require("utils.logger")
local rgbUtils = require("utils.rgb")
local settings = require("utils.settings")
local system = require("utils.system")

local focusManager = nil

-- Screens module will be initialized after loading
local screens = nil

-- Fade duration for screen transitions
local fadeDuration = 0.5

local function getInitialScreen()
	local envScreen = system.getEnvironmentVariable("INIT_SCREEN")
	if envScreen and #envScreen > 0 then
		return envScreen
	end
	return nil
end

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

	-- Load UI components that require initialization
	screens = require("screens")
	screens.load() -- Register all screens

	-- Explicitly load the splash screen since it's the first screen and needs immediate resources
	local splashScreen = require("screens.splash")
	splashScreen.load()
	splashScreen._loadedLazily = true -- Mark as already loaded to prevent double loading

	-- Determine which screen to start with
	local initialScreen = getInitialScreen() or "splash"
	if not screens.isRegistered(initialScreen) then
		print("Error: Initial screen '" .. tostring(initialScreen) .. "' is not registered. Exiting.")
		love.event.quit()
		return
	end
	screens.switchTo(initialScreen)

	-- Fade effect will be handled after splash screen completes
	state.fading = false

	-- Run font calibration (debugging)
	-- font_calibration.run()

	local focusManager = FocusManager:new()
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
	-- Called only once per frame.
	-- All other modules must not call it again to avoid errors from invalid `dt` values.
	InputManager.update(dt)
	if focusManager then
		focusManager:update(dt)
	end

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
	screens.draw()

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
	logger.debug("Exiting application")
	settings.saveToFile()

	-- Restore original RGB configuration if no theme was applied
	if state.hasRGBSupport and not state.themeApplied then
		rgbUtils.restoreConfig()
	end
end

return state
