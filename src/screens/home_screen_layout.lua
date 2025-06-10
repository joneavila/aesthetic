--- Home Screen Layout Selection Screen
local love = require("love")

local controls = require("control_hints")
local paths = require("paths")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List
local image = require("ui.image")

local homeScreenLayout = {}

-- UI Components
local menuList = nil
local input = nil
local previewImage = nil

-- Constants
local CONTROLS_HEIGHT = controls.calculateHeight()
local IMAGE_MARGIN = 16

-- Load preview images
local function loadPreviewImages()
	local images = {}

	-- Load grid image
	if love.filesystem.getInfo(paths.UI_HOME_SCREEN_LAYOUT_GRID_IMAGE) then
		images.grid = love.graphics.newImage(paths.UI_HOME_SCREEN_LAYOUT_GRID_IMAGE)
	end

	-- Load list image
	if love.filesystem.getInfo(paths.UI_HOME_SCREEN_LAYOUT_LIST_IMAGE) then
		images.list = love.graphics.newImage(paths.UI_HOME_SCREEN_LAYOUT_LIST_IMAGE)
	end

	return images
end

-- Create the layout selection button
local function createLayoutButton()
	return Button:new({
		text = "Layout",
		type = ButtonTypes.INDICATORS,
		options = { "List", "Grid" },
		currentOptionIndex = (state.homeScreenLayout == "Grid" and 2) or 1,
		screenWidth = state.screenWidth,
		context = "homeScreenLayout",
	})
end

-- Handle option cycling
local function handleOptionCycle(button, direction)
	if not button.context or button.context ~= "homeScreenLayout" then
		return false
	end

	local changed = button:cycleOption(direction)
	if not changed then
		return false
	end

	local newValue = button:getCurrentOption()
	state.homeScreenLayout = newValue

	return true
end

function homeScreenLayout.draw()
	background.draw()
	header.draw("Home Screen Layout")

	-- Set the default body font for consistent sizing
	love.graphics.setFont(fonts.loaded.body)

	-- Draw the button list
	if menuList then
		menuList:draw()
	end

	-- Draw the preview image
	local currentLayout = state.homeScreenLayout:lower()
	if previewImage and previewImage[currentLayout] then
		local img = previewImage[currentLayout]

		-- Calculate available space for the image
		local buttonAreaBottom = header.getContentStartY() + 80 -- The button list height
		local controlsTop = state.screenHeight - CONTROLS_HEIGHT
		local availableHeight = controlsTop - buttonAreaBottom - (IMAGE_MARGIN * 2) -- Top and bottom padding
		local availableWidth = state.screenWidth - (IMAGE_MARGIN * 2) -- Left and right padding

		-- Calculate image dimensions maintaining aspect ratio
		local originalWidth = img:getWidth()
		local originalHeight = img:getHeight()
		local aspectRatio = originalWidth / originalHeight

		local imageWidth, imageHeight

		-- Fit image to available space while maintaining aspect ratio
		if availableWidth / aspectRatio <= availableHeight then
			-- Width is the limiting factor
			imageWidth = availableWidth
			imageHeight = availableWidth / aspectRatio
		else
			-- Height is the limiting factor
			imageHeight = availableHeight
			imageWidth = availableHeight * aspectRatio
		end

		-- Ensure image is never scaled beyond original size
		if imageWidth > originalWidth then
			imageWidth = originalWidth
			imageHeight = originalHeight
		end

		-- Center the image both horizontally and vertically in the available space
		local imageX = (state.screenWidth - imageWidth) / 2
		local totalAvailableHeight = controlsTop - buttonAreaBottom
		local imageY = buttonAreaBottom + (totalAvailableHeight - imageHeight) / 2

		-- Only draw if there's enough space
		if availableHeight > 50 then -- Minimum reasonable height
			image.draw(img, imageX, imageY, imageWidth, imageHeight, 8)
		end
	end

	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function homeScreenLayout.update(dt)
	-- Handle list input
	if menuList then
		menuList:handleInput(input)
	end

	-- Handle B button press for back
	if input.isPressed("b") then
		screens.switchTo("main_menu")
	end

	-- Update components
	if menuList then
		menuList:update(dt)
	end
end

function homeScreenLayout.onExit() end

function homeScreenLayout.onEnter(_data)
	-- Initialize components
	require("ui.button").init()
	input = inputHandler.create()

	-- Load preview images
	previewImage = loadPreviewImages()

	-- Create the layout button
	local buttons = { createLayoutButton() }

	-- Create the main list
	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = 80, -- Just enough for the button
		items = buttons,
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})
end

return homeScreenLayout
