--- Modal UI module
--- This file contains code for drawing modal dialogs throughout the application
local love = require("love")
local colors = require("colors")

-- Module table to export public functions
local modal = {}

-- Animation durations
modal.FADE_IN_DURATION = 0.4 -- Time to fade in completely (seconds)
modal.FADE_OUT_DURATION = 0.4 -- Time to fade out completely (seconds)
modal.BG_FADE_DURATION = 0.4 -- Background fade duration (seconds)

-- Modal state variables
local showModal = false
local modalMessage = ""
local modalButtons = {}
local modalOpacity = 0 -- For fade animation
local targetOpacity = 1 -- Target opacity for animation
local isFadingOut = false -- Track if modal is currently fading out
local nextModalInfo = nil -- Store next modal info for transitions
local backgroundOpacity = 0 -- Separate opacity for background dimming (elements behind the modal)
local isProcessModal = false -- Flag for process modals that should be dismissed manually
local isScrollableModal = false -- Flag for scrollable modals
local scrollPosition = 0 -- Current scroll position for scrollable modals
local customFont = nil -- Custom font for the modal

-- Modal drawing function
function modal.drawModal(screenWidth, screenHeight, font)
	-- Apply current opacity to the background with separate opacity control
	-- This ensures background stays dimmed during modal transitions
	backgroundOpacity = showModal and 0.9 or backgroundOpacity

	-- If we have a next modal queued, don't fade out background
	if nextModalInfo then
		backgroundOpacity = 0.9
	end

	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], backgroundOpacity)
	love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

	-- Get controls height to avoid overlapping with control hints
	local controls = require("controls")
	local controlsHeight = controls.HEIGHT or controls.calculateHeight()

	-- Calculate modal dimensions based on text
	local padding = 40
	local maxWidth = screenWidth * 0.9 -- Maximum width is 90% of screen width

	-- Set font for text measurement
	local currentFont = customFont or font
	love.graphics.setFont(currentFont)

	-- For process modals without buttons, use a smaller layout
	local minWidth, minHeight
	if isProcessModal or (#modalButtons == 0 and not isScrollableModal) then
		-- Calculate text dimensions more precisely for modals without buttons
		local availTextWidth = maxWidth - (padding * 2)
		local _, lines = currentFont:getWrap(modalMessage, availTextWidth)
		local textHeight = #lines * currentFont:getHeight()

		-- Use fixed padding but adapt to text size
		minWidth = math.min(currentFont:getWidth(modalMessage) + (padding * 2), maxWidth)
		minHeight = textHeight + (padding * 2)
	else
		-- Standard modal with buttons or scrollable content
		minWidth = math.min(screenWidth * 0.8, maxWidth)
		minHeight = screenHeight * 0.3
	end

	-- Calculate available width for text
	local availableTextWidth = minWidth - (padding * 2)

	-- Get wrapped text info for correct line calculation
	local _, lines = currentFont:getWrap(modalMessage, availableTextWidth)
	local lineHeight = currentFont:getHeight()
	local textHeight = #lines * lineHeight

	-- For scrollable modals, limit the display height but allow content to be larger
	local contentHeight = textHeight
	local visibleHeight = math.min(screenHeight * 0.6, textHeight)

	-- Calculate final modal dimensions
	local modalWidth = minWidth
	local buttonHeight = 40
	local buttonSpacing = 20

	-- Calculate extra height needed for buttons (always vertical)
	local buttonsExtraHeight = 0
	if #modalButtons > 0 then
		buttonsExtraHeight = (#modalButtons * buttonHeight) + ((#modalButtons - 1) * buttonSpacing) + padding
	end

	-- For scrollable modals, use the visible height plus button area
	local modalHeight
	if isScrollableModal then
		modalHeight = visibleHeight + (padding * 2) + buttonsExtraHeight
	else
		modalHeight = math.max(minHeight, textHeight + (padding * 2) + buttonsExtraHeight)
	end

	-- Calculate maximum available height to avoid overlapping controls area
	local maxAvailableHeight = screenHeight - controlsHeight - 20 -- 20px extra padding

	-- Limit modalHeight to ensure it doesn't overlap the controls area
	if modalHeight > maxAvailableHeight then
		modalHeight = maxAvailableHeight

		-- Also adjust visibleHeight for scrollable modals
		if isScrollableModal then
			visibleHeight = modalHeight - (padding * 2) - buttonsExtraHeight
		end
	end

	local x = (screenWidth - modalWidth) / 2
	local y = (screenHeight - modalHeight - controlsHeight) / 2 -- Center in available space

	-- Draw modal background with current opacity
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], modalOpacity)
	love.graphics.rectangle("fill", x, y, modalWidth, modalHeight, 10)

	-- Draw modal border with current opacity
	love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], modalOpacity)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, modalWidth, modalHeight, 10)

	-- Draw message with wrapping, handling scrolling if needed
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], modalOpacity)

	if isScrollableModal then
		-- Set scissor to create scrollable area
		love.graphics.push()
		local scissorX = x + padding
		local scissorY = y + padding
		local scissorWidth = availableTextWidth
		local scissorHeight = visibleHeight

		love.graphics.setScissor(scissorX, scissorY, scissorWidth, scissorHeight)

		-- Draw text with scroll offset
		love.graphics.printf(modalMessage, x + padding, y + padding - scrollPosition, availableTextWidth, "left")

		-- Calculate max scroll value (don't allow scrolling past content)
		local maxScroll = math.max(0, contentHeight - visibleHeight)
		if scrollPosition > maxScroll then
			scrollPosition = maxScroll
		end

		-- Draw scroll indicators if content is scrollable
		if contentHeight > visibleHeight then
			-- Show up indicator if not at top
			if scrollPosition > 0 then
				love.graphics.setColor(
					colors.ui.surface[1],
					colors.ui.surface[2],
					colors.ui.surface[3],
					modalOpacity * 0.7
				)
				love.graphics.polygon(
					"fill",
					scissorX + scissorWidth / 2,
					scissorY + 10,
					scissorX + scissorWidth / 2 - 10,
					scissorY + 20,
					scissorX + scissorWidth / 2 + 10,
					scissorY + 20
				)
			end

			-- Show down indicator if not at bottom
			if scrollPosition < maxScroll then
				love.graphics.setColor(
					colors.ui.surface[1],
					colors.ui.surface[2],
					colors.ui.surface[3],
					modalOpacity * 0.7
				)
				love.graphics.polygon(
					"fill",
					scissorX + scissorWidth / 2,
					scissorY + scissorHeight - 10,
					scissorX + scissorWidth / 2 - 10,
					scissorY + scissorHeight - 20,
					scissorX + scissorWidth / 2 + 10,
					scissorY + scissorHeight - 20
				)
			end
		end

		love.graphics.setScissor()
		love.graphics.pop()
	else
		-- Regular non-scrolling text
		local textY = y + padding
		love.graphics.printf(modalMessage, x + padding, textY, availableTextWidth, "center")
	end

	-- Only draw buttons if there are any
	if #modalButtons > 0 then
		-- Draw buttons (always vertically stacked)
		local buttonWidth = 300
		local buttonX = (screenWidth - buttonWidth) / 2
		local startButtonY

		if isScrollableModal then
			startButtonY = y + padding + visibleHeight + padding
		else
			startButtonY = y + padding + textHeight + padding
		end

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
				buttonY + (buttonHeight - currentFont:getHeight()) / 2,
				buttonWidth,
				"center"
			)
		end
	end
end

-- Update function for animations
function modal.update(dt)
	-- Update background opacity smoothly in both directions
	local targetBgOpacity = showModal and 0.9 or 0
	local bgFadeSpeed = 1 / modal.BG_FADE_DURATION

	if backgroundOpacity < targetBgOpacity then
		backgroundOpacity = math.min(backgroundOpacity + dt * bgFadeSpeed, targetBgOpacity)
	elseif backgroundOpacity > targetBgOpacity then
		backgroundOpacity = math.max(backgroundOpacity - dt * bgFadeSpeed, targetBgOpacity)
	end

	if showModal then
		-- Handle fade in
		if modalOpacity < targetOpacity and not isFadingOut then
			local fadeInSpeed = 1 / modal.FADE_IN_DURATION
			modalOpacity = math.min(modalOpacity + dt * fadeInSpeed, targetOpacity) -- Fade in animation
		end

		-- Handle fade out and cleanup when fully transparent
		if isFadingOut then
			local fadeOutSpeed = 1 / modal.FADE_OUT_DURATION
			modalOpacity = math.max(modalOpacity - dt * fadeOutSpeed, 0) -- Fade out animation
			if modalOpacity <= 0 then
				-- Just hide this modal
				showModal = false
				isProcessModal = false
				isScrollableModal = false
				isFadingOut = false
				customFont = nil
				scrollPosition = 0
			end
		end
	else
		-- Reset opacity when modal is hidden
		modalOpacity = 0
		targetOpacity = 1
		isFadingOut = false

		-- Fade out background when modal is hidden
		local bgFadeSpeed = 1 / modal.BG_FADE_DURATION
		backgroundOpacity = math.max(backgroundOpacity - dt * bgFadeSpeed, 0)
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
			isScrollableModal = false,
			customFont = nil,
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
	isScrollableModal = false
	customFont = nil
	scrollPosition = 0
	isFadingOut = false
end

-- Show a scrollable modal with custom font
function modal.showScrollableModal(message, buttons, font)
	-- If a modal is already showing and fading out, queue this modal to show after it's gone
	if showModal and isFadingOut then
		nextModalInfo = {
			message = message,
			buttons = buttons or {},
			isProcessModal = false,
			isScrollableModal = true,
			customFont = font,
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
	isScrollableModal = true
	customFont = font
	scrollPosition = 0
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
			isScrollableModal = false,
			customFont = nil,
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
	isScrollableModal = false
	customFont = nil
	scrollPosition = 0
	isFadingOut = false
end

-- Smoothly replace current modal with a new one
function modal.replaceModal(message, buttons)
	-- If there's a current modal, replace it instantly
	if showModal then
		-- Directly update the modal content without animation
		modalMessage = message
		modalButtons = buttons or {}
		isProcessModal = false
		isScrollableModal = false
		customFont = nil
		scrollPosition = 0

		-- Keep the opacity at full to avoid flicker
		modalOpacity = targetOpacity
		isFadingOut = false

		-- Clear any queued modals
		nextModalInfo = nil
	else
		-- No current modal, show with normal fade in
		modal.showModal(message, buttons)
	end
end

-- Replace with a process modal
function modal.replaceWithProcessModal(message)
	-- If there's a current modal, replace it instantly
	if showModal then
		-- Directly update the modal content without animation
		modalMessage = message
		modalButtons = {}
		isProcessModal = true
		isScrollableModal = false
		customFont = nil
		scrollPosition = 0

		-- Keep the opacity at full to avoid flicker
		modalOpacity = targetOpacity
		isFadingOut = false

		-- Clear any queued modals
		nextModalInfo = nil
	else
		-- No current modal, show with normal fade in
		modal.showProcessModal(message)
	end
end

-- Scroll the modal content
function modal.scroll(amount)
	if isScrollableModal then
		scrollPosition = math.max(0, scrollPosition + amount)

		-- Get current font
		local font = customFont or love.graphics.getFont()

		-- Get controls height to calculate available space
		local controls = require("controls")
		local controlsHeight = controls.HEIGHT or controls.calculateHeight()

		-- Get screen dimensions
		local screenWidth = love.graphics.getWidth()
		local screenHeight = love.graphics.getHeight()

		-- Calculate text content height
		local lineHeight = font:getHeight()
		local availableTextWidth = screenWidth * 0.8 - 80 -- Approximate width (modal width - padding)
		local _, lines = font:getWrap(modalMessage, availableTextWidth)
		local contentHeight = #lines * lineHeight

		-- Calculate max modal height available (accounting for controls)
		local maxAvailableHeight = screenHeight - controlsHeight - 20 -- 20px extra padding

		-- Calculate visible height for text (accounting for padding and buttons)
		local padding = 40
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = 0
		if #modalButtons > 0 then
			buttonsExtraHeight = (#modalButtons * buttonHeight) + ((#modalButtons - 1) * buttonSpacing) + padding
		end

		-- First calculate the ideal visible height
		local idealVisibleHeight = math.min(screenHeight * 0.6, contentHeight)

		-- Then constrain it by available space
		local modalHeight = idealVisibleHeight + (padding * 2) + buttonsExtraHeight
		if modalHeight > maxAvailableHeight then
			modalHeight = maxAvailableHeight
			-- Recalculate visible height after constraint
			idealVisibleHeight = modalHeight - (padding * 2) - buttonsExtraHeight
		end

		local visibleHeight = idealVisibleHeight

		-- Don't allow scrolling past the end
		local maxScroll = math.max(0, contentHeight - visibleHeight)
		if scrollPosition > maxScroll then
			scrollPosition = maxScroll
		end
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
	isScrollableModal = false
	customFont = nil
	scrollPosition = 0
	isFadingOut = false
end

-- Check if modal is visible
function modal.isModalVisible()
	return showModal
end

-- Check if the currently visible modal is a process modal
function modal.isProcessModal()
	return isProcessModal
end

-- Check if the currently visible modal is scrollable
function modal.isScrollableModal()
	return isScrollableModal
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
