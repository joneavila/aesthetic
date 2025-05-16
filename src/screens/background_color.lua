--- Background color screen with Solid/Gradient options
local love = require("love")
local state = require("state")
local controls = require("controls")
local button = require("ui.button")
local header = require("ui.header")
local background = require("ui.background")
local list = require("ui.list")
local fonts = require("ui.fonts")

local backgroundColor = {}

-- Screen switching
local switchScreen = nil

-- List of buttons
local buttons = {}
-- Scrolling
local scrollPosition = 0
local visibleButtonCount = 0

local function getDirectionText()
	return state.backgroundGradientDirection or "Vertical"
end

local function cycleDirection()
	if state.backgroundGradientDirection == "Vertical" then
		state.backgroundGradientDirection = "Horizontal"
	else
		state.backgroundGradientDirection = "Vertical"
	end
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
	buttons[1].selected = true
end

function backgroundColor.load()
	buildButtonsList()
end

function backgroundColor.draw()
	-- Draw the background first
	background.draw()

	-- Draw header
	header.draw("BACKGROUND COLOR")

	love.graphics.setFont(state.fonts.body)

	local headerHeight = header.getHeight()

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
	visibleButtonCount = result.visibleCount

	-- Draw controls
	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
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

	-- Handle D-pad navigation
	if virtualJoystick.isGamepadPressedWithDelay("dpup") then
		list.navigate(buttons, -1)
	elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
		list.navigate(buttons, 1)
	end

	-- Handle cycling through options with left/right for the type and direction selectors
	if virtualJoystick.isGamepadPressedWithDelay("dpleft") or virtualJoystick.isGamepadPressedWithDelay("dpright") then
		for _, btn in ipairs(buttons) do
			if btn.selected and btn.typeToggle then
				if btn.valueText == "Solid" then
					btn.valueText = "Gradient"
					state.backgroundType = "Gradient"
				else
					btn.valueText = "Solid"
					state.backgroundType = "Solid"
				end
				buildButtonsList()
				break
			elseif btn.selected and btn.directionToggle then
				cycleDirection()
				btn.valueText = getDirectionText()
				break
			end
		end
	end

	-- Handle button selection (A button)
	if virtualJoystick.isGamepadPressedWithDelay("a") then
		for _, btn in ipairs(buttons) do
			if btn.selected then
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
				break
			end
		end
	end

	-- Update scroll position based on selected button
	local selectedIndex = list.findSelectedIndex(buttons)
	if selectedIndex > 0 then
		scrollPosition = list.adjustScrollPosition({
			selectedIndex = selectedIndex,
			scrollPosition = scrollPosition,
			visibleCount = visibleButtonCount,
		})
	end
end

function backgroundColor.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function backgroundColor.onEnter()
	buildButtonsList()
end

return backgroundColor
