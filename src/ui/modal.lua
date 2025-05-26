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
local scrollPosition = 0 -- Current scroll position for scrollable modals

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
	local currentFont = font
	love.graphics.setFont(currentFont)

	-- Calculate available height for text
	local maxTextHeight = screenHeight * 0.6

	-- Calculate estimated text height for initial layout
	local estimatedTextWidth = math.min(screenWidth * 0.8, maxWidth) - (padding * 2)
	local _, estimatedLines = currentFont:getWrap(modalMessage, estimatedTextWidth)
	local estimatedTextHeight = #estimatedLines * currentFont:getHeight()

	local isScrollable = estimatedTextHeight > maxTextHeight

	local minWidth = math.min(screenWidth * 0.8, maxWidth)

	if #modalButtons == 0 and not isScrollable then
		minWidth = math.min(currentFont:getWidth(modalMessage) + (padding * 2), maxWidth)
	end

	-- Calculate available width and heights
	local availableTextWidth = minWidth - (padding * 2)
	local _, lines = currentFont:getWrap(modalMessage, availableTextWidth)
	local lineHeight = currentFont:getHeight()
	local textHeight = #lines * lineHeight -- Actual height if not wrapped

	local contentHeight = textHeight -- Total height of the text content
	local visibleHeight = math.min(screenHeight * 0.6, contentHeight) -- Max height for the text area

	isScrollable = contentHeight > visibleHeight

	-- Calculate final modal dimensions
	local modalWidth = minWidth
	local buttonHeight = 40
	local buttonSpacing = 20

	-- Calculate extra height needed for buttons (always vertical)
	local buttonsExtraHeight = 0
	if #modalButtons > 0 then
		buttonsExtraHeight = (#modalButtons * buttonHeight) + ((#modalButtons - 1) * buttonSpacing) + padding
	end

	-- Calculate final modal height
	local modalHeight = visibleHeight + (padding * 2) + buttonsExtraHeight

	-- Calculate maximum available height to avoid overlapping controls area
	local maxAvailableHeight = screenHeight - controlsHeight - 20 -- 20px extra padding

	-- Limit modalHeight to ensure it doesn't overlap the controls area
	if modalHeight > maxAvailableHeight then
		modalHeight = maxAvailableHeight

		-- Also adjust visibleHeight for scrollable modals
		visibleHeight = modalHeight - (padding * 2) - buttonsExtraHeight
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

		if isScrollable then
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

			if isScrollable then
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
	scrollPosition = 0
end

-- Scroll the modal content
function modal.scroll(amount)
	-- Determine scrollability dynamically
	local screenHeight = love.graphics.getHeight()
	local controls = require("controls")
	local controlsHeight = controls.HEIGHT or controls.calculateHeight()
	local padding = 40
	local buttonHeight = 40
	local buttonSpacing = 20
	local buttonsExtraHeight = 0
	if #modalButtons > 0 then
		buttonsExtraHeight = (#modalButtons * buttonHeight) + ((#modalButtons - 1) * buttonSpacing) + padding
	end

	local maxAvailableHeight = screenHeight - controlsHeight - 20

	local currentFont = love.graphics.getFont()
	local availableTextWidth = (love.graphics.getWidth() * 0.8) - (padding * 2) -- Approximate width
	local _, lines = currentFont:getWrap(modalMessage, availableTextWidth)
	local contentHeight = #lines * currentFont:getHeight()
	local visibleHeight = math.min(screenHeight * 0.6, contentHeight)

	local modalHeight = visibleHeight + (padding * 2) + buttonsExtraHeight

	if modalHeight > maxAvailableHeight then
		modalHeight = maxAvailableHeight
		visibleHeight = modalHeight - (padding * 2) - buttonsExtraHeight
	end

	local isScrollable = contentHeight > visibleHeight

	if isScrollable then
		scrollPosition = scrollable.handleInput({
			scrollPosition = scrollPosition,
			contentSize = contentHeight,
			viewportSize = visibleHeight,
			scrollStep = amount,
			input = { up = amount < 0, down = amount > 0 },
		})
	end
end

-- Hide modal
function modal.hideModal()
	showModal = false -- Hide instantly
end

-- Force hide modal immediately (no animation)
function modal.forceHideModal()
	showModal = false
	scrollPosition = 0
end

-- Check if modal is visible
function modal.isModalVisible()
	return showModal
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
