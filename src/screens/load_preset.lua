--- Load preset screen
local love = require("love")

local controls = require("controls")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List

local logger = require("utils.logger")
local presets = require("utils.presets")

-- Module table to export public functions
local loadPreset = {}

-- Preset items list
local presetItems = {}

-- Helper function to load presets and verify they are valid
local function loadPresetsList()
	-- Clear existing presets
	presetItems = {}

	-- Get list of presets
	local availablePresets = presets.listPresets()
	local presetDetails = {}

	-- Validate each preset and gather creation dates
	logger.debug("Starting preset validation loop")
	for _, presetName in ipairs(availablePresets) do
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
			})
		)
	end
end

function loadPreset.load()
	input = inputHandler.create()
	loadPresetsList()

	-- Calculate available height for the list (full space between header and controls)
	local availableHeight = state.screenHeight - header.getContentStartY() - controls.calculateHeight()

	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = availableHeight,
		items = presetItems,
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		wrap = false,
	})
end

function loadPreset.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("load theme preset")

	-- Reset font to the regular body font after header drawing
	love.graphics.setFont(fonts.loaded.body)

	-- Draw message if no presets found
	if #presetItems == 0 then
		love.graphics.setFont(fonts.loaded.body)
		love.graphics.print("No presets found", 16, header.getContentStartY())

		-- Draw controls
		controls.draw({
			{ button = "b", text = "Back" },
		})
		return
	end

	-- Draw the list of presets using the list component
	if menuList then
		menuList:draw()
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
end

-- Clean up resources when leaving the screen
function loadPreset.onExit() end

return loadPreset
