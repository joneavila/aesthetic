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
local logger = require("utils.logger")

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
	logger.debug("Starting preset validation loop")
	for i, presetName in ipairs(availablePresets) do
		logger.debug("Validating preset " .. i .. ": " .. tostring(presetName))
		local isValid, presetData = presets.validatePreset(presetName)
		logger.debug("Preset " .. tostring(presetName) .. " valid: " .. tostring(isValid))

		local createdTime = 0
		local displayName = presetName
		local source = "user"

		if presetData then
			logger.debug("Preset data available for " .. tostring(presetName))
			if presetData.created then
				logger.debug("Preset has creation time: " .. tostring(presetData.created))
				createdTime = presetData.created
			end

			if presetData.displayName then
				logger.debug("Preset has display name: " .. tostring(presetData.displayName))
				displayName = presetData.displayName
			end

			if presetData.source then
				logger.debug("Preset has source: " .. tostring(presetData.source))
				source = presetData.source
			end
		else
			logger.debug("No preset data available for " .. tostring(presetName))
		end

		logger.debug("Adding preset " .. tostring(presetName) .. " to presetDetails")
		table.insert(presetDetails, {
			name = presetName, -- Original filename (sanitized)
			displayName = displayName, -- Name to display
			isValid = isValid,
			created = createdTime,
			source = source,
		})
	end

	-- Sort by creation date (newest first)
	logger.debug("Sorting presets by creation date")
	table.sort(presetDetails, function(a, b)
		return a.created > b.created
	end)

	-- Create the sorted list of preset items
	logger.debug("Creating sorted list of preset items")
	for i, detail in ipairs(presetDetails) do
		logger.debug("Processing preset detail " .. i .. ": " .. tostring(detail.name))
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
	logger.debug("Setting initial selection")
	if #presetItems > 0 then
		logger.debug("Selecting first preset: " .. tostring(presetItems[1].name))
		presetItems[1].selected = true
		selectedIndex = 1
	else
		logger.debug("No presets available to select")
	end
	logger.debug("Completed loadPresetsList()")
end

function loadPreset.load()
	logger.debug("loadPreset.load() called")
	loadPresetsList()
	logger.debug("loadPreset.load() completed")
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
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function loadPreset.update(dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Handle D-pad navigation
	if virtualJoystick.isGamepadPressedWithDelay("dpup") then
		selectedIndex = list.navigate(presetItems, -1)
		scrollPosition = list.adjustScrollPosition({
			selectedIndex = selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleItemCount,
		})
	elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
		selectedIndex = list.navigate(presetItems, 1)
		scrollPosition = list.adjustScrollPosition({
			selectedIndex = selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleItemCount,
		})
	end

	-- Handle A button (Select)
	if virtualJoystick.isGamepadPressedWithDelay("a") and #presetItems > 0 then
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
				end
			end
		end
	end

	-- Handle B button (Back)
	if virtualJoystick.isGamepadPressedWithDelay("b") and switchScreen then
		switchScreen("main_menu")
	end
end

function loadPreset.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function loadPreset.onEnter()
	logger.debug("loadPreset.onEnter() called")
	loadPresetsList()
	scrollPosition = 0
	logger.debug("loadPreset.onEnter() completed")
end

return loadPreset
