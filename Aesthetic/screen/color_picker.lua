--- Color picker screen with tabbed interface
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")

-- Import sub-screens
local paletteScreen = require("screen.color_picker.palette")
local hsvScreen = require("screen.color_picker.hsv")
local hexScreen = require("screen.color_picker.hex")

-- Module table to export public functions
local colorPicker = {}

-- Constants for tab UI
local TAB = {
	HEIGHT = 40,
	PADDING = 10,
	MARGIN = 0, -- Move tabs to the top of the screen
	CORNER_RADIUS = 8,
	ACTIVE_LINE_HEIGHT = 3,
}

-- Store these valuesglobally for other screens to access
state.TAB_HEIGHT = TAB.MARGIN + TAB.HEIGHT
state.CONTROLS_HEIGHT = controls.HEIGHT

-- Tab definitions
local tabs = {
	{ name = "Palette", screen = paletteScreen, active = true },
	{ name = "HSV", screen = hsvScreen, active = false },
	{ name = "Hex", screen = hexScreen, active = false },
}

-- Screen switching
local switchScreen = nil

-- Helper function to get active tab
local function getActiveTab()
	for i, tab in ipairs(tabs) do
		if tab.active then
			return tab, i
		end
	end
	return tabs[1], 1 -- Default to first tab if none active
end

-- Helper function to switch to a specific tab by name
local function switchToTab(tabName)
	for _, tab in ipairs(tabs) do
		if tab.name:lower() == tabName:lower() then
			-- Deactivate all tabs
			for _, t in ipairs(tabs) do
				t.active = false
			end
			-- Activate the requested tab
			tab.active = true
			-- Call onEnter for the newly activated tab if it exists
			if tab.screen.onEnter then
				tab.screen.onEnter()
			end
			return true
		end
	end
	return false -- Tab not found
end

function colorPicker.load()
	-- Calculate tab widths
	local availableWidth = state.screenWidth - (TAB.MARGIN * 2)
	local tabWidth = availableWidth / #tabs

	for i, tab in ipairs(tabs) do
		tab.x = TAB.MARGIN + (i - 1) * tabWidth
		tab.width = tabWidth
	end

	-- Load all sub-screens
	for _, tab in ipairs(tabs) do
		if tab.screen.load then
			tab.screen.load()
		end

		-- Set screen switcher for each sub-screen
		if tab.screen.setScreenSwitcher then
			tab.screen.setScreenSwitcher(function(targetScreen, tabName)
				if targetScreen == "color_picker" then
					-- If a tab name is provided, switch to that tab
					if tabName then
						switchToTab(tabName)
					end
					-- Otherwise just stay on current tab
				else
					-- Switch to another main screen
					switchScreen(targetScreen)
				end
			end)
		end

		-- Initialize onEnter for palette screen
		if tab.name == "Palette" and tab.screen.onEnter then
			tab.screen.onEnter()
		end
	end
end

function colorPicker.draw()
	-- Draw the active sub-screen first, underneath the tabs
	local activeTab = getActiveTab()
	if activeTab.screen.draw then
		activeTab.screen.draw()
	end

	-- Draw tab bar background
	love.graphics.setColor(colors.bg[1], colors.bg[2], colors.bg[3], 0.9)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, TAB.HEIGHT + TAB.MARGIN)

	-- Draw tabs
	for _, tab in ipairs(tabs) do
		-- Tab background
		if tab.active then
			love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 0.2)
		else
			love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], 0.1)
		end

		-- Determine corner radius based on position
		local leftRadius = 0
		local rightRadius = 0

		-- Draw tab with appropriate corner rounding (none)
		love.graphics.rectangle("fill", tab.x, TAB.MARGIN, tab.width, TAB.HEIGHT, leftRadius, rightRadius)

		-- Tab text
		if tab.active then
			love.graphics.setColor(colors.fg)
		else
			-- Use a muted version of the foreground color if fg_muted is not available
			love.graphics.setColor(colors.fg[1] * 0.7, colors.fg[2] * 0.7, colors.fg[3] * 0.7, 1)
		end
		love.graphics.setFont(state.fonts.body)
		love.graphics.printf(
			tab.name,
			tab.x,
			TAB.MARGIN + (TAB.HEIGHT - state.fonts.body:getHeight()) / 2,
			tab.width,
			"center"
		)

		-- Active tab indicator
		if tab.active then
			love.graphics.setColor(colors.fg)
			love.graphics.rectangle(
				"fill",
				tab.x,
				TAB.MARGIN + TAB.HEIGHT - TAB.ACTIVE_LINE_HEIGHT,
				tab.width,
				TAB.ACTIVE_LINE_HEIGHT,
				0
			)
		end
	end
end

function colorPicker.update(dt)
	-- Update the active sub-screen
	local activeTab, activeIndex = getActiveTab()
	if activeTab.screen.update then
		activeTab.screen.update(dt)
	end

	if state.canProcessInput() then
		local virtualJoystick = require("input").virtualJoystick

		-- Handle B button (return to menu screen)
		if virtualJoystick:isGamepadDown("b") then
			if switchScreen then
				switchScreen("menu")
				state.resetInputTimer()
			end
			return
		end

		-- Handle tab switching with shoulder buttons
		if virtualJoystick:isGamepadDown("leftshoulder") then
			-- Switch to previous tab
			local newIndex = activeIndex - 1
			if newIndex < 1 then
				newIndex = #tabs
			end

			for i, tab in ipairs(tabs) do
				tab.active = (i == newIndex)
			end

			-- Call onEnter for the newly activated tab if it exists
			if tabs[newIndex].screen.onEnter then
				tabs[newIndex].screen.onEnter()
			end

			state.resetInputTimer()
		elseif virtualJoystick:isGamepadDown("rightshoulder") then
			-- Switch to next tab
			local newIndex = activeIndex + 1
			if newIndex > #tabs then
				newIndex = 1
			end

			for i, tab in ipairs(tabs) do
				tab.active = (i == newIndex)
			end

			-- Call onEnter for the newly activated tab if it exists
			if tabs[newIndex].screen.onEnter then
				tabs[newIndex].screen.onEnter()
			end

			state.resetInputTimer()
		end
	end
end

function colorPicker.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- Function called when entering this screen
function colorPicker.onEnter(tabName)
	-- If a specific tab is requested, switch to it
	if tabName then
		switchToTab(tabName)
	else
		-- Otherwise ensure palette tab is active when entering
		for i, tab in ipairs(tabs) do
			tab.active = (i == 1)
		end

		-- Call onEnter for palette screen if it exists
		if tabs[1].screen.onEnter then
			tabs[1].screen.onEnter()
		end
	end
end

return colorPicker
