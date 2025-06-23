--- Home Screen Layout Selection Screen
local love = require("love")

local controls = require("control_hints").ControlHints
local paths = require("paths")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local List = require("ui.components.list").List
local image = require("ui.components.image")
local InputManager = require("ui.controllers.input_manager")
local logger = require("utils.logger")
local Image = require("ui.components.image").Image

local homeScreenLayout = {}

-- UI Components
local menuList = nil
local input = nil
local previewImage = nil
local headerInstance = Header:new({ title = "Home Screen Layout" })

-- Constants
local CONTROLS_HEIGHT = controls.calculateHeight()
local PREVIEW_TOP_MARGIN = 2
local PREVIEW_BOTTOM_MARGIN = 8
local BUTTON_LIST_HEIGHT = 80
local MIN_IMAGE_HEIGHT = 50

local controlHintsInstance

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
	headerInstance:draw()

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
		local buttonAreaBottom = headerInstance:getContentStartY()
			+ BUTTON_LIST_HEIGHT
			- (menuList and menuList.paddingY or 0) -- Adjust for List's bottom padding
		local controlsTop = state.screenHeight - CONTROLS_HEIGHT - PREVIEW_BOTTOM_MARGIN
		local availableHeight = controlsTop - buttonAreaBottom - PREVIEW_TOP_MARGIN
		local availableWidth = state.screenWidth

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
		local imageY = buttonAreaBottom + PREVIEW_TOP_MARGIN + ((availableHeight - imageHeight) / 2)

		-- Only draw if there's enough space
		if availableHeight > MIN_IMAGE_HEIGHT then
			-- local cornerRadius = 20
			local imgComponent = Image:new({
				image = img,
				x = imageX,
				y = imageY,
				width = imageWidth,
				height = imageHeight,
				-- cornerRadius = cornerRadius,
				haloParams = {
					enabled = true,
					scaleFactor = 1.05,
					blurRadius = 18,
					intensity = 0.6,
				},
			})
			imgComponent:draw()
		end
	end

	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

function homeScreenLayout.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, input)
		menuList:update(dt)
		local layoutButton = menuList.items[1]
		if layoutButton and layoutButton.getCurrentOption then
			state.homeScreenLayout = layoutButton:getCurrentOption()
		end
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end

	-- Update components
	if menuList then
		menuList:update(dt)
	end
end

function homeScreenLayout.onExit() end

function homeScreenLayout.onEnter(_data)
	-- Load preview images
	previewImage = loadPreviewImages()

	-- Create the layout button
	local buttons = { createLayoutButton() }

	-- Create the main list
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = BUTTON_LIST_HEIGHT,
		items = buttons,
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

return homeScreenLayout
