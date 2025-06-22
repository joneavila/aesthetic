--- Settings screen
local love = require("love")

local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local InputManager = require("ui.controllers.input_manager")
local List = require("ui.components.list").List
local Modal = require("ui.components.modal").Modal

local otaUpdate = require("utils.ota_update")
local presets = require("utils.presets")

-- Screen module
local settings = {}

-- Modal state tracking
local presetName = nil
local menuList = nil
local input = nil
local modalInstance = nil

-- OTA update state
local updateCheckInProgress = false
local downloadInProgress = false
local updateInfo = nil
local updateCheckScheduled = false
local updateCheckTimer = 0
local updateCheckMinTime = 0.5 -- Minimum time to show "checking" modal
local downloadThread = nil -- LÖVE thread for downloading

local headerInstance = Header:new({ title = "Settings" })
local controlHintsInstance

-- Function to handle OTA update check
local function checkForUpdates()
	if updateCheckInProgress or downloadInProgress or updateCheckScheduled then
		return
	end

	updateCheckScheduled = true
	updateCheckInProgress = false
	updateCheckTimer = 0
	updateInfo = nil
	modalInstance:show("Checking for updates...", {})
end

-- Function to handle update download
local function downloadUpdate()
	if not updateInfo or downloadInProgress then
		return
	end

	downloadInProgress = true

	-- Start the threaded download
	local success, threadOrError = otaUpdate.startThreadedDownload(updateInfo.downloadUrl, updateInfo.assetName)
	if not success then
		-- Failed to start download
		modalInstance:show("Failed to start download:\n" .. threadOrError, {
			{
				text = "Close",
				onSelect = function()
					modalInstance:hide()
				end,
			},
		})
		downloadInProgress = false
		return
	end

	downloadThread = threadOrError
	modalInstance:show("Downloading update...", {}, { forceSimple = true })
end

local function createMenuButtons()
	return {
		Button:new({
			text = "Save Theme Preset",
			type = "basic",
			onClick = function()
				screens.switchTo("virtual_keyboard", {
					title = "Theme Preset Name",
					returnScreen = "settings",
					inputValue = "",
				})
			end,
		}),
		Button:new({
			text = "Load Theme Preset",
			type = "basic",
			onClick = function()
				screens.switchTo("load_preset")
			end,
		}),
		Button:new({
			text = "Reset to Defaults",
			type = "basic",
			onClick = function()
				modalInstance:show("This will clear your customizations. Reset to defaults?", {
					{
						text = "Cancel",
						onSelect = function()
							modalInstance:hide()
						end,
					},
					{
						text = "Confirm",
						onSelect = function()
							state.resetToDefaults()
							modalInstance:show("Reset to defaults successfully!", {
								{
									text = "Close",
									onSelect = function()
										modalInstance:hide()
										-- Return to settings screen, not main menu
									end,
								},
							})
						end,
					},
				})
			end,
		}),
		Button:new({
			text = "Manage Themes",
			type = "basic",
			onClick = function()
				screens.switchTo("delete_themes")
			end,
		}),
		Button:new({
			text = "Check for Updates",
			type = "basic",
			onClick = function()
				checkForUpdates()
			end,
		}),
		Button:new({
			text = "About",
			type = "basic",
			onClick = function()
				screens.switchTo("about")
			end,
		}),
	}
end

function settings.draw()
	-- Set background
	background.draw()

	headerInstance:draw()

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
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

function settings.update(dt)
	-- Always handle scheduled update check with minimum display time, even if modal is visible
	if updateCheckScheduled then
		updateCheckTimer = updateCheckTimer + dt

		-- Only perform the check after minimum time has passed
		if not updateCheckInProgress and updateCheckTimer >= updateCheckMinTime then
			updateCheckInProgress = true
			-- Perform the check and store result
			updateInfo = otaUpdate.checkForUpdates()
		end

		-- Only show results after minimum time has passed and check is done
		if updateCheckInProgress and updateInfo then
			updateCheckScheduled = false
			updateCheckInProgress = false
			updateCheckTimer = 0

			local result = updateInfo
			updateInfo = nil -- Clear the temporary storage

			if result.error then
				modalInstance:show("Update check failed:\n" .. result.error, {
					{
						text = "Close",
						onSelect = function()
							modalInstance:hide()
						end,
					},
				})
			elseif result.hasUpdate then
				updateInfo = result -- Store for download
				local message = string.format(
					"New version available!\n\n%s → %s\n\nWould you like to download it?",
					result.currentVersion,
					result.latestVersion
				)
				modalInstance:show(message, {
					{
						text = "Download",
						onSelect = function()
							downloadUpdate()
						end,
					},
					{
						text = "Cancel",
						onSelect = function()
							modalInstance:hide()
						end,
					},
				})
			else
				modalInstance:show("You are on the latest version (" .. result.currentVersion .. ")", {
					{
						text = "Close",
						onSelect = function()
							modalInstance:hide()
						end,
					},
				})
			end
		end
	end

	if modalInstance and modalInstance:isVisible() then
		-- Always pass input to modalInstance:handleInput so D-pad up/down works
		if modalInstance:handleInput(input) then
			modalInstance:update(dt)
			return
		end
		modalInstance:update(dt)
		return
	end

	-- Handle threaded download completion
	if downloadInProgress and downloadThread then
		-- Check for errors from the thread
		local error = otaUpdate.getDownloadError()
		if error then
			-- Download failed
			downloadInProgress = false
			downloadThread = nil
			modalInstance:show("Download failed:\n" .. error, {
				{
					text = "Close",
					onSelect = function()
						modalInstance:hide()
					end,
				},
			})
		else
			-- Check if download is complete
			local result = otaUpdate.getDownloadResult()
			if result then
				downloadInProgress = false
				downloadThread = nil

				if result.success then
					local fileSize = result.fileSize and string.format(" (%.1f MB)", result.fileSize / 1024 / 1024)
						or ""
					modalInstance:show(
						"Download complete!" .. fileSize .. "\n\nInstall the archive from muOS Apps > Archive Manager.",
						{
							{
								text = "Close",
								onSelect = function()
									modalInstance:hide()
								end,
							},
						}
					)
				else
					modalInstance:show("Download failed:\nUnknown error occurred", {
						{
							text = "Close",
							onSelect = function()
								modalInstance:hide()
							end,
						},
					})
				end
			-- Check if thread is no longer running (could be an error)
			elseif not downloadThread:isRunning() then
				downloadInProgress = false
				local threadError = downloadThread:getError()
				downloadThread = nil

				local errorMsg = threadError and ("Thread error: " .. threadError)
					or "Download failed for unknown reason"
				modalInstance:show("Download failed:\n" .. errorMsg, {
					{
						text = "Close",
						onSelect = function()
							modalInstance:hide()
						end,
					},
				})
			end
		end
	end

	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, input)
		menuList:update(dt)
	end
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

-- Handle entry to this screen
function settings.onEnter(params)
	-- Initialize input handler

	-- Create modal
	modalInstance = Modal:new({
		font = fonts.loaded.body,
	})

	-- Create menu list
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - 60,
		items = createMenuButtons(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		wrap = false,
	})

	-- Reset modal state
	if modalInstance then
		modalInstance:hide()
	end

	-- Check if returning from virtual keyboard with a preset name
	if params and params.inputValue and params.inputValue ~= "" then
		presetName = params.inputValue

		-- Save the preset
		local success = presets.savePreset(presetName)

		if success then
			-- Show success modal
			modalInstance:show("Theme preset saved successfully!", {
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

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

-- Handle cleanup when leaving this screen
function settings.onExit()
	-- Reset modal state
	if modalInstance then
		modalInstance:hide()
	end

	-- Reset OTA update state
	updateCheckInProgress = false
	downloadInProgress = false
	updateInfo = nil
	updateCheckScheduled = false
	updateCheckTimer = 0

	-- Clean up download thread if still running
	if downloadThread then
		downloadThread = nil
	end
end

return settings
