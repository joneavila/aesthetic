--- Background color/gradient screen with Solid/Gradient options
local love = require("love")

local controls = require("controls")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.button").Button
local ButtonTypes = require("ui.button").TYPES
local fonts = require("ui.fonts")
local gradientPreview = require("ui.gradient_preview")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List

local backgroundColor = {}

local menuList = nil
local input = nil

-- Function to update gradient preview mesh
local function updateGradientPreview()
	if state.backgroundType == "Gradient" then
		local bgColor = state.getColorValue("background")
		local gradientColor = state.getColorValue("backgroundGradient")
		local direction = state.backgroundGradientDirection or "Vertical"
		gradientPreview.updateMesh(bgColor, gradientColor, direction)
	end
end

-- Function to build buttons list
local function createMenuButtons()
	local buttons = {}
	table.insert(
		buttons,
		Button:new({
			text = "Type",
			type = ButtonTypes.INDICATORS,
			options = { "Solid", "Gradient" },
			currentOptionIndex = (state.backgroundType == "Gradient" and 2) or 1,
			screenWidth = state.screenWidth,
			context = "typeToggle",
		})
	)
	if state.backgroundType == "Gradient" then
		table.insert(
			buttons,
			Button:new({
				text = "Color Start",
				type = ButtonTypes.COLOR,
				hexColor = state.getColorValue("background"),
				monoFont = fonts.loaded.monoBody,
				screenWidth = state.screenWidth,
				onClick = function()
					state.activeColorContext = "background"
					state.previousScreen = "background"
					screens.switchTo("color_picker")
				end,
			})
		)
		table.insert(
			buttons,
			Button:new({
				text = "Color Stop",
				type = ButtonTypes.COLOR,
				hexColor = state.getColorValue("backgroundGradient"),
				monoFont = fonts.loaded.monoBody,
				screenWidth = state.screenWidth,
				onClick = function()
					state.activeColorContext = "backgroundGradient"
					state.previousScreen = "background"
					screens.switchTo("color_picker")
				end,
			})
		)
		table.insert(
			buttons,
			Button:new({
				text = "Direction",
				type = ButtonTypes.INDICATORS,
				options = { "Vertical", "Horizontal" },
				currentOptionIndex = (state.backgroundGradientDirection == "Horizontal" and 2) or 1,
				screenWidth = state.screenWidth,
				context = "directionToggle",
			})
		)
	else
		table.insert(
			buttons,
			Button:new({
				text = "Color",
				type = ButtonTypes.COLOR,
				hexColor = state.getColorValue("background"),
				monoFont = fonts.loaded.monoBody,
				screenWidth = state.screenWidth,
				onClick = function()
					state.activeColorContext = "background"
					screens.switchTo("color_picker")
				end,
			})
		)
	end
	return buttons
end

local function handleOptionCycle(button, direction)
	if button.context == "typeToggle" then
		local changed = button:cycleOption(direction)
		if changed then
			state.backgroundType = button:getCurrentOption()
			updateGradientPreview()
			menuList:setItems(createMenuButtons())
		end
		return changed
	elseif button.context == "directionToggle" then
		local changed = button:cycleOption(direction)
		if changed then
			state.backgroundGradientDirection = button:getCurrentOption()
			updateGradientPreview()
		end
		return changed
	end
	return false
end

function backgroundColor.draw()
	-- Draw the background first
	background.draw()

	-- Draw header
	header.draw("background")

	love.graphics.setFont(fonts.loaded.body)

	if menuList then
		menuList:draw()
	end

	-- Draw gradient preview box if gradient mode is selected
	if state.backgroundType == "Gradient" then
		local controlsHeight = controls.HEIGHT or controls.calculateHeight()
		local margin = 10
		local listBottom = menuList.y + menuList:getContentHeight()
		local previewY = listBottom + margin
		local previewX_margin = 20
		local previewAreaHeight = state.screenHeight - previewY - controlsHeight - margin
		local previewAreaWidth = state.screenWidth - previewX_margin * 2
		-- Maintain 4:3 aspect ratio, but fit within available area
		local previewHeight = previewAreaHeight
		local previewWidth = previewHeight * 4 / 3
		if previewWidth > previewAreaWidth then
			previewWidth = previewAreaWidth
			previewHeight = previewWidth * 3 / 4
		end
		if previewHeight >= 40 then
			local previewX = (state.screenWidth - previewWidth) / 2
			gradientPreview.draw(
				previewX,
				previewY,
				previewWidth,
				previewHeight,
				state.getColorValue("background"),
				state.getColorValue("backgroundGradient"),
				state.backgroundGradientDirection,
				8
			)
		end
	end

	-- Draw controls
	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Save" },
	})
end

function backgroundColor.update(dt)
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end
	local virtualJoystick = require("input").virtualJoystick
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		screens.switchTo("main_menu")
		return
	end
end

function backgroundColor.onEnter()
	-- Initialize input handler
	input = inputHandler.create()

	-- Create menu list
	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - header.getContentStartY() - 60,
		items = createMenuButtons(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		onItemOptionCycle = handleOptionCycle,
	})
end

return backgroundColor
