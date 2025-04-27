--- Modal UI module
--- This file contains code for drawing modal dialogs throughout the application
local love = require("love")
local colors = require("colors")
local state = require("state")

-- Module table to export public functions
local modal = {}

-- Modal state variables
local showModal = false
local modalMessage = ""
local modalButtons = {}
local modalOpacity = 0 -- For fade animation
local targetOpacity = 1 -- Target opacity for animation
local isFadingOut = false -- Track if modal is currently fading out
local nextModalInfo = nil -- Store next modal info for transitions
local backgroundOpacity = 0 -- Separate opacity for background dimming
local isProcessModal = false -- Flag for process modals that should be dismissed manually

-- Modal drawing function
function modal.drawModal()
	-- Apply current opacity to the background with separate opacity control
	-- This ensures background stays dimmed during modal transitions
	local targetBgOpacity = showModal and 0.9 or 0
	backgroundOpacity = showModal and 0.9 or backgroundOpacity

	-- If we have a next modal queued, don't fade out background
	if nextModalInfo then
		backgroundOpacity = 0.9
	end

	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], backgroundOpacity)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)

	-- Calculate modal dimensions based on text
	local padding = 40
	local maxWidth = state.screenWidth * 0.9 -- Maximum width is 90% of screen width

	-- Set font for text measurement
	love.graphics.setFont(state.fonts.body)

	-- For process modals without buttons, use a smaller layout
	local minWidth, minHeight
	if isProcessModal or (#modalButtons == 0) then
		-- Calculate text dimensions more precisely for modals without buttons
		local availTextWidth = maxWidth - (padding * 2)
		local _, lines = state.fonts.body:getWrap(modalMessage, availTextWidth)
		local textHeight = #lines * state.fonts.body:getHeight()

		-- Use fixed padding but adapt to text size
		minWidth = math.min(state.fonts.body:getWidth(modalMessage) + (padding * 2), maxWidth)
		minHeight = textHeight + (padding * 2)
	else
		-- Standard modal with buttons
		minWidth = math.min(state.screenWidth * 0.8, maxWidth)
		minHeight = state.screenHeight * 0.3
	end

	-- Calculate available width for text
	local availableTextWidth = minWidth - (padding * 2)

	-- Get wrapped text info for correct line calculation
	local _, lines = state.fonts.body:getWrap(modalMessage, availableTextWidth)
	local textHeight = #lines * state.fonts.body:getHeight()

	-- Calculate final modal dimensions
	local modalWidth = minWidth
	local buttonHeight = 40
	local buttonSpacing = 20

	-- Calculate extra height needed for buttons (always vertical)
	local buttonsExtraHeight = 0
	if #modalButtons > 0 then
		buttonsExtraHeight = (#modalButtons * buttonHeight) + ((#modalButtons - 1) * buttonSpacing) + padding
	end

	local modalHeight = math.max(minHeight, textHeight + (padding * 2) + buttonsExtraHeight)

	local x = (state.screenWidth - modalWidth) / 2
	local y = (state.screenHeight - modalHeight) / 2

	-- Draw modal background with current opacity
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], modalOpacity)
	love.graphics.rectangle("fill", x, y, modalWidth, modalHeight, 10)

	-- Draw modal border with current opacity
	love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], modalOpacity)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, modalWidth, modalHeight, 10)

	-- Draw message with wrapping
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], modalOpacity)
	local textY = y + padding
	love.graphics.printf(modalMessage, x + padding, textY, availableTextWidth, "center")

	-- Only draw buttons if there are any
	if #modalButtons > 0 then
		-- Draw buttons (always vertically stacked)
		local buttonWidth = 300
		local buttonX = (state.screenWidth - buttonWidth) / 2
		local startButtonY = y + padding + textHeight + padding

		for i, button in ipairs(modalButtons) do
			local buttonY = startButtonY + ((i - 1) * (buttonHeight + buttonSpacing))
			local isSelected = button.selected

			-- Draw button background
			if isSelected then
				love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], modalOpacity)
			else
				love.graphics.setColor(
					colors.ui.background[1],
					colors.ui.background[2],
					colors.ui.background[3],
					modalOpacity
				)
			end
			love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

			-- Draw button outline
			love.graphics.setLineWidth(isSelected and 4 or 2)
			love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], modalOpacity)
			love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5)

			-- Draw button text
			love.graphics.setColor(
				colors.ui.foreground[1],
				colors.ui.foreground[2],
				colors.ui.foreground[3],
				modalOpacity
			)
			love.graphics.printf(
				button.text,
				buttonX,
				buttonY + (buttonHeight - state.fonts.body:getHeight()) / 2,
				buttonWidth,
				"center"
			)
		end
	end
end

-- Update function for animations
function modal.update(dt)
	-- Update background opacity smoothly in both directions
	local targetBgOpacity = (showModal or nextModalInfo) and 0.9 or 0
	if backgroundOpacity < targetBgOpacity then
		backgroundOpacity = math.min(backgroundOpacity + dt * 5, targetBgOpacity)
	elseif backgroundOpacity > targetBgOpacity then
		backgroundOpacity = math.max(backgroundOpacity - dt * 5, targetBgOpacity)
	end

	if showModal then
		-- Handle fade in
		if modalOpacity < targetOpacity and not isFadingOut then
			modalOpacity = math.min(modalOpacity + dt * 5, targetOpacity) -- Faster fade in: 5 units per second
		end

		-- Handle fade out and cleanup when fully transparent
		if isFadingOut then
			modalOpacity = math.max(modalOpacity - dt * 5, 0) -- Faster fade out: 5 units per second
			if modalOpacity <= 0 then
				-- If we have a next modal queued, show it
				if nextModalInfo then
					-- Apply the next modal info
					modalMessage = nextModalInfo.message
					modalButtons = nextModalInfo.buttons or {}
					isProcessModal = nextModalInfo.isProcessModal or false

					-- Reset fade settings
					modalOpacity = 0
					targetOpacity = 1
					isFadingOut = false

					-- Clear next modal info to prevent loops
					nextModalInfo = nil
				else
					-- Just hide this modal
					showModal = false
					isProcessModal = false
					isFadingOut = false
				end
			end
		end
	else
		-- Reset opacity when modal is hidden
		modalOpacity = 0
		targetOpacity = 1
		isFadingOut = false

		-- Only fade out background if no modals are queued
		if not nextModalInfo then
			backgroundOpacity = math.max(backgroundOpacity - dt * 5, 0)
		end
	end
end

-- Show modal with message and buttons
function modal.showModal(message, buttons)
	-- If a modal is already showing and fading out, queue this modal to show after it's gone
	if showModal and isFadingOut then
		nextModalInfo = {
			message = message,
			buttons = buttons or {},
			isProcessModal = false,
		}
		return
	end

	-- Otherwise, show the modal immediately
	showModal = true
	modalMessage = message
	modalButtons = buttons or {}
	modalOpacity = 0 -- Start fully transparent
	targetOpacity = 1 -- Target fully opaque
	isProcessModal = false
	isFadingOut = false
end

-- Show a process modal that remains visible until manually dismissed
function modal.showProcessModal(message)
	-- If a modal is already showing and fading out, queue this modal to show after it's gone
	if showModal and isFadingOut then
		nextModalInfo = {
			message = message,
			buttons = {},
			isProcessModal = true,
		}
		return
	end

	-- Otherwise, show the modal immediately
	showModal = true
	modalMessage = message
	modalButtons = {}
	modalOpacity = 0 -- Start fully transparent
	targetOpacity = 1 -- Target fully opaque
	isProcessModal = true
	isFadingOut = false
end

-- Smoothly replace current modal with a new one
function modal.replaceModal(message, buttons)
	-- Start fade out of current modal
	if showModal then
		isFadingOut = true
		targetOpacity = 0

		-- Queue the next modal
		nextModalInfo = {
			message = message,
			buttons = buttons or {},
			isProcessModal = false,
		}
	else
		-- No current modal, show immediately
		modal.showModal(message, buttons)
	end
end

-- Replace with a process modal
function modal.replaceWithProcessModal(message)
	-- Start fade out of current modal
	if showModal then
		isFadingOut = true
		targetOpacity = 0

		-- Queue the next modal
		nextModalInfo = {
			message = message,
			buttons = {},
			isProcessModal = true,
		}
	else
		-- No current modal, show immediately
		modal.showProcessModal(message)
	end
end

-- Hide modal
function modal.hideModal()
	-- Start fade out
	if showModal then
		isFadingOut = true
		targetOpacity = 0
	end
end

-- Force hide modal immediately (no animation)
function modal.forceHideModal()
	showModal = false
	modalOpacity = 0
	targetOpacity = 1
	isProcessModal = false
	isFadingOut = false
	nextModalInfo = nil
end

-- Check if modal is visible
function modal.isModalVisible()
	return showModal
end

-- Check if the currently visible modal is a process modal
function modal.isProcessModal()
	return isProcessModal
end

-- Get modal message
function modal.getModalMessage()
	return modalMessage
end

-- Get modal buttons
function modal.getModalButtons()
	return modalButtons
end

-- Set modal buttons
function modal.setModalButtons(buttons)
	modalButtons = buttons or {}
end

-- Update message of current modal
function modal.updateMessage(message)
	modalMessage = message
end

-- Check if the current modal has fully faded in
function modal.isFullyFadedIn()
	return showModal and not isFadingOut and modalOpacity >= targetOpacity
end

return modal
