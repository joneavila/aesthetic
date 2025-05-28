--- Settings screen
local love = require("love")
local state = require("state")
local controls = require("controls")
local input = require("input")
local presets = require("utils.presets")
local header = require("ui.header")
local background = require("ui.background")
local Button = require("ui.button").Button
local List = require("ui.list").List
local modalModule = require("ui.modal")
local Modal = modalModule.Modal
local screens = require("screens")
local inputHandler = require("ui.input_handler")

-- Screen module
local settings = {}

-- Button constants
local BUTTONS = {
	-- { text = "Save theme preset", selected = true }, -- Disabled until the feature is more complete
	{ text = "Load Theme Preset", selected = true },
	{ text = "Manage Themes", selected = false },
	{ text = "About", selected = false },
}

-- Last selected index for persistence
local lastSelectedIndex = 1

-- Modal state tracking
local modalMode = "none" -- none, save_success, load_success, error, save_input
local presetName = nil
local menuList = nil
local input = nil
local modalInstance = nil

-- Helper function to generate a unique preset name
local function generatePresetName()
	local currentTime = os.time()
	local dateString = os.date("%B %d, %Y %I:%M:%S%p", currentTime)
	return dateString
end

local function createMenuButtons()
	return {
		Button:new({
			text = "Load Theme Preset",
			onClick = function()
				screens.switchTo("load_preset")
			end,
		}),
		Button:new({
			text = "Manage Themes",
			onClick = function()
				screens.switchTo("manage_themes")
			end,
		}),
		Button:new({
			text = "About",
			onClick = function()
				screens.switchTo("about")
			end,
		}),
	}
end

function settings.load()
	input = inputHandler.create()
	menuList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - header.getContentStartY() - 60,
		items = createMenuButtons(),
		itemHeight = 60,
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		wrap = false,
		paddingX = 16,
		paddingY = 8,
	})
	-- Create modal instance
	modalInstance = Modal:new({
		font = state.fonts.body,
	})
end

function settings.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("settings")

	-- Calculate start Y position for the list
	local startY = header.getContentStartY()

	-- Set font for consistent sizing
	love.graphics.setFont(state.fonts.body)

	-- Draw the buttons using our list component
	if menuList then
		menuList:draw()
	end

	-- Draw modal if visible (now handled by modal component)
	if modalInstance and modalInstance:isVisible() then
		modalInstance:draw(state.screenWidth, state.screenHeight, state.fonts.body)
	end

	-- Draw controls at bottom of screen
	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function settings.update(dt)
	if modalInstance and modalInstance:isVisible() then
		-- Modal input handling remains unchanged
		return
	end
	if menuList then
		menuList:handleInput(input)
		menuList:update(dt)
	end
	if input.isPressed("b") then
		screens.switchTo("main_menu")
	end
end

-- Handle entry to this screen
function settings.onEnter()
	-- Reset modal state
	if modalInstance then
		modalInstance:hide()
	end
	modalMode = "none"

	-- Reset list state and restore selection
	if menuList then
		menuList:setItems(createMenuButtons())
	end
end

-- Handle cleanup when leaving this screen
function settings.onExit()
	-- Reset modal state
	if modalInstance then
		modalInstance:hide()
	end
	modalMode = "none"

	-- Save the current selected index
	if menuList then
		lastSelectedIndex = menuList.selectedIndex
	end
end

return settings
