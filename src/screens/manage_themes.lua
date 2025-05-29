--- Manage Themes screen
local love = require("love")

local colors = require("colors")
local controls = require("controls")
local input = require("input")
local paths = require("paths")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List
local Modal = require("ui.modal").Modal

local commands = require("utils.commands")
local svg = require("utils.svg")
local system = require("utils.system")

local manage_themes = {}

local themeItems = {}
local modalMode = "none"
local themeList = nil
local inputObj = nil
local modalInstance = nil

-- Preload icons for checkboxes
local SQUARE = svg.loadIcon("square", 24)
local SQUARE_CHECK_ICON = svg.loadIcon("square-check", 24)

-- Custom checkbox item component
local CheckboxItem = {}
CheckboxItem.__index = CheckboxItem

function CheckboxItem:new(text, index)
	local instance = {
		text = text,
		index = index,
		checked = false,
		focused = false,
		x = 0,
		y = 0,
		width = 0,
		height = 0,
	}
	setmetatable(instance, CheckboxItem)
	return instance
end

function CheckboxItem:setPosition(x, y)
	self.x = x
	self.y = y
end

function CheckboxItem:setSize(width, height)
	self.width = width
	self.height = height
end

function CheckboxItem:setFocused(focused)
	self.focused = focused
end

function CheckboxItem:draw()
	local font = love.graphics.getFont()
	local boxSize = 28
	local padding = 16
	local textPadding = 12

	-- Draw background if focused
	if self.focused then
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 8)
	end

	-- Calculate positions
	local boxX = self.x + padding
	local boxY = self.y + (self.height - boxSize) / 2
	local textX = boxX + boxSize + textPadding
	local textY = self.y + (self.height - font:getHeight()) / 2

	-- Draw checkbox
	if self.checked then
		if SQUARE_CHECK_ICON then
			local iconColor = self.focused and { 1, 1, 1, 1 } or colors.ui.accent
			svg.drawIcon(SQUARE_CHECK_ICON, boxX + boxSize / 2, boxY + boxSize / 2, iconColor)
		end
	else
		if SQUARE then
			local iconColor = self.focused and { 1, 1, 1, 1 } or { 0.7, 0.7, 0.7, 1 }
			svg.drawIcon(SQUARE, boxX + boxSize / 2, boxY + boxSize / 2, iconColor)
		end
	end

	-- Draw text
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(font)
	love.graphics.print(self.text, textX, textY)
end

local function createThemeCheckboxItem(filename, index)
	return CheckboxItem:new(filename, index)
end

local function scanThemes()
	themeItems = {}
	local p = paths.THEME_DIR
	local files = system.listFiles(p, "*.muxthm")
	for i, file in ipairs(files) do
		local item = createThemeCheckboxItem(file, i)
		table.insert(themeItems, item)
	end
end

function manage_themes.load()
	inputObj = inputHandler.create()
	scanThemes()
	themeList = List:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - header.getContentStartY() - controls.calculateHeight(),
		items = themeItems,
		itemHeight = fonts.loaded.body:getHeight() + 24,
		onItemSelect = function(item, _idx)
			-- Toggle checked state
			item.checked = not item.checked
		end,
		wrap = false,
		paddingX = 16,
		paddingY = 8,
	})
	modalInstance = Modal:new({ font = fonts.loaded.body })
end

function manage_themes.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("manage themes")

	-- Reset font to the regular body font after header drawing
	love.graphics.setFont(fonts.loaded.body)

	-- Draw the list
	if themeList then
		themeList:draw()
	end

	-- Draw modal if visible
	if modalInstance and modalInstance:isVisible() then
		modalInstance:draw(state.screenWidth, state.screenHeight, fonts.loaded.body)
		return -- Don't draw controls when modal is visible
	end

	-- Count checked items for controls
	local checkedCount = 0
	for _, item in ipairs(themeItems) do
		if item.checked then
			checkedCount = checkedCount + 1
		end
	end

	-- Draw controls
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	if checkedCount > 0 then
		table.insert(controlsList, { button = "x", text = "Delete" })
	end
	controls.draw(controlsList)
end

function manage_themes.update(dt)
	local vjoy = input.virtualJoystick

	-- Handle modal interactions
	if modalInstance and modalInstance:isVisible() then
		if vjoy.isGamepadPressedWithDelay("a") then
			if modalMode == "confirm_delete" then
				local toDelete = {}
				for _, item in ipairs(themeItems) do
					if item.checked then
						table.insert(toDelete, item.text)
					end
				end
				if #toDelete > 0 then
					for _, fname in ipairs(toDelete) do
						commands.executeCommand("rm '" .. paths.THEME_DIR .. "/" .. fname .. "'")
					end
					modalMode = "deleted"
					modalInstance:show("Selected themes deleted.", { { text = "Close", selected = true } })
					scanThemes()
					if themeList then
						themeList:setItems(themeItems)
					end
				else
					modalMode = "none"
					modalInstance:hide()
				end
			elseif modalMode == "deleted" or modalMode == "error" then
				modalMode = "none"
				modalInstance:hide()
			end
			return
		end
		if vjoy.isGamepadPressedWithDelay("b") then
			modalMode = "none"
			modalInstance:hide()
			return
		end
		return
	end

	-- Handle list input
	if themeList then
		themeList:handleInput(inputObj)
		themeList:update(dt)
	end

	-- Handle delete action
	if vjoy.isGamepadPressedWithDelay("x") then
		local anyChecked = false
		for _, item in ipairs(themeItems) do
			if item.checked then
				anyChecked = true
				break
			end
		end
		if anyChecked then
			modalMode = "confirm_delete"
			modalInstance:show("This action cannot be undone. Are you sure you want to delete the selected themes?", {
				{ text = "Delete", selected = true },
				{ text = "Cancel", selected = false },
			})
		else
			modalMode = "error"
			modalInstance:show("No themes selected.", { { text = "Close", selected = true } })
		end
		return
	end

	-- Handle back navigation
	if vjoy.isGamepadPressedWithDelay("b") then
		screens.switchTo("settings")
		return
	end
end

function manage_themes.onEnter(_data)
	scanThemes()
	if themeList then
		themeList:setItems(themeItems)
	end
end

function manage_themes.onExit()
	if modalInstance then
		modalInstance:hide()
	end
	modalMode = "none"
end

return manage_themes
