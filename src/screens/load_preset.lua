--- Load preset screen
local love = require("love")
local state = require("state")
local controls = require("controls")
local presets = require("utils.presets")
local rgbUtils = require("utils.rgb")
local header = require("ui.header")
local background = require("ui.background")
local Button = require("ui.button").Button
local List = require("ui.list").List
local logger = require("utils.logger")
local paths = require("paths")
local screens = require("screens")
local inputHandler = require("ui.input_handler")

-- Module table to export public functions
local loadPreset = {}

-- Preset items list
local presetItems = {}
local lastSelectedIndex = 1

-- Preview image
local previewImage = nil
local previewImageName = nil

-- Helper function to load preview image for a preset
local function loadPreviewImage(presetName)
	logger.debug("Loading preview image for preset: " .. tostring(presetName))
	if previewImage then
		previewImage:release()
		previewImage = nil
	end

	previewImageName = presetName

	local imagePath = paths.getThemePreviewImagePath()
	logger.debug("Loading image from path: " .. imagePath)

	local success, result = pcall(function()
		return love.graphics.newImage(imagePath)
	end)

	if success and result then
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
		local isValid, presetData = presets.validatePreset(presetName)
		logger.debug("Preset " .. tostring(presetName) .. " valid: " .. tostring(isValid))

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
		else
			logger.debug("No preset data available for " .. tostring(presetName))
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
	logger.debug("Creating sorted list of preset items")
	for i, detail in ipairs(presetDetails) do
		logger.debug("Processing preset detail " .. i .. ": " .. tostring(detail.name))
		table.insert(
			presetItems,
			Button:new({
				text = detail.displayName,
				screenWidth = state.screenWidth,
				isValid = detail.isValid,
				onClick = function()
					if detail.isValid then
						local success = presets.loadPreset(detail.name)
						if success then
							screens.switchTo("settings")
						else
							logger.error("Failed to load preset: " .. detail.name)
						end
					else
						logger.warn("Attempted to load invalid preset: " .. detail.name)
					end
				end,
				focusCallback = function()
					loadPreviewImage(detail.name)
				end,
			})
		)
	end
end

function loadPreset.load()
	input = inputHandler.create()
	loadPresetsList()
	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight * 0.5,
		items = presetItems,
		itemHeight = 60,
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		onItemFocus = function(item)
			if item.focusCallback then
				item.focusCallback()
			end
		end,
		wrap = false,
		paddingX = 16,
		paddingY = 8,
	})
end

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
	if menuList then
		menuList:draw()
	end

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
		local previewY = header.getHeight() + listHeight + 10
		local messageText = "Preview image not found"
		local textWidth = state.fonts.body:getWidth(messageText)
		local textX = (state.screenWidth - textWidth) / 2
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
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end
	local virtualJoystick = require("input").virtualJoystick
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		screens.switchTo("settings")
	end
end

function loadPreset.onEnter()
	loadPresetsList()

	-- Initialize the list with proper state management
	if menuList then
		menuList:setItems(presetItems)
	end

	-- Load preview for initially selected item
	if menuList and menuList:getSelectedItem() and menuList:getSelectedItem().focusCallback then
		menuList:getSelectedItem().focusCallback()
	end
end

-- Clean up resources when leaving the screen
function loadPreset.onExit()
	-- Store selected index before leaving
	if menuList then
		lastSelectedIndex = menuList.selectedIndex
	end

	if previewImage then
		previewImage:release()
		previewImage = nil
	end
end

return loadPreset
