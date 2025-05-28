--- Manage Themes screen
local love = require("love")
local state = require("state")
local controls = require("controls")
local input = require("input")
local paths = require("paths")
local header = require("ui.header")
local background = require("ui.background")
local ListSelect = require("ui.list_select").ListSelect
local Modal = require("ui.modal").Modal
local logger = require("utils.logger")
local system = require("utils.system")
local commands = require("utils.commands")
local screens = require("screens")

local manage_themes = {}

local themeItems = {}
local modalMode = "none"
local savedSelectedIndex = 1
local listSelect = nil
local inputObj = nil
local modalInstance = nil

local function scanThemes()
	themeItems = {}
	local p = paths.THEME_DIR
	local files = system.listFiles(p, "*.muxthm")
	for _, file in ipairs(files) do
		table.insert(themeItems, { text = file, checked = false, selected = #themeItems == 0 })
	end
end

function manage_themes.load()
	inputObj = input
	scanThemes()
	listSelect = ListSelect:new({
		x = 0,
		y = header.getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - header.getContentStartY() - 60,
		items = themeItems,
		itemHeight = state.fonts.body:getHeight() + 24,
		onItemChecked = function(item, idx)
			-- No-op, handled by ListSelect
		end,
		onActionSelected = function(action, idx)
			-- No actions in this screen
		end,
		wrap = false,
		paddingX = 16,
		paddingY = 8,
	})
	modalInstance = Modal:new({ font = state.fonts.body })
end

function manage_themes.draw()
	background.draw()
	header.draw("manage themes")
	love.graphics.setFont(state.fonts.body)
	if listSelect then
		listSelect:draw()
	end
	if modalInstance and modalInstance:isVisible() then
		modalInstance:draw(state.screenWidth, state.screenHeight, state.fonts.body)
	end
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	if listSelect and #listSelect:getCheckedItems() > 0 then
		table.insert(controlsList, { button = "x", text = "Delete" })
	end
	controls.draw(controlsList)
end

function manage_themes.update(dt)
	local vjoy = input.virtualJoystick
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
					if listSelect then
						listSelect:setItems(themeItems)
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
	if listSelect then
		listSelect:handleInput(inputObj)
		listSelect:update(dt)
	end
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
	if vjoy.isGamepadPressedWithDelay("b") then
		screens.switchTo("settings")
		return
	end
end

function manage_themes.onEnter(data)
	scanThemes()
	if listSelect then
		listSelect:setItems(themeItems)
	end
end

function manage_themes.onExit()
	if modalInstance then
		modalInstance:hide()
	end
	modalMode = "none"
end

return manage_themes
