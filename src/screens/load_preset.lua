--- Load preset screen
local love = require("love")
local state = require("state")
local controls = require("controls")
local presets = require("utils.presets")
local rgbUtils = require("utils.rgb")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local button = require("ui.button")
local scrollView = require("ui.scroll_view")

-- Module table to export public functions
local loadPreset = {}

-- Screen switching
local switchScreen = nil

-- Preset items list
local presetItems = {}
local selectedIndex = 1

-- Scrolling
local scrollPosition = 0
local visibleItemCount = 0

-- Helper function to load presets and verify they are valid
local function loadPresetsList()
	-- Clear existing presets
	presetItems = {}

	-- Get list of presets
	local availablePresets = presets.listPresets()
	local presetDetails = {}

	-- Validate each preset and gather creation dates
	for _, presetName in ipairs(availablePresets) do
		local isValid, presetData = presets.validatePreset(presetName)

		local createdTime = 0
		local displayName = presetName
		local source = "user"

		if presetData then
			if presetData.created then
				createdTime = presetData.created
			end

			if presetData.displayName then
				displayName = presetData.displayName
			end

			if presetData.source then
				source = presetData.source
			end
		end

		table.insert(presetDetails, {
			name = presetName, -- Original filename (sanitized)
			displayName = displayName, -- Name to display
			isValid = isValid,
			created = createdTime,
			source = source,
		})
	end

	-- Sort by creation date (newest first)
	table.sort(presetDetails, function(a, b)
		return a.created > b.created
	end)

	-- Create the sorted list of preset items
	for _, detail in ipairs(presetDetails) do
		table.insert(presetItems, {
			name = detail.name, -- Keep the original name for loading
			text = detail.displayName, -- Use the display name for showing (match list.lua's expected structure)
			displayName = detail.displayName, -- Keep the original property for reference
			selected = false,
			isValid = detail.isValid,
			source = detail.source, -- Track source (user or built-in)
		})
	end

	-- Select the first preset if available
	if #presetItems > 0 then
		presetItems[1].selected = true
		selectedIndex = 1
	end
end

function loadPreset.load()
	loadPresetsList()
end

function loadPreset.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("LOAD THEME PRESET")

	-- Reset font to the regular body font after header drawing
	love.graphics.setFont(state.fonts.body)

	-- Draw message if no presets found
	if #presetItems == 0 then
		love.graphics.setFont(state.fonts.body)
		love.graphics.print("No presets found", button.BUTTON.EDGE_MARGIN, header.getHeight())

		-- Draw controls
		controls.draw({
			{ button = "b", text = "Back" },
		})
		return
	end

	-- Draw the list of presets using the list component
	local result = list.draw({
		items = presetItems,
		startY = header.getHeight(),
		itemHeight = button.calculateHeight(),
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = state.screenHeight,
		drawItemFunc = function(item, _index, y)
			-- Draw the basic button first
			button.draw(item.text, 0, y, item.selected, state.screenWidth)

			-- Display built-in indicator if applicable
			if item.source == "built-in" then
				local indicatorText = "[Built-in]"
				local textWidth = state.fonts.body:getWidth(indicatorText)

				-- Use a slightly different color for the built-in indicator
				love.graphics.setColor(0.5, 0.7, 1.0, 1.0)
				love.graphics.print(
					indicatorText,
					state.screenWidth - scrollView.SCROLL_BAR_WIDTH - textWidth - button.BUTTON.PADDING * 2,
					y + (button.calculateHeight() - state.fonts.body:getHeight()) / 2
				)
			end

			-- Add red text for invalid presets
			if not item.isValid then
				love.graphics.setColor(0.8, 0.2, 0.2, 1)
			end
		end,
	})

	-- Store the returned visibleCount for scroll calculations
	visibleItemCount = result.visibleCount

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Navigate" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function loadPreset.update(_dt)
	if not state.canProcessInput() then
		return
	end

	local virtualJoystick = require("input").virtualJoystick

	-- Handle D-pad navigation
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		local direction = virtualJoystick:isGamepadDown("dpup") and -1 or 1

		-- Update selected index using list's navigation helper
		selectedIndex = list.navigate(presetItems, direction)

		-- Adjust scroll position to ensure selected item is visible
		scrollPosition = list.adjustScrollPosition({
			selectedIndex = selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleItemCount,
		})
	end

	-- Handle A button (Select)
	if virtualJoystick:isGamepadDown("a") and #presetItems > 0 then
		local selectedPreset = presetItems[selectedIndex]

		if selectedPreset.isValid then
			-- Load the selected preset
			local success = presets.loadPreset(selectedPreset.name)
			if success then
				-- Update RGB configuration immediately after loading preset
				rgbUtils.updateConfig()

				-- Return to main menu screen
				if switchScreen then
					switchScreen("main_menu")
					state.resetInputTimer()
					state.forceInputDelay(0.2) -- Add extra delay when switching screens
				end
			end
		end

		state.resetInputTimer()
	end

	-- Handle B button (Back)
	if virtualJoystick:isGamepadDown("b") and switchScreen then
		switchScreen("main_menu")
		state.resetInputTimer()
		state.forceInputDelay(0.2) -- Add extra delay when switching screens
	end
end

function loadPreset.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function loadPreset.onEnter()
	loadPresetsList()
	scrollPosition = 0
end

return loadPreset
