--- Settings screen
local love = require("love")

local controls = require("controls")
local errorHandler = require("error_handler")
local paths = require("paths")
local screens = require("screens")
local state = require("state")
local system = require("utils.system")

local background = require("ui.background")
local Button = require("ui.button").Button
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List
local modalModule = require("ui.modal")
local Modal = modalModule.Modal

-- Screen module
local settings = {}

-- Last selected index for persistence
local lastSelectedIndex = 1

-- Modal state tracking
local presetName = nil
local menuList = nil
local input = nil
local modalInstance = nil

-- Function to save current state as a preset
local function saveThemePreset(name)
	-- Ensure presets directory exists
	if not system.isDir(paths.PRESETS_DIR) then
		local success = system.createDirectory(paths.PRESETS_DIR)
		if not success then
			errorHandler.setError("Failed to create presets directory: " .. paths.PRESETS_DIR)
			return false
		end
	end

	-- Create preset file path
	local presetPath = paths.PRESETS_DIR .. "/" .. name .. ".lua"

	-- Create the file
	local file, err = io.open(presetPath, "w")
	if not file then
		errorHandler.setError("Failed to create preset file: " .. (err or "unknown error"))
		return false
	end

	-- Serialize the current state as Lua code
	file:write("-- Aesthetic theme preset: " .. name .. "\n")
	file:write("return {\n")

	-- Background color
	file:write("  background = {\n")
	file:write('    value = "' .. state.getColorValue("background") .. '",\n')
	file:write('    type = "' .. state.backgroundType .. '",\n')
	file:write("  },\n")

	-- Background gradient color
	file:write("  backgroundGradient = {\n")
	file:write('    value = "' .. state.getColorValue("backgroundGradient") .. '",\n')
	file:write('    direction = "' .. (state.backgroundGradientDirection or "Vertical") .. '",\n')
	file:write("  },\n")

	-- Foreground color
	file:write("  foreground = {\n")
	file:write('    value = "' .. state.getColorValue("foreground") .. '",\n')
	file:write("  },\n")

	-- RGB lighting
	file:write("  rgb = {\n")
	file:write('    value = "' .. state.getColorValue("rgb") .. '",\n')
	file:write('    mode = "' .. state.rgbMode .. '",\n')
	file:write("    brightness = " .. state.rgbBrightness .. ",\n")
	file:write("    speed = " .. state.rgbSpeed .. ",\n")
	file:write("  },\n")

	-- Box art width
	file:write("  boxArtWidth = " .. state.boxArtWidth .. ",\n")

	-- Font family
	file:write('  font = "' .. fonts.getSelectedFont() .. '",\n')

	-- Font size
	file:write('  fontSize = "' .. fonts.getFontSize() .. '",\n')

	-- Navigation alignment
	file:write('  navigationAlignment = "' .. state.navigationAlignment .. '",\n')

	-- Navigation alpha
	file:write("  navigationAlpha = " .. state.navigationAlpha .. ",\n")

	-- Status alignment
	file:write('  statusAlignment = "' .. state.statusAlignment .. '",\n')

	-- Time alignment
	file:write('  timeAlignment = "' .. state.timeAlignment .. '",\n')

	-- Header text alignment
	file:write("  headerTextAlignment = " .. state.headerTextAlignment .. ",\n")

	-- Glyphs
	file:write("  glyphs_enabled = " .. tostring(state.glyphs_enabled) .. ",\n")

	-- Theme name
	file:write('  themeName = "' .. state.themeName .. '",\n')

	-- Header text enabled
	file:write('  headerTextEnabled = "' .. state.headerTextEnabled .. '",\n')

	-- Header text alpha
	file:write("  headerTextAlpha = " .. tostring(state.headerTextAlpha) .. ",\n")

	-- Launch screen type
	file:write('  launchScreenType = "' .. state.launchScreenType .. '",\n')

	-- Preset metadata
	file:write('  presetName = "' .. name .. '",\n')
	file:write('  createdAt = "' .. os.date("%Y-%m-%d %H:%M:%S") .. '",\n')

	file:write("}\n")

	file:close()
	return true
end

local function createMenuButtons()
	return {
		Button:new({
			text = "Save Theme Preset",
			onClick = function()
				screens.switchTo("virtual_keyboard", {
					title = "Enter Preset Name",
					returnScreen = "settings",
					inputValue = "",
				})
			end,
		}),
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
	})
	-- Create modal instance
	modalInstance = Modal:new({
		font = fonts.loaded.body,
	})
end

function settings.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("settings")

	-- Set font for consistent sizing
	love.graphics.setFont(fonts.loaded.body)

	-- Draw the buttons using our list component
	if menuList then
		menuList:draw()
	end

	-- Draw modal if visible (now handled by modal component)
	if modalInstance and modalInstance:isVisible() then
		modalInstance:draw(state.screenWidth, state.screenHeight, fonts.loaded.body)
	end

	-- Draw controls at bottom of screen
	controls.draw({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
end

function settings.update(dt)
	if modalInstance and modalInstance:isVisible() then
		if modalInstance:handleInput(input) then
			return
		end
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
function settings.onEnter(params)
	-- Reset modal state
	if modalInstance then
		modalInstance:hide()
	end
	modalMode = "none"

	-- Check if returning from virtual keyboard with a preset name
	if params and params.inputValue and params.inputValue ~= "" then
		presetName = params.inputValue

		-- Save the preset
		local success = saveThemePreset(presetName)

		if success then
			-- Show success modal
			modalInstance:show("Theme preset saved successfully", {
				{
					text = "Close",
					onSelect = function()
						modalInstance:hide()
					end,
				},
			})
		else
			-- Show error modal
			modalInstance:show("Failed to save theme preset", {
				{
					text = "Close",
					onSelect = function()
						modalInstance:hide()
					end,
				},
			})
		end
	end

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
