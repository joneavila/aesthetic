--- Color picker screen with tabbed interface
local love = require("love")

local colors = require("colors")
local screens = require("screens")
local state = require("state")
local tween = require("tween")

local fonts = require("ui.fonts")
local header = require("ui.header")

local constants = require("screens.color_picker.constants")
local hexScreen = require("screens.color_picker.hex")
local hsvScreen = require("screens.color_picker.hsv")
local paletteScreen = require("screens.color_picker.palette")

local TabBar = require("ui.tab_bar")

-- Module table to export public functions
local colorPicker = {}

-- Shared constants
colorPicker.TAB_HEIGHT = constants.getTabHeight()

-- Constants for styling
local TAB_TEXT_PADDING = 8 -- Add padding for tab text (8px)
local TAB_CONTAINER_HEIGHT = colorPicker.TAB_HEIGHT + (TAB_TEXT_PADDING * 2)
local TAB_CORNER_RADIUS = TAB_CONTAINER_HEIGHT / 4
local TAB_ANIMATION_DURATION = 0.2 -- Animation duration in seconds

-- Add a TabBar instance
local tabBar

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
	local contextTitle = formatColorContext(state.activeColorContext)
	header.draw(contextTitle)

	-- Draw the tab bar with 8px left/right padding
	if tabBar then
		tabBar.x = 8
		tabBar.y = header.getContentStartY()
		tabBar.width = state.screenWidth - 16
		tabBar:draw()
	end
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
	-- Create the tab bar if it doesn't exist
	if not tabBar then
		tabBar = TabBar:new({
			tabs = {
				{ name = "Palette", screen = paletteScreen },
				{ name = "HSV", screen = hsvScreen },
				{ name = "Hex", screen = hexScreen },
			},
			width = state.screenWidth - 16,
			height = colorPicker.TAB_HEIGHT + 16,
			x = 8,
			y = header.getContentStartY(),
			onTabSwitched = function(tab)
				if tab.screen.onEnter then
					tab.screen.onEnter()
				end
			end,
		})
	else
		tabBar.width = state.screenWidth - 16
		tabBar.x = 8
		tabBar.y = header.getContentStartY()
	end

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
end

return colorPicker
