--- Screen manager module
local screens = {}
local love = require("love")

-- Private state
local currentScreen = "menu" -- Default screen
local registeredScreens = {}

-- Register a screen module
function screens.register(screenName, screenModule)
	if not screenName then
		error("Screen name cannot be nil")
	end

	registeredScreens[screenName] = screenModule

	-- Initialize screen switcher function
	if screenModule.setScreenSwitcher then
		screenModule.setScreenSwitcher(function(targetScreen, tabName)
			screens.switchTo(targetScreen, tabName)
		end)
	end
end

function screens.getCurrentScreen()
	return currentScreen
end

function screens.switchTo(screenName, tabName)
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

	-- Switch screens
	currentScreen = screenName

	-- Call enter handler on new screen if it exists
	local newModule = registeredScreens[currentScreen]
	if newModule and newModule.onEnter then
		newModule.onEnter(tabName)
	end
end

function screens.draw()
	local currentModule = registeredScreens[currentScreen]
	if currentModule and currentModule.draw then
		currentModule.draw()
	end
end

function screens.update(dt)
	local currentModule = registeredScreens[currentScreen]
	if currentModule and currentModule.update then
		currentModule.update(dt)
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
	for _, module in pairs(registeredScreens) do
		if module.load then
			module.load()
		end
	end

	-- Update font selection based on state
	local fontDefs = require("ui.font_defs")
	local state = require("state")
	for _, font in ipairs(fontDefs.FONTS) do
		font.selected = (font.name == state.selectedFont)
	end
end

return screens
