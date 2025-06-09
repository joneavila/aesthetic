--- Manage Themes screen
local love = require("love")

local colors = require("colors")
local controls = require("control_hints")
local paths = require("paths")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local fonts = require("ui.fonts")
local header = require("ui.header")
local inputHandler = require("ui.input_handler")
local List = require("ui.list").List
local Modal = require("ui.modal").Modal

local svg = require("utils.svg")
local system = require("utils.system")

local delete_themes = {}

local themeItems = {}
local themeList = nil
local inputObj = nil
local modalInstance = nil

-- Preload icons for checkboxes
local SQUARE = svg.loadIcon("square", 24)
local SQUARE_CHECK_ICON = svg.loadIcon("square-check", 24)

-- Custom checkbox item component
local CheckboxItem = {}
CheckboxItem.__index = CheckboxItem

function CheckboxItem.new(_self, text, index)
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
	local name = filename:gsub("%.muxthm$", "") -- Remove .muxthm extension
	return CheckboxItem:new(name, index)
end

local function scanThemes()
	themeItems = {}
	local p = paths.MUOS_THEMES_DIR
	local files = system.listFiles(p, "*.muxthm")
	for i, file in ipairs(files) do
		local item = createThemeCheckboxItem(file, i)
		table.insert(themeItems, item)
	end
end

function delete_themes.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	header.draw("manage themes")

	-- Draw theme directory path in mono font between header and list
	love.graphics.setFont(fonts.loaded.monoBody)
	local dirText = "Theme directory: " .. paths.MUOS_THEMES_DIR
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.print(dirText, 32, header.getContentStartY() + 8)

	-- Reset font to the regular body font after header drawing
	love.graphics.setFont(fonts.loaded.body)

	-- Adjust list Y to account for directory text
	local listY = header.getContentStartY() + 8 + fonts.loaded.monoBody:getHeight() + 12
	if themeList then
		themeList.y = listY
		themeList.height = state.screenHeight - listY - controls.calculateHeight()
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

function delete_themes.update(dt)
	if modalInstance and modalInstance:isVisible() then
		if modalInstance:handleInput(inputObj) then
			return
		end
	end

	-- Update modal animation
	if modalInstance then
		modalInstance:update(dt)
	end

	if not themeList then
		return
	end

	local handled = themeList:handleInput(inputObj)
	themeList:update(dt)

	if handled then
		return
	end

	if inputObj.isPressed("b") then
		screens.switchTo("settings")
	elseif inputObj.isPressed("x") then
		local checkedCount = 0
		local checkedItems = {}
		for _, item in ipairs(themeItems) do
			if item.checked then
				checkedCount = checkedCount + 1
				table.insert(checkedItems, item.text)
			end
		end

		if checkedCount == 0 then
			return
		end

		local message = string.format("Delete %d selected theme%s?", checkedCount, checkedCount > 1 and "s" or "")
		modalInstance:show(message, {
			{
				text = "Cancel",
				onSelect = function()
					modalInstance:hide()
				end,
			},
			{
				text = "Delete",
				onSelect = function()
					local deleteSuccess = true
					for _, themeName in ipairs(checkedItems) do
						local fullPath = paths.MUOS_THEMES_DIR .. "/" .. themeName .. ".muxthm"
						if not system.removeFile(fullPath) then
							deleteSuccess = false
						end
					end
					if deleteSuccess then
						modalInstance:show("Themes deleted successfully", {
							{
								text = "Close",
								onSelect = function()
									modalInstance:hide()
									scanThemes()
									if themeList then
										themeList:setItems(themeItems)
									end
								end,
							},
						})
					else
						modalInstance:show("Failed to delete some themes", {
							{
								text = "Close",
								onSelect = function()
									modalInstance:hide()
									scanThemes()
									if themeList then
										themeList:setItems(themeItems)
									end
								end,
							},
						})
					end
				end,
			},
		})
	end
end

function delete_themes.onEnter(_data)
	-- Initialize input handler
	inputObj = inputHandler.create()

	-- Create modal
	modalInstance = Modal:new({ font = fonts.loaded.body })

	scanThemes()

	-- Create theme list
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
	})
end

function delete_themes.onExit()
	if modalInstance then
		modalInstance:hide()
	end
end

return delete_themes
