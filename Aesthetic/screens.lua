--- Screen manager module
local screens = {}

-- Screen states as an enum-like table
screens.STATES = {
	MENU = "menu",
	COLORPICKERPALETTE = "colorpickerpalette",
	COLORPICKERHSV = "colorpickerhsv",
	ABOUT = "about",
}

-- Private state
local currentScreen = screens.STATES.MENU
local registeredScreens = {}

-- Register a screen module
function screens.register(screenName, screenModule)
	if not screens.STATES[screenName:upper()] then
		error("Attempting to register invalid screen: " .. screenName)
	end

	registeredScreens[screenName] = screenModule

	-- Initialize screen switcher function
	if screenModule.setScreenSwitcher then
		screenModule.setScreenSwitcher(function(targetScreen)
			screens.switchTo(targetScreen)
		end)
	end
end

function screens.getCurrentScreen()
	return currentScreen
end

function screens.switchTo(screenName)
	-- Validate screen name
	if not screens.STATES[screenName:upper()] then
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
		newModule.onEnter()
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
	-- Load all registered screens
	for _, module in pairs(registeredScreens) do
		if module.load then
			module.load()
		end
	end
end

return screens
