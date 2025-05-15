--- Manage Themes screen
local love = require("love")
local state = require("state")
local controls = require("controls")
local input = require("input")
local paths = require("paths")
local header = require("ui.header")
local background = require("ui.background")
local list_select = require("ui.list_select")
local modal = require("ui.modal")
local logger = require("utils.logger")
local system = require("utils.system")

local manage_themes = {}

local switchScreen = nil
local themeItems = {}
local actionButtons = nil -- No action buttons now
local scrollPosition = 0
local visibleCount = 0
local modalMode = "none" -- none, confirm_delete, error, deleted

-- Helper to scan for .muxthm files in paths.THEME_DIR
local function scanThemes()
	themeItems = {}
	local p = paths.THEME_DIR
	local files = system.listFiles(p, "*.muxthm")
	for _, file in ipairs(files) do
		table.insert(themeItems, { text = file, checked = false, selected = #themeItems == 0 })
	end
end

function manage_themes.load()
	scanThemes()
	scrollPosition = 0
end

function manage_themes.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

function manage_themes.draw()
	background.draw()
	header.draw("MANAGE THEMES")
	local startY = header.getHeight()
	love.graphics.setFont(state.fonts.body)
	local selectedCount = 0
	for _, item in ipairs(themeItems) do
		if item.checked then
			selectedCount = selectedCount + 1
		end
	end
	local result = list_select.draw({
		items = themeItems,
		actions = {},
		startY = startY,
		itemHeight = state.fonts.body:getHeight() + 24,
		scrollPosition = scrollPosition,
		screenWidth = state.screenWidth,
		screenHeight = state.screenHeight,
		selectedCount = selectedCount,
	})
	visibleCount = result.visibleCount
	if modal.isModalVisible() then
		modal.drawModal(state.screenWidth, state.screenHeight, state.fonts.body)
	end
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	if selectedCount > 0 then
		table.insert(controlsList, { button = "x", text = "Delete" })
	end
	controls.draw(controlsList)
end

function manage_themes.update(dt)
	-- Ensure modal animations and visibility are updated
	modal.update(dt)

	local vjoy = input.virtualJoystick
	if modal.isModalVisible() then
		if vjoy.isGamepadPressedWithDelay("a") then
			if modalMode == "confirm_delete" then
				-- Delete selected themes
				local toDelete = {}
				for _, item in ipairs(themeItems) do
					if item.checked then
						table.insert(toDelete, item.text)
					end
				end
				if #toDelete > 0 then
					for _, fname in ipairs(toDelete) do
						os.execute("rm '" .. paths.THEME_DIR .. "/" .. fname .. "'")
					end
					modalMode = "deleted"
					modal.showModal("Selected themes deleted.", { { text = "Close", selected = true } })
					scanThemes()
				else
					modalMode = "none"
					modal.hideModal()
				end
			elseif modalMode == "deleted" or modalMode == "error" then
				modalMode = "none"
				modal.hideModal()
			end
			return
		end
		if vjoy.isGamepadPressedWithDelay("b") then
			modalMode = "none"
			modal.hideModal()
			return
		end
		return
	end

	-- D-pad up/down navigates theme list
	if vjoy.isGamepadPressedWithDelay("dpup") then
		local idx = list_select.navigate(themeItems, -1)
		scrollPosition = list_select.adjustScrollPosition({
			selectedIndex = idx,
			scrollPosition = scrollPosition,
			visibleCount = visibleCount,
		})
	elseif vjoy.isGamepadPressedWithDelay("dpdown") then
		local idx = list_select.navigate(themeItems, 1)
		scrollPosition = list_select.adjustScrollPosition({
			selectedIndex = idx,
			scrollPosition = scrollPosition,
			visibleCount = visibleCount,
		})
	end

	-- Select/deselect theme with A
	if vjoy.isGamepadPressedWithDelay("a") then
		local idx = list_select.findSelectedIndex(themeItems)
		if idx > 0 then
			list_select.toggleChecked(themeItems, idx)
		end
	end
	-- Delete action with X button
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
			modal.showModal("This action cannot be undone. Are you sure you want to delete the selected themes?", {
				{ text = "Delete", selected = true },
				{ text = "Cancel", selected = false },
			})
		else
			modalMode = "error"
			modal.showModal("No themes selected.", { { text = "Close", selected = true } })
		end
		return
	end
	-- Back to settings
	if vjoy.isGamepadPressedWithDelay("b") then
		if switchScreen then
			switchScreen("settings")
		end
		return
	end
end

function manage_themes.onExit()
	modal.hideModal()
	modalMode = "none"
	scrollPosition = 0
end

return manage_themes
