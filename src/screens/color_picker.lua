--- Color picker screen with tabbed interface
local love = require("love")
local colors = require("colors")
local state = require("state")
local constants = require("screens.color_picker.constants")
local errorHandler = require("error_handler")
local header = require("ui.header")
local tween = require("tween") -- Import the tween library

-- Import sub-screens
local paletteScreen = require("screens.color_picker.palette")
local hsvScreen = require("screens.color_picker.hsv")
local hexScreen = require("screens.color_picker.hex")

-- Module table to export public functions
local colorPicker = {}

-- Shared constants
colorPicker.TAB_HEIGHT = constants.getTabHeight()

-- Constants for styling
local TAB_CONTAINER_PADDING = 15
local TAB_TEXT_PADDING = 8 -- Add padding for tab text (8px)
local TAB_CONTAINER_HEIGHT = (colorPicker.TAB_HEIGHT * 1.4) - (TAB_CONTAINER_PADDING * 2) + (TAB_TEXT_PADDING * 2)
local TAB_CORNER_RADIUS = TAB_CONTAINER_HEIGHT / 4
local TAB_ANIMATION_DURATION = 0.2 -- Animation duration in seconds

-- Tab definitions
local tabs = {
	{ name = "Palette", screen = paletteScreen, active = true },
	{ name = "HSV", screen = hsvScreen, active = false },
	{ name = "Hex", screen = hexScreen, active = false },
}

-- Animation for the sliding indicator
local tabIndicator = {
	x = 0,
	width = 0,
	animation = nil,
}

-- Animation for text colors
local tabTextColors = {}

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

-- Helper function to initialize text color animations
local function initializeTextColors()
	for i = 1, #tabs do
		tabTextColors[i] = {
			color = { 0, 0, 0, 1 }, -- Will be initialized properly
			animation = nil,
		}
	end
end

-- Helper function to update the tab animations
local function updateTabAnimations()
	local activeTab, _ = getActiveTab()

	-- Create target position based on active tab
	local targetX = activeTab.x
	local targetWidth = activeTab.width

	-- Create or update the tween for sliding motion
	tabIndicator.animation =
		tween.new(TAB_ANIMATION_DURATION, tabIndicator, { x = targetX, width = targetWidth }, "inOutQuad")

	-- Update text color animations
	for i, tab in ipairs(tabs) do
		local targetColor
		if tab.active then
			-- Active tab text color (bright)
			targetColor = { colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1 }
		else
			-- Inactive tab text color (dim)
			targetColor = { colors.ui.subtext[1], colors.ui.subtext[2], colors.ui.subtext[3], 1 }
		end

		-- Create or update the tween for text color
		tabTextColors[i].animation =
			tween.new(TAB_ANIMATION_DURATION, tabTextColors[i], { color = targetColor }, "inOutQuad")
	end
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

			-- Update all animations
			updateTabAnimations()

			-- Call onEnter for the newly activated tab if it exists
			if tab.screen.onEnter then
				tab.screen.onEnter()
			end
			return true
		end
	end
	return false -- Tab not found
end

-- Helper function to format color context for display
local function formatColorContext(context)
	if context == "background" then
		return "Background color"
	elseif context == "foreground" then
		return "Foreground color"
	elseif context == "rgb" then
		return "RGB lighting color"
	else
		-- Capitalize first letter and add " color" suffix for other contexts
		return context:sub(1, 1):upper() .. context:sub(2) .. " color"
	end
end

function colorPicker.load()
	-- Calculate tab widths
	local availableWidth = state.screenWidth - (TAB_CONTAINER_PADDING * 2)
	local tabWidth = availableWidth / #tabs

	for i, tab in ipairs(tabs) do
		tab.x = TAB_CONTAINER_PADDING + (i - 1) * tabWidth
		tab.width = tabWidth
	end

	-- Initialize the tab indicator
	local activeTab = getActiveTab()
	tabIndicator.x = activeTab.x
	tabIndicator.width = activeTab.width

	-- Initialize text colors
	initializeTextColors()

	-- Set initial text colors
	for i, tab in ipairs(tabs) do
		if tab.active then
			tabTextColors[i].color = { colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1 }
		else
			tabTextColors[i].color = { colors.ui.subtext[1], colors.ui.subtext[2], colors.ui.subtext[3], 1 }
		end
	end

	-- Set up initial animation state
	updateTabAnimations()

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
					if switchScreen then
						switchScreen(targetScreen)
					else
						errorHandler.setError("Failed to switch screen: switchScreen function not set")
					end
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

	-- Draw header with current color context
	local contextTitle = formatColorContext(state.activeColorContext)
	header.draw(contextTitle)

	-- Draw tab container (pill-shaped background)
	love.graphics.setColor(
		colors.ui.background[1] * 1.3,
		colors.ui.background[2] * 1.3,
		colors.ui.background[3] * 1.3,
		0.9
	)
	love.graphics.rectangle(
		"fill",
		TAB_CONTAINER_PADDING,
		header.HEIGHT,
		state.screenWidth - (TAB_CONTAINER_PADDING * 2),
		TAB_CONTAINER_HEIGHT,
		TAB_CORNER_RADIUS,
		TAB_CORNER_RADIUS
	)

	-- Draw the sliding tab indicator
	love.graphics.setColor(colors.ui.accent[1], colors.ui.accent[2], colors.ui.accent[3], 0.9)
	love.graphics.rectangle(
		"fill",
		tabIndicator.x,
		header.HEIGHT,
		tabIndicator.width,
		TAB_CONTAINER_HEIGHT,
		TAB_CORNER_RADIUS,
		TAB_CORNER_RADIUS
	)

	-- Draw tabs (text only, since the background indicator is drawn separately)
	for i, tab in ipairs(tabs) do
		local tabY = header.HEIGHT

		-- Calculate tab position to ensure it fits flush with the container
		local tabX = tab.x
		local tabWidth = tab.width

		-- Use animated text color
		love.graphics.setColor(tabTextColors[i].color)
		love.graphics.setFont(state.fonts.body)
		love.graphics.printf(
			tab.name,
			tabX,
			tabY + (TAB_CONTAINER_HEIGHT - state.fonts.body:getHeight()) / 2 - 1, -- Adjust vertical position so its visually centered
			tabWidth,
			"center"
		)
	end
end

function colorPicker.update(dt)
	-- Update the active sub-screen
	local activeTab, activeIndex = getActiveTab()
	if activeTab.screen.update then
		activeTab.screen.update(dt)
	end

	-- Update tab indicator animation
	if tabIndicator.animation then
		tabIndicator.animation:update(dt)
	end

	-- Update text color animations
	for _, textColorAnim in ipairs(tabTextColors) do
		if textColorAnim.animation then
			textColorAnim.animation:update(dt)
		end
	end

	if state.canProcessInput() then
		local virtualJoystick = require("input").virtualJoystick

		-- Handle B button (return to menu screen)
		if virtualJoystick:isGamepadDown("b") then
			if switchScreen then
				switchScreen(state.previousScreen)
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

			-- Update tab animations
			updateTabAnimations()

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

			-- Update tab animations
			updateTabAnimations()

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

		-- Update tab animations
		updateTabAnimations()

		-- Call onEnter for palette screen if it exists
		if tabs[1].screen.onEnter then
			tabs[1].screen.onEnter()
		end
	end

	-- Notify all sub-screens about header height for positioning
	for _, tab in ipairs(tabs) do
		if tab.screen.updateLayout then
			tab.screen.updateLayout()
		end
	end
end

return colorPicker
