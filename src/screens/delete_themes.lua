--- Manage Themes screen
local love = require("love")

local colors = require("colors")
local controls = require("control_hints").ControlHints
local paths = require("paths")
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local List = require("ui.components.list").List
local Modal = require("ui.components.modal").Modal
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES

local svg = require("utils.svg")
local system = require("utils.system")
local InputManager = require("ui.controllers.input_manager")

local delete_themes = {}

local themeItems = {}
local themeList = nil
local input = nil
local modalInstance = nil
local controlHintsInstance

-- Preload icons for checkboxes
local SQUARE = svg.loadIcon("square", 24)
local SQUARE_CHECK_ICON = svg.loadIcon("square-check", 24)

-- Remove CheckboxItem and related code

local function createThemeCheckboxButton(filename, index)
	local name = filename:gsub("%.muxthm$", "") -- Remove .muxthm extension
	return Button:new({
		type = ButtonTypes.CHECKBOX,
		text = name,
		checked = false,
		index = index,
	})
end

local function scanThemes()
	themeItems = {}
	local p = paths.MUOS_THEMES_DIR
	local files = system.listFiles(p, "*.muxthm")
	for i, file in ipairs(files) do
		local item = createThemeCheckboxButton(file, i)
		table.insert(themeItems, item)
	end
end

local headerInstance = Header:new({ title = "Manage Themes" })

local PADDING = 16

function delete_themes.draw()
	-- Set background
	background.draw()

	-- Draw header with title
	headerInstance:draw()

	-- Draw theme directory path in mono font between header and list
	love.graphics.setFont(fonts.loaded.monoBody)
	local dirText = "Theme directory: " .. paths.MUOS_THEMES_DIR
	love.graphics.setColor(colors.ui.foreground)
	local dirY = headerInstance:getContentStartY() + 8
	local dirWidth = state.screenWidth - (PADDING * 2)
	local _, wrappedLines = fonts.loaded.monoBody:getWrap(dirText, dirWidth)
	local dirHeight = #wrappedLines * fonts.loaded.monoBody:getHeight()
	love.graphics.printf(dirText, PADDING, dirY, dirWidth, "left")

	-- Reset font to the regular body font after header drawing
	love.graphics.setFont(fonts.loaded.body)

	-- Adjust list Y to account for directory text
	local listY = dirY + dirHeight + 12
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

	if not (modalInstance and modalInstance:isVisible()) then
		local controlsList = {
			{ button = "a", text = "Select" },
			{ button = "b", text = "Back" },
		}
		local checkedCount = 0
		for _, item in ipairs(themeItems) do
			if item.type == ButtonTypes.CHECKBOX and item.checked then
				checkedCount = checkedCount + 1
			end
		end
		if checkedCount > 0 then
			table.insert(controlsList, { button = "x", text = "Delete" })
		end
		controlHintsInstance:setControlsList(controlsList)
		controlHintsInstance:draw()
	end
end

function delete_themes.update(dt)
	if modalInstance and modalInstance:isVisible() then
		if modalInstance:handleInput(input) then
			modalInstance:update(dt)
			return
		end
		modalInstance:update(dt)
		return
	end

	if not themeList then
		return
	end

	-- Use navigation direction for list navigation
	local navDir = InputManager.getNavigationDirection()
	local handled = false
	if navDir == "up" or navDir == "down" then
		handled = themeList:handleInput(navDir, input)
	else
		handled = themeList:handleInput(nil, input)
	end

	themeList:update(dt)

	if handled then
		return
	end

	-- Only allow confirm/cancel/delete if not handled by list, and use justPressed
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("settings")
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.CONFIRM) then
		local checkedCount = 0
		local checkedItems = {}
		for _, item in ipairs(themeItems) do
			if item.type == ButtonTypes.CHECKBOX and item.checked then
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
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.CLEAR) then
		local checkedCount = 0
		local checkedItems = {}
		for _, item in ipairs(themeItems) do
			if item.type == ButtonTypes.CHECKBOX and item.checked then
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
	-- Create modal
	modalInstance = Modal:new({ font = fonts.loaded.body })

	scanThemes()

	-- Create theme list
	themeList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - controls.calculateHeight(),
		items = themeItems,
		itemHeight = fonts.loaded.body:getHeight() + 24,
		onItemSelect = function(item, _idx)
			-- Only toggle checked state for CHECKBOX type
			if item.type == ButtonTypes.CHECKBOX then
				item.checked = not item.checked
			end
		end,
		wrap = false,
	})

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function delete_themes.onExit()
	if modalInstance then
		modalInstance:hide()
	end
end

return delete_themes
