--[[
   Screen manager module
   This module manages application screens, handling screen registration, switching, and lifecycle methods
   (load, enter, exit, update, draw). It automatically loads screens from the `screens` directory and
   supports returning value passing between screens.
]]

--- Screen manager module
local screens = {}
local love = require("love")

-- Private state
local currentScreen = "main_menu" -- Default screen
local registeredScreens = {}
local returnValue = nil -- Store return values from screens

-- Input cooldown state
local inputCooldownTimer = 0
local INPUT_COOLDOWN_DURATION = 0.3

-- Register a screen module
function screens.register(screenName, screenModule)
	if not screenName then
		error("Screen name cannot be nil")
	end

	registeredScreens[screenName] = screenModule

	-- Debug log: print screen name and filename
	local logger = require("utils.logger")
	logger.debug("Registered screen: " .. tostring(screenName) .. " (screens/" .. tostring(screenName) .. ".lua)")
end

function screens.getCurrentScreen()
	return currentScreen
end

function screens.switchTo(screenName, tabName, retVal)
	-- Validate screen name
	if not registeredScreens[screenName] then
		error("Attempting to switch to invalid screen: " .. screenName)
		return
	end

	-- Call exit handler on current screen if it exists
	local currentModule = registeredScreens[currentScreen]
	if currentModule and currentModule.onExit then
		currentModule.onExit()
	end

	-- Store return value
	returnValue = retVal

	-- Switch screens
	currentScreen = screenName

	-- Reset input cooldown timer when switching screens
	inputCooldownTimer = INPUT_COOLDOWN_DURATION

	-- Call enter handler on new screen if it exists
	local newModule = registeredScreens[currentScreen]
	if newModule and newModule.onEnter then
		newModule.onEnter(tabName, returnValue)
	end

	-- Set default font to ensure consistent rendering across screens
	local state = require("state")
	state.setDefaultFont()

	return returnValue
end

function screens.getReturnValue()
	return returnValue
end

function screens.draw()
	love.graphics.push()
	local currentModule = registeredScreens[currentScreen]
	if currentModule and currentModule.draw then
		currentModule.draw()
	end
	love.graphics.pop()
end

function screens.update(dt)
	-- Decrement input cooldown timer
	if inputCooldownTimer > 0 then
		inputCooldownTimer = inputCooldownTimer - dt
	end

	local currentModule = registeredScreens[currentScreen]
	if currentModule and currentModule.update then
		-- Only call update if cooldown is finished or screen is a modal
		-- (Modals handle their own input logic and shouldn't be affected by screen transition cooldown)
		if inputCooldownTimer <= 0 or currentScreen:match("_modal$") then
			currentModule.update(dt)
		end
	end
end

function screens.load()
	-- Auto-load screens from the screen directory
	local screenFiles = love.filesystem.getDirectoryItems("screens")

	for _, file in ipairs(screenFiles) do
		-- Remove the .lua extension to get the screen name
		local screenName = file:match("^(.+)%.lua$")
		if screenName then
			local screenModule = require("screens." .. screenName)
			screens.register(screenName, screenModule)
		end
	end

	-- Load all registered screens
	for screenName, module in pairs(registeredScreens) do
		local logger = require("utils.logger")
		logger.debug(
			"Calling load() for screen: " .. tostring(screenName) .. " (screens/" .. tostring(screenName) .. ".lua)"
		)
		if module.load then
			module.load()
		end
	end
end

return screens
