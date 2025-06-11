--- Color picker screen with tabbed interface
local screens = require("screens")
local state = require("state")

local Header = require("ui.header")
local TabBar = require("ui.tab_bar")

local hexScreen = require("screens.color_picker.hex")
local hsvScreen = require("screens.color_picker.hsv")
local paletteScreen = require("screens.color_picker.palette")

local controls = require("control_hints").ControlHints
local controlHintsInstance

local colorPicker = {}

local tabBar

local TAB_BAR_HORIZONTAL_PADDING = 16
local COMPONENT_SPACING = 8
local TAB_BAR_START_Y = Header:new({ title = "Color Picker" }):getContentStartY() + COMPONENT_SPACING

-- Helper function to format color context for display
local function formatColorContext(context)
	if context == "background" then
		return "Background"
	elseif context == "foreground" then
		return "Foreground"
	elseif context == "rgb" then
		return "RGB Lighting"
	else
		-- Capitalize first letter
		return context:sub(1, 1):upper() .. context:sub(2)
	end
end

function colorPicker.draw()
	-- Draw the active sub-screen first, underneath the tabs
	if tabBar then
		local activeTab = tabBar:getActiveTab()
		if activeTab and activeTab.screen and activeTab.screen.draw then
			activeTab.screen.draw()
		end
	end

	-- Draw header with current color context
	local title = formatColorContext(state.activeColorContext)
	local headerInstance = Header:new({ title = title })
	headerInstance:draw()

	-- Draw the tab bar with left/right padding
	if tabBar then
		tabBar.x = TAB_BAR_HORIZONTAL_PADDING
		tabBar.y = TAB_BAR_START_Y
		tabBar.width = state.screenWidth - (TAB_BAR_HORIZONTAL_PADDING * 2)
		tabBar:draw()
	end

	-- If you want to show color picker global controls, add here:
	-- local controlsList = { { button = "b", text = "Back" } }
	-- controlHintsInstance:setControlsList(controlsList)
	-- controlHintsInstance:draw()
end

function colorPicker.update(dt)
	if tabBar then
		tabBar:update(dt)
		local activeTab = tabBar:getActiveTab()
		if activeTab and activeTab.screen and activeTab.screen.update then
			activeTab.screen.update(dt)
		end
	end

	local virtualJoystick = require("input").virtualJoystick

	if virtualJoystick.isGamepadPressedWithDelay("b") then
		screens.switchTo(state.previousScreen)
	end
end

function colorPicker.onEnter(tabName)
	tabBar = TabBar:new({
		tabs = {
			{ name = "Palette", screen = paletteScreen },
			{ name = "HSV", screen = hsvScreen },
			{ name = "Hex", screen = hexScreen },
		},
		width = state.screenWidth - (TAB_BAR_HORIZONTAL_PADDING * 2),
		height = colorPicker.TAB_HEIGHT,
		x = TAB_BAR_HORIZONTAL_PADDING,
		y = TAB_BAR_START_Y,
		onTabSwitched = function(tab)
			if tab.screen.onEnter then
				tab.screen.onEnter()
			end
		end,
	})
	if tabName then
		tabBar:switchToTab(tabName)
	else
		tabBar:switchToTab("Palette")
	end

	-- Load all sub-screens
	for _, tab in ipairs(tabBar.tabs) do
		if tab.screen.load then
			tab.screen.load()
		end
	end

	-- Notify all sub-screens about header height for positioning
	for _, tab in ipairs(tabBar.tabs) do
		if tab.screen.updateLayout then
			tab.screen.updateLayout()
		end
	end

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

return colorPicker
