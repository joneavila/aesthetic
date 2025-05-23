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
local scrollable = require("ui.scrollable")
local logger = require("utils.logger")
local paths = require("paths")

-- Module table to export public functions
local loadPreset = {}

-- Screen switching
local switchScreen = nil

-- Preset items list
local presetItems = {}
local lastSelectedIndex = 1

-- Preview image
local previewImage = nil
local previewImageName = nil

-- Helper function to load preview image for a preset
local function loadPreviewImage(presetName)
	logger.debug("Loading preview image for preset: " .. tostring(presetName))
	-- Clear any existing preview image
	if previewImage then
		previewImage:release()
		previewImage = nil
	end

	previewImageName = presetName

	local imagePath = paths.PRESETS_IMAGES_DIR .. "/" .. presetName .. ".png"
	logger.debug("Loading image from path: " .. imagePath)

	local success, result = pcall(function()
		return love.graphics.newImage(imagePath)
	end)

	if success then
		logger.debug("Successfully loaded preview image")
		previewImage = result
	else
		logger.debug("Failed to load preview image. Error: " .. tostring(result))
		previewImage = nil
	end
end

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

	logger.debug("Completed loadPresetsList()")
end

function loadPreset.load() end

function loadPreset.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("load theme preset")

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

	-- Calculate available height for list and preview image
	local totalAvailableHeight = state.screenHeight - header.getHeight() - controls.calculateHeight()
	local listHeight = totalAvailableHeight * 0.5 -- Use half of the available height for the list

	-- Draw the list of presets using the list component
	local result = list.draw({
		items = presetItems,
		startY = header.getHeight(),
		itemHeight = button.calculateHeight(),
		scrollPosition = list.getScrollPosition(), -- Get current scroll position from list module
		screenWidth = state.screenWidth,
		screenHeight = header.getHeight() + listHeight, -- Only use half the space for the list
		drawItemFunc = function(item, _index, y)
			-- Draw the basic button first
			button.draw(item.text, 0, y, item.selected, state.screenWidth)

			-- You may want to display an indicator for built-in presets
			-- Built-in presets have source = "built-in"

			-- Add red text for invalid presets
			if not item.isValid then
				love.graphics.setColor(0.8, 0.2, 0.2, 1)
			end
		end,
	})

	-- Store visible count for use in update function
	loadPreset.visibleItemCount = result.visibleCount

	-- Draw the preview image if available
	if previewImage then
		-- Calculate preview image position
		local previewY = header.getHeight() + listHeight + 10

		-- Calculate remaining space for preview
		local availableHeight = state.screenHeight - previewY - controls.calculateHeight() - 10

		-- Calculate scaling to fit the image in the available height while maintaining aspect ratio
		local scale = availableHeight / previewImage:getHeight()
		local imageWidth = previewImage:getWidth() * scale
		local imageHeight = previewImage:getHeight() * scale

		-- Center the image horizontally
		local previewX = (state.screenWidth - imageWidth) / 2

		-- Draw a border around the preview
		love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
		love.graphics.rectangle("line", previewX - 2, previewY - 2, imageWidth + 4, imageHeight + 4)

		-- Draw the preview image
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(previewImage, previewX, previewY, 0, scale, scale)
	elseif previewImageName then
		-- Display "Image not found" message if we tried to load an image but failed
		local previewY = header.getHeight() + listHeight + 10
		local messageText = "Image not found for preset: " .. previewImageName

		-- Center the message horizontally
		local textWidth = state.fonts.body:getWidth(messageText)
		local textX = (state.screenWidth - textWidth) / 2

		-- Draw error message
		love.graphics.setColor(0.8, 0.2, 0.2, 1.0)
		love.graphics.setFont(state.fonts.body)
		love.graphics.print(messageText, textX, previewY + 30)
	end

	-- Draw controls
	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function loadPreset.update(dt)
	local virtualJoystick = require("input").virtualJoystick

	-- If no presets found, only handle back button
	if #presetItems == 0 then
		if virtualJoystick.isGamepadPressedWithDelay("b") and switchScreen then
			switchScreen("settings")
		end
		return
	end

	-- Get current scroll position
	local scrollPosition = list.getScrollPosition()

	-- Use the enhanced list input handler for navigation and selection
	local result = list.handleInput({
		items = presetItems,
		virtualJoystick = virtualJoystick,
		scrollPosition = scrollPosition,
		visibleCount = loadPreset.visibleItemCount or 5, -- Use stored visibleCount or default to 5

		-- Handle item selection (A button)
		handleItemSelect = function(selectedItem, selectedIndex)
			lastSelectedIndex = selectedIndex

			if selectedItem.isValid then
				-- Load the selected preset
				local success = presets.loadPreset(selectedItem.name)
				if success then
					-- Update RGB configuration immediately after loading preset
					if state.hasRGBSupport then
						rgbUtils.updateConfig()
					end

					-- Return to main menu screen
					if switchScreen then
						switchScreen("main_menu")
					end
				end
			end
		end,
	})

	-- Update preview image when selection changes
	if result and result.selectedIndexChanged then
		local selectedItem = list.getSelectedItem()
		if selectedItem then
			loadPreviewImage(selectedItem.name)
		end
	end

	-- Handle B button (Back)
	if virtualJoystick.isGamepadPressedWithDelay("b") and switchScreen then
		switchScreen("settings")
	end
end

function loadPreset.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function loadPreset.onEnter()
	logger.debug("loadPreset.onEnter() called")
	loadPresetsList()

	-- Initialize the list with proper state management
	list.onScreenEnter("load_preset", presetItems, lastSelectedIndex)

	-- Load preview for initially selected item
	local selectedItem = list.getSelectedItem()
	if selectedItem then
		loadPreviewImage(selectedItem.name)
	end

	logger.debug("loadPreset.onEnter() completed")
end

-- Clean up resources when leaving the screen
function loadPreset.onExit()
	-- Store selected index before leaving
	lastSelectedIndex = list.onScreenExit()

	if previewImage then
		previewImage:release()
		previewImage = nil
	end
end

return loadPreset
