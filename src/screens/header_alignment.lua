--- Header Alignment Settings Screen
local love = require("love")

local colors = require("colors")
local controls = require("controls")
local paths = require("paths")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local header = require("ui.header")
local imageComponent = require("ui.image")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List

local headerAlignment = {}

-- UI Components
local menuList = nil
local input = nil
local previewImages = {}

-- Constants
local CONTROLS_HEIGHT = controls.calculateHeight()
local IMAGE_MARGIN = 16
local EDGE_PADDING = 10

-- Load preview images
local function loadPreviewImages()
	local images = {}

	-- Load left alignment image
	if love.filesystem.getInfo(paths.HEADER_ALIGNMENT_LEFT_IMAGE) then
		images.left = love.graphics.newImage(paths.HEADER_ALIGNMENT_LEFT_IMAGE)
	end

	-- Load center alignment image
	if love.filesystem.getInfo(paths.HEADER_ALIGNMENT_CENTER_IMAGE) then
		images.center = love.graphics.newImage(paths.HEADER_ALIGNMENT_CENTER_IMAGE)
	end

	-- Load right alignment image
	if love.filesystem.getInfo(paths.HEADER_ALIGNMENT_RIGHT_IMAGE) then
		images.right = love.graphics.newImage(paths.HEADER_ALIGNMENT_RIGHT_IMAGE)
	end

	return images
end

-- Create the alignment selection button
local function createAlignmentButton()
	local alignmentOptions = { "Auto", "Left", "Center", "Right" }
	local currentIndex = (state.headerTextAlignment or 0) + 1

	return Button:new({
		text = "Alignment",
		type = ButtonTypes.INDICATORS,
		options = alignmentOptions,
		currentOptionIndex = currentIndex,
		screenWidth = state.screenWidth,
		context = "headerAlignment",
	})
end

-- Handle option cycling
local function handleOptionCycle(button, direction)
	if not button.context or button.context ~= "headerAlignment" then
		return false
	end

	local changed = button:cycleOption(direction)
	if not changed then
		return false
	end

	local newValue = button:getCurrentOption()
	local alignmentMap = { ["Auto"] = 0, ["Left"] = 1, ["Center"] = 2, ["Right"] = 3 }
	state.headerTextAlignment = alignmentMap[newValue] or 2

	return true
end

function headerAlignment.load()
	input = inputHandler.create()
	previewImages = loadPreviewImages()

	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = 60, -- Fixed height for single button
		items = { createAlignmentButton() },
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		onItemOptionCycle = handleOptionCycle,
	})
end

function headerAlignment.draw()
	background.draw()
	header.draw("header alignment")

	-- Draw warning text below header
	local warningText =
		"You must set the 'Status Alignment' and 'Time Alignment' settings appropriately to avoid overlapping elements."
	love.graphics.setFont(fonts.loaded.caption)
	love.graphics.setColor(colors.ui.subtext)
	local warningY = header.getContentStartY() + 2
	local warningWidth = state.screenWidth - (EDGE_PADDING * 2)
	love.graphics.printf(warningText, EDGE_PADDING, warningY, warningWidth, "left")
	love.graphics.setFont(fonts.loaded.body)

	-- Calculate warning text height
	local _, wrappedLines = fonts.loaded.caption:getWrap(warningText, warningWidth)
	local warningHeight = #wrappedLines * fonts.loaded.caption:getHeight() + 10

	-- Position the menu list below the warning text
	if menuList then
		menuList.y = header.getContentStartY() + warningHeight + 6
		menuList:draw()
	end

	-- Draw preview image below the button
	local controlsHeight = controls.HEIGHT or controls.calculateHeight()
	local listBottom = menuList and (menuList.y + menuList:getContentHeight())
		or (header.getContentStartY() + warningHeight + 6 + 60)
	local previewY = listBottom + IMAGE_MARGIN
	local previewAreaHeight = state.screenHeight - previewY - controlsHeight - IMAGE_MARGIN
	local previewAreaWidth = state.screenWidth - (IMAGE_MARGIN * 2)

	-- Get the appropriate preview image based on current alignment
	local currentAlignment = state.headerTextAlignment or 2
	local currentImage = nil

	if currentAlignment == 1 then -- Left
		currentImage = previewImages.left
	elseif currentAlignment == 2 then -- Center
		currentImage = previewImages.center
	elseif currentAlignment == 3 then -- Right
		currentImage = previewImages.right
	end
	-- No image for Auto (currentAlignment == 0)

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

		-- Center the image horizontally and vertically
		local previewX = (state.screenWidth - previewWidth) / 2
		local centeredPreviewY = previewY + (previewAreaHeight - previewHeight) / 2

		-- Draw using the image component
		imageComponent.draw(currentImage, previewX, centeredPreviewY, previewWidth, previewHeight)
	end

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Change" },
		{ button = "b", text = "Back" },
	})
end

function headerAlignment.update(dt)
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end

	-- Handle B button press to go back
	if input.isPressed("b") then
		screens.switchTo("main_menu")
	end
end

function headerAlignment.onEnter(data)
	-- Reload images and recreate button in case state changed
	previewImages = loadPreviewImages()
	if menuList then
		menuList:setItems({ createAlignmentButton() })
	end
end

function headerAlignment.onExit()
	-- Clean up preview images
	for _, image in pairs(previewImages) do
		if image then
			image:release()
		end
	end
	previewImages = {}
end

return headerAlignment
