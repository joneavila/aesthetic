--- Home Screen Layout Selection Screen
local love = require("love")

local controls = require("controls")
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
	if love.filesystem.getInfo(paths.HOME_SCREEN_LAYOUT_GRID_IMAGE) then
		images.grid = love.graphics.newImage(paths.HOME_SCREEN_LAYOUT_GRID_IMAGE)
	end

	-- Load list image
	if love.filesystem.getInfo(paths.HOME_SCREEN_LAYOUT_LIST_IMAGE) then
		images.list = love.graphics.newImage(paths.HOME_SCREEN_LAYOUT_LIST_IMAGE)
	end

	return images
end

-- Create the layout selection button
local function createLayoutButton()
	return Button:new({
		text = "Home Screen Layout",
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

function homeScreenLayout.load()
	-- Initialize button component
	require("ui.button").init()

	-- Create input handler
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

function homeScreenLayout.draw()
	background.draw()
	header.draw("home screen layout")

	-- Set the default body font for consistent sizing
	love.graphics.setFont(fonts.loaded.body)

	-- Draw the button list
	if menuList then
		menuList:draw()
	end

	-- Draw the preview image
	local currentLayout = state.homeScreenLayout:lower()
	if previewImage and previewImage[currentLayout] then
		local image = previewImage[currentLayout]

		-- Calculate available space for the image
		local buttonAreaBottom = header.getContentStartY() + 80 -- The button list height
		local controlsTop = state.screenHeight - CONTROLS_HEIGHT
		local availableHeight = controlsTop - buttonAreaBottom - (IMAGE_MARGIN * 2) -- Top and bottom padding
		local availableWidth = state.screenWidth - (IMAGE_MARGIN * 2) -- Left and right padding

		-- Calculate image dimensions maintaining aspect ratio
		local originalWidth = image:getWidth()
		local originalHeight = image:getHeight()
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

		-- Center the image in the available space
		local imageX = (state.screenWidth - imageWidth) / 2
		local imageY = buttonAreaBottom + IMAGE_MARGIN

		-- Only draw if there's enough space
		if availableHeight > 50 then -- Minimum reasonable height
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.draw(image, imageX, imageY, 0, imageWidth / originalWidth, imageHeight / originalHeight)
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

function homeScreenLayout.onEnter(data)
	-- Rebuild the button with current state
	local buttons = { createLayoutButton() }
	if menuList then
		menuList:setItems(buttons)
	end
end

return homeScreenLayout
