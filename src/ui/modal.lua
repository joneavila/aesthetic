--- Modal UI module
--- This file contains code for drawing modal dialogs throughout the application
local love = require("love")
local colors = require("colors")
local scrollable = require("ui.scrollable")

-- Module table to export public functions
local modal = {}

-- Modal state variables
local showModal = false
local modalMessage = ""
local modalButtons = {}
local isProcessModal = false -- Flag for process modals that should be dismissed manually
local isScrollableModal = false -- Flag for scrollable modals
local scrollPosition = 0 -- Current scroll position for scrollable modals
local customFont = nil -- Custom font for the modal

-- Modal drawing function
function modal.drawModal(screenWidth, screenHeight, font)
	-- Apply background dimming when the modal is shown
	love.graphics.setColor(
		colors.ui.background[1],
		colors.ui.background[2],
		colors.ui.background[3],
		showModal and 0.9 or 0
	)
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
		modalHeight = math.max(minHeight, textHeight + (padding * 2) + buttonsExtraHeight) -- Ensure minimum height
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

	-- Only draw the modal content if it is visible
	if showModal then
		-- Draw modal background
		love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1)
		love.graphics.rectangle("fill", x, y, modalWidth, modalHeight, 10)

		-- Draw modal border
		love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 1)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", x, y, modalWidth, modalHeight, 10)

		-- Draw message with wrapping, handling scrolling if needed
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)

		if isScrollableModal then
			-- Use the scrollable component to draw scrollable content
			local drawContent = function()
				love.graphics.printf(modalMessage, x + padding, y + padding, availableTextWidth, "left")
			end

			local metrics = scrollable.drawContent({
				x = x + padding,
				y = y + padding,
				width = availableTextWidth,
				height = visibleHeight,
				scrollPosition = scrollPosition,
				contentSize = contentHeight,
				drawContent = drawContent,
				opacity = 1,
			})

			-- Calculate max scroll position from metrics
			local maxScroll = metrics.maxScrollPosition
			if scrollPosition > maxScroll then
				scrollPosition = maxScroll
			end
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
					love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 1)
				else
					love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1)
				end
				love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

				-- Draw button outline
				love.graphics.setLineWidth(isSelected and 4 or 2)
				love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 1)
				love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5)

				-- Draw button text
				love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
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
end

-- Show modal with message and buttons
function modal.showModal(message, buttons)
	showModal = true
	modalMessage = message
	modalButtons = buttons or {}
	isProcessModal = false
	isScrollableModal = false
	customFont = nil
	scrollPosition = 0
end

-- Show a scrollable modal with custom font
function modal.showScrollableModal(message, buttons, font)
	showModal = true
	modalMessage = message
	modalButtons = buttons or {}
	isProcessModal = false
	isScrollableModal = true
	customFont = font
	scrollPosition = 0
end

-- Show a process modal that remains visible until manually dismissed
function modal.showProcessModal(message)
	showModal = true
	modalMessage = message
	modalButtons = {}
	isProcessModal = true
	isScrollableModal = false
	customFont = nil
	scrollPosition = 0
end

-- Replace current modal with a new one
function modal.replaceModal(message, buttons)
	-- Directly update the modal content
	modalMessage = message
	modalButtons = buttons or {}
	isProcessModal = false
	isScrollableModal = false
	customFont = nil
	scrollPosition = 0
	-- If modal was not shown, it will be shown by drawModal in the next frame
	showModal = true
end

-- Replace with a process modal
function modal.replaceWithProcessModal(message)
	-- Directly update the modal content
	modalMessage = message
	modalButtons = {}
	isProcessModal = true
	isScrollableModal = false
	customFont = nil
	scrollPosition = 0
	-- If modal was not shown, it will be shown by drawModal in the next frame
	showModal = true
end

-- Scroll the modal content
function modal.scroll(amount)
	if isScrollableModal then
		scrollPosition = scrollable.handleInput({
			scrollPosition = scrollPosition,
			contentSize = getModalContentHeight(),
			viewportSize = getModalViewportHeight(),
			scrollStep = amount,
			input = { up = amount < 0, down = amount > 0 },
		})
	end
end

-- Helper function to get current modal content height
function getModalContentHeight()
	if not isScrollableModal then
		return 0
	end

	local font = customFont or love.graphics.getFont()
	local lineHeight = font:getHeight()
	local screenWidth = love.graphics.getWidth()
	local availableTextWidth = screenWidth * 0.8 - 80 -- Approximate width
	local _, lines = font:getWrap(modalMessage, availableTextWidth)

	return #lines * lineHeight
end

-- Helper function to get current modal viewport height
function getModalViewportHeight()
	if not isScrollableModal then
		return 0
	end

	local screenHeight = love.graphics.getHeight()
	local controls = require("controls")
	local controlsHeight = controls.HEIGHT or controls.calculateHeight()
	local padding = 40

	-- Calculate the buttons height
	local buttonHeight = 40
	local buttonSpacing = 20
	local buttonsExtraHeight = 0
	if #modalButtons > 0 then
		buttonsExtraHeight = (#modalButtons * buttonHeight) + ((#modalButtons - 1) * buttonSpacing) + padding
	end

	-- Calculate maximum height and visible height
	local maxAvailableHeight = screenHeight - controlsHeight - 20
	local idealVisibleHeight = math.min(screenHeight * 0.6, getModalContentHeight())
	local modalHeight = idealVisibleHeight + (padding * 2) + buttonsExtraHeight

	if modalHeight > maxAvailableHeight then
		modalHeight = maxAvailableHeight
		idealVisibleHeight = modalHeight - (padding * 2) - buttonsExtraHeight
	end

	return idealVisibleHeight
end

-- Hide modal
function modal.hideModal()
	showModal = false -- Hide instantly
end

-- Force hide modal immediately (no animation)
function modal.forceHideModal()
	showModal = false
	isProcessModal = false
	isScrollableModal = false
	customFont = nil
	scrollPosition = 0
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

return modal
