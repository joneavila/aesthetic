--- Background color screen with Solid/Gradient options
local love = require("love")
local state = require("state")
local controls = require("controls")
local button = require("ui.button")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local fonts = require("ui.fonts")
local colorUtils = require("utils.color")
local imageGenerator = require("utils.image_generator")

local backgroundColor = {}

-- Screen switching
local switchScreen = nil

-- List of buttons
local buttons = {}
-- Last selected button index for persistence
local lastSelectedIndex = 1

-- Gradient preview mesh
local gradientPreviewMesh = nil

local function getDirectionText()
	return state.backgroundGradientDirection or "Vertical"
end

-- Function to update gradient preview mesh
local function updateGradientPreview()
	if state.backgroundType == "Gradient" then
		local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
		local gradientColor = colorUtils.hexToLove(state.getColorValue("backgroundGradient"))
		local direction = state.backgroundGradientDirection or "Vertical"
		gradientPreviewMesh = imageGenerator.createGradientMesh(direction, bgColor, gradientColor)
	else
		gradientPreviewMesh = nil
	end
end

local function cycleDirection()
	if state.backgroundGradientDirection == "Vertical" then
		state.backgroundGradientDirection = "Horizontal"
	else
		state.backgroundGradientDirection = "Vertical"
	end
	-- Update gradient preview when direction changes
	updateGradientPreview()
end

-- Function to build buttons list
local function buildButtonsList()
	buttons = {
		{ text = "Type", selected = true, typeToggle = true, valueText = state.backgroundType or "Solid" },
	}
	if state.backgroundType == "Gradient" then
		table.insert(buttons, { text = "Color Start", selected = false, gradientStart = true })
		table.insert(buttons, { text = "Color Stop", selected = false, gradientStop = true })
		table.insert(
			buttons,
			{ text = "Direction", selected = false, directionToggle = true, valueText = getDirectionText() }
		)
	else
		table.insert(buttons, { text = "Color", selected = false, solidColor = true })
	end

	updateGradientPreview()
end

function backgroundColor.load()
	buildButtonsList()
end

function backgroundColor.draw()
	-- Draw the background first
	background.draw()

	-- Draw header
	header.draw("background color")

	love.graphics.setFont(state.fonts.body)

	local headerHeight = header.getHeight()
	local scrollPosition = list.getScrollPosition()

	-- Draw list of buttons
	local result = list.draw({
		items = buttons,
		startY = headerHeight,
		itemHeight = button.calculateHeight(),
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = state.screenHeight,
		drawItemFunc = function(item, _index, y)
			if item.typeToggle then
				button.drawWithIndicators(item.text, 0, y, item.selected, false, state.screenWidth, item.valueText)
			elseif item.directionToggle then
				button.drawWithIndicators(item.text, 0, y, item.selected, false, state.screenWidth, item.valueText)
			elseif item.solidColor then
				button.drawWithColorPreview(
					item.text,
					item.selected,
					0,
					y,
					state.screenWidth,
					state.getColorValue("background"),
					false,
					fonts.loaded.monoBody
				)
			elseif item.gradientStart then
				button.drawWithColorPreview(
					item.text,
					item.selected,
					0,
					y,
					state.screenWidth,
					state.getColorValue("background"),
					false,
					fonts.loaded.monoBody
				)
			elseif item.gradientStop then
				button.drawWithColorPreview(
					item.text,
					item.selected,
					0,
					y,
					state.screenWidth,
					state.getColorValue("backgroundGradient"),
					false,
					fonts.loaded.monoBody
				)
			else
				button.draw(item.text, 0, y, item.selected, state.screenWidth)
			end
		end,
	})

	-- Draw gradient preview box if gradient mode is selected
	if state.backgroundType == "Gradient" and gradientPreviewMesh then
		-- Get the end Y position of the list
		local listEndY = result.endY

		-- Get control hint height to avoid overlapping with bottom controls
		local controlsHeight = controls.HEIGHT or controls.calculateHeight()

		-- Calculate available vertical space between list end and controls
		local availableHeight = state.screenHeight - listEndY - controlsHeight - 20 -- 20px for padding
		local availableWidth = state.screenWidth - 40 -- 20px padding on each side

		-- Calculate dimensions maintaining 4:3 aspect ratio (640x480)
		local previewWidth, previewHeight

		-- Try to fit by height first
		previewHeight = availableHeight -- Use all available height
		previewWidth = previewHeight * 4 / 3 -- Maintain 4:3 aspect ratio

		-- If width doesn't fit, recalculate based on width
		if previewWidth > availableWidth then
			previewWidth = availableWidth
			previewHeight = previewWidth * 3 / 4 -- Maintain 4:3 aspect ratio
		end

		-- Only draw preview if we have enough space
		if previewHeight >= 40 then -- Minimum height threshold to make preview useful
			local previewX = (state.screenWidth - previewWidth) / 2
			local previewY = listEndY + 10 -- 10px padding after list

			-- Draw border
			love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
			love.graphics.rectangle("line", previewX - 2, previewY - 2, previewWidth + 4, previewHeight + 4)

			-- Draw gradient preview
			love.graphics.setColor(1, 1, 1)
			love.graphics.draw(gradientPreviewMesh, previewX, previewY, 0, previewWidth, previewHeight)
		end
	end

	-- Draw controls
	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Save" },
	})
end

function backgroundColor.update(dt)
	local virtualJoystick = require("input").virtualJoystick

	-- Handle back button
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		if switchScreen then
			switchScreen("main_menu")
		end
		return
	end

	-- Use the enhanced list input handler for all navigation and selection
	local result = list.handleInput({
		items = buttons,
		virtualJoystick = virtualJoystick,

		-- Handle button selection (A button)
		handleItemSelect = function(btn)
			lastSelectedIndex = list.getSelectedIndex()

			if btn.solidColor then
				state.activeColorContext = "background"
				state.previousScreen = "background_color"
				if switchScreen then
					switchScreen("color_picker")
				end
			elseif btn.gradientStart then
				state.activeColorContext = "background"
				state.previousScreen = "background_color"
				if switchScreen then
					switchScreen("color_picker")
				end
			elseif btn.gradientStop then
				state.activeColorContext = "backgroundGradient"
				state.previousScreen = "background_color"
				if switchScreen then
					switchScreen("color_picker")
				end
			end
		end,

		-- Handle option cycling (left/right d-pad)
		handleItemOption = function(btn, direction)
			local changed = false

			if btn.typeToggle then
				if btn.valueText == "Solid" then
					btn.valueText = "Gradient"
					state.backgroundType = "Gradient"
				else
					btn.valueText = "Solid"
					state.backgroundType = "Solid"
				end
				buildButtonsList()
				changed = true
			elseif btn.directionToggle then
				cycleDirection()
				btn.valueText = getDirectionText()
				changed = true
			end

			return changed
		end,
	})
end

function backgroundColor.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function backgroundColor.onEnter()
	buildButtonsList()

	-- Use the centralized list state management for screen entry
	list.onScreenEnter("background_color", buttons, lastSelectedIndex)
end

function backgroundColor.onExit()
	-- Store the current selected index before leaving
	lastSelectedIndex = list.onScreenExit()
end

return backgroundColor
