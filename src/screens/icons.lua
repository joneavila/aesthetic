--- Icons toggle screen
local love = require("love")

local controls = require("control_hints")
local paths = require("paths")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.header")
local imageComponent = require("ui.image")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List

local iconsToggle = {}

local menuList = nil
local input = nil
local previewImages = {}

local headerInstance = Header:new({ title = "Icons", screenWidth = state.screenWidth })

-- Function to load preview images
local function loadPreviewImages()
	previewImages.enabled = love.graphics.newImage(paths.UI_ICONS_TOGGLE_ENABLED_IMAGE)
	previewImages.disabled = love.graphics.newImage(paths.UI_ICONS_TOGGLE_DISABLED_IMAGE)
end

-- Function to create the toggle button
local function createMenuButtons()
	local buttons = {}
	table.insert(
		buttons,
		Button:new({
			text = "Icons",
			type = ButtonTypes.INDICATORS,
			options = { "Disabled", "Enabled" },
			currentOptionIndex = state.glyphsEnabled and 2 or 1,
			screenWidth = state.screenWidth,
			context = "glyphs",
		})
	)
	return buttons
end

-- Handle option cycling for the toggle button
local function handleOptionCycle(button, direction)
	if button.context == "glyphs" then
		local changed = button:cycleOption(direction)
		if changed then
			local newValue = button:getCurrentOption()
			state.glyphsEnabled = (newValue == "Enabled")
		end
		return changed
	end
	return false
end

function iconsToggle.draw()
	-- Draw the background first
	background.draw()

	-- Draw header
	headerInstance:draw()

	love.graphics.setFont(fonts.loaded.body)

	if menuList then
		menuList:draw()
	end

	-- Draw preview image below the button
	local controlsHeight = controls.HEIGHT or controls.calculateHeight()
	local margin = 20
	local listBottom = menuList.y + menuList:getContentHeight()
	local previewY = listBottom + margin
	local previewAreaHeight = state.screenHeight - previewY - controlsHeight - margin
	local previewAreaWidth = state.screenWidth - margin * 2

	-- Get the appropriate preview image
	local currentImage = state.glyphsEnabled and previewImages.enabled or previewImages.disabled

	if currentImage and previewAreaHeight > 40 then
		-- Calculate image dimensions maintaining aspect ratio
		local imageWidth = currentImage:getWidth()
		local imageHeight = currentImage:getHeight()
		local aspectRatio = imageWidth / imageHeight

		-- Fit image within available area
		local previewWidth = previewAreaWidth
		local previewHeight = previewWidth / aspectRatio

		if previewHeight > previewAreaHeight then
			previewHeight = previewAreaHeight
			previewWidth = previewHeight * aspectRatio
		end

		-- Ensure image is never scaled larger than original size
		if previewWidth > imageWidth or previewHeight > imageHeight then
			previewWidth = imageWidth
			previewHeight = imageHeight
		end

		-- Center the image both horizontally and vertically
		local previewX = (state.screenWidth - previewWidth) / 2
		local centeredPreviewY = previewY + (previewAreaHeight - previewHeight) / 2

		-- Draw using the image component
		imageComponent.draw(currentImage, previewX, centeredPreviewY, previewWidth, previewHeight)
	end

	-- Draw controls
	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function iconsToggle.update(dt)
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end

	-- Handle B button press to go back
	if input.isPressed("b") then
		screens.switchTo("main_menu")
	end
end

function iconsToggle.onExit()
	-- Clean up preview images
	if previewImages.enabled then
		previewImages.enabled:release()
	end
	if previewImages.disabled then
		previewImages.disabled:release()
	end
	previewImages = {}
end

function iconsToggle.onEnter(_data)
	-- Initialize input handler
	input = inputHandler.create()

	-- Load preview images
	loadPreviewImages()

	-- Create menu list
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - 60,
		items = createMenuButtons(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		onItemOptionCycle = handleOptionCycle,
	})
end

return iconsToggle
