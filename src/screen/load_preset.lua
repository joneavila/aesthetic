--- Load preset screen
local love = require("love")
local colors = require("colors")
local state = require("state")
local controls = require("controls")
local presets = require("utils.presets")
local rgbUtils = require("utils.rgb")
local system = require("utils.system")

-- Module table to export public functions
local loadPreset = {}

-- Screen switching
local switchScreen = nil

-- Screen constants
local SCREEN = {
	PADDING = 20,
	ITEM_HEIGHT = 50,
	ITEM_SPACING = 10,
	TITLE_HEIGHT = 60,
}

-- Preset items list
local presetItems = {}
local selectedIndex = 1

-- Scrolling
local scrollPosition = 0
local visibleItemCount = 0
local scrollBarWidth = 10
local scrollBarGap = 5

-- Helper function to load presets and verify they are valid
local function loadPresetsList()
	-- Clear existing presets
	presetItems = {}

	-- Get list of presets
	local availablePresets = presets.listPresets()

	-- Validate each preset using the presets.validatePreset function
	for _, presetName in ipairs(availablePresets) do
		local isValid = presets.validatePreset(presetName)

		-- Add to the list regardless, but mark invalid ones
		table.insert(presetItems, {
			name = presetName,
			selected = false,
			isValid = isValid,
		})
	end

	-- Select the first preset if available
	if #presetItems > 0 then
		presetItems[1].selected = true
		selectedIndex = 1
	end

	-- Calculate how many items can be displayed
	local availableHeight = state.screenHeight - SCREEN.TITLE_HEIGHT - controls.HEIGHT - (SCREEN.PADDING * 2)
	visibleItemCount = math.floor(availableHeight / (SCREEN.ITEM_HEIGHT + SCREEN.ITEM_SPACING))
end

function loadPreset.load()
	loadPresetsList()
end

function loadPreset.draw()
	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	-- Draw title
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(state.fonts.header)
	love.graphics.print("Load Preset", SCREEN.PADDING, SCREEN.PADDING)

	-- Draw message if no presets found
	if #presetItems == 0 then
		love.graphics.setFont(state.fonts.body)
		love.graphics.print("No presets found", SCREEN.PADDING, SCREEN.TITLE_HEIGHT + SCREEN.PADDING)

		-- Draw controls
		controls.draw({
			{ button = "b", text = "Back" },
		})
		return
	end

	-- Calculate visible range
	local startIndex = math.floor(scrollPosition) + 1
	local endIndex = math.min(startIndex + visibleItemCount - 1, #presetItems)

	-- Draw preset items
	love.graphics.setFont(state.fonts.body)
	for i = startIndex, endIndex do
		local item = presetItems[i]
		local y = SCREEN.TITLE_HEIGHT + ((i - startIndex) * (SCREEN.ITEM_HEIGHT + SCREEN.ITEM_SPACING))

		-- Draw item background if selected
		if item.selected then
			love.graphics.setColor(colors.ui.surface)
			love.graphics.rectangle("fill", 0, y, state.screenWidth - scrollBarWidth - scrollBarGap, SCREEN.ITEM_HEIGHT)
		end

		-- Draw item text
		if item.isValid then
			love.graphics.setColor(colors.ui.foreground)
		else
			-- Use red color for invalid presets
			love.graphics.setColor(0.8, 0.2, 0.2, 1)
		end

		love.graphics.print(item.name, SCREEN.PADDING, y + (SCREEN.ITEM_HEIGHT - state.fonts.body:getHeight()) / 2)
	end

	-- Draw scrollbar if needed
	if #presetItems > visibleItemCount then
		-- Draw scrollbar background
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 0.2)
		local scrollbarBgHeight = visibleItemCount * (SCREEN.ITEM_HEIGHT + SCREEN.ITEM_SPACING)
		love.graphics.rectangle(
			"fill",
			state.screenWidth - scrollBarWidth,
			SCREEN.TITLE_HEIGHT,
			scrollBarWidth,
			scrollbarBgHeight
		)

		-- Draw scrollbar handle
		love.graphics.setColor(colors.ui.foreground)
		local scrollRatio = scrollPosition / (#presetItems - visibleItemCount)
		local handleHeight = (visibleItemCount / #presetItems) * scrollbarBgHeight
		local handleY = SCREEN.TITLE_HEIGHT + scrollRatio * (scrollbarBgHeight - handleHeight)
		love.graphics.rectangle("fill", state.screenWidth - scrollBarWidth, handleY, scrollBarWidth, handleHeight)
	end

	-- Draw controls
	controls.draw({
		{ button = "d_pad", text = "Navigate" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function loadPreset.update(_dt)
	if not state.canProcessInput() then
		return
	end

	local virtualJoystick = require("input").virtualJoystick
	local moved = false

	-- Handle D-pad navigation
	if virtualJoystick:isGamepadDown("dpup") or virtualJoystick:isGamepadDown("dpdown") then
		local direction = virtualJoystick:isGamepadDown("dpup") and -1 or 1

		-- Update selected index
		presetItems[selectedIndex].selected = false
		selectedIndex = selectedIndex + direction

		-- Wrap around
		if selectedIndex < 1 then
			selectedIndex = #presetItems
		elseif selectedIndex > #presetItems then
			selectedIndex = 1
		end

		presetItems[selectedIndex].selected = true
		moved = true

		-- Update scroll position if necessary
		if selectedIndex <= scrollPosition then
			scrollPosition = math.max(0, selectedIndex - 1)
		elseif selectedIndex > scrollPosition + visibleItemCount then
			scrollPosition = math.min(#presetItems - visibleItemCount, selectedIndex - visibleItemCount)
		end
	end

	-- Handle A button (Select)
	if virtualJoystick:isGamepadDown("a") and #presetItems > 0 then
		local selectedPreset = presetItems[selectedIndex]

		if selectedPreset.isValid then
			-- Load the selected preset
			local success = presets.loadPreset(selectedPreset.name)
			if success then
				-- Update RGB configuration immediately after loading preset
				rgbUtils.updateConfig()

				-- Return to settings screen
				if switchScreen then
					switchScreen("settings")
					state.resetInputTimer()
					state.forceInputDelay(0.2) -- Add extra delay when switching screens
				end
			end
		end

		state.resetInputTimer()
	end

	-- Handle B button (Back)
	if virtualJoystick:isGamepadDown("b") and switchScreen then
		switchScreen("settings")
		state.resetInputTimer()
		state.forceInputDelay(0.2) -- Add extra delay when switching screens
	end

	-- Reset input timer if moved
	if moved then
		state.resetInputTimer()
	end
end

function loadPreset.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

-- Function called when entering this screen
function loadPreset.onEnter()
	-- Refresh the presets list
	loadPresetsList()
end

return loadPreset
