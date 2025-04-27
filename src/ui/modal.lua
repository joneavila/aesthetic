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

-- Modal drawing function
function modal.drawModal()
	-- Draw semi-transparent background
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.9)
	love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)

	-- Calculate modal dimensions based on text
	local padding = 40
	local maxWidth = state.screenWidth * 0.9 -- Maximum width is 90% of screen width
	-- Minimum width is 80% of screen width, but not more than maxWidth
	local minWidth = math.min(state.screenWidth * 0.8, maxWidth)
	local minHeight = state.screenHeight * 0.3

	-- Set font for text measurement
	love.graphics.setFont(state.fonts.body)

	-- Calculate available width for text
	local availableTextWidth = minWidth - (padding * 2)

	-- Get wrapped text info
	local _, lines = state.fonts.body:getWrap(modalMessage, availableTextWidth)
	local textHeight = #lines * state.fonts.body:getHeight()

	-- Calculate final modal dimensions
	local modalWidth = minWidth -- Always use the minimum width to ensure consistent wrapping
	local buttonHeight = 40
	local buttonSpacing = 20

	-- Calculate extra height needed for buttons (always vertical)
	local buttonsExtraHeight = (#modalButtons * buttonHeight) + ((#modalButtons - 1) * buttonSpacing) + padding
	local modalHeight = math.max(minHeight, textHeight + (padding * 2) + buttonsExtraHeight)

	local x = (state.screenWidth - modalWidth) / 2
	local y = (state.screenHeight - modalHeight) / 2

	-- Draw modal background
	love.graphics.setColor(colors.ui.background)
	love.graphics.rectangle("fill", x, y, modalWidth, modalHeight, 10)

	-- Draw modal border
	love.graphics.setColor(colors.ui.surface)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, modalWidth, modalHeight, 10)

	-- Draw message with wrapping
	love.graphics.setColor(colors.ui.foreground)
	local textY = y + padding
	love.graphics.printf(modalMessage, x + padding, textY, availableTextWidth, "center")

	-- Draw buttons (always vertically stacked)
	local buttonWidth = 300
	local buttonX = (state.screenWidth - buttonWidth) / 2
	local startButtonY = y + padding + textHeight + padding

	for i, button in ipairs(modalButtons) do
		local buttonY = startButtonY + ((i - 1) * (buttonHeight + buttonSpacing))
		local isSelected = button.selected

		-- Draw button background
		love.graphics.setColor(isSelected and colors.ui.surface or colors.ui.background)
		love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)

		-- Draw button outline
		love.graphics.setLineWidth(isSelected and 4 or 2)
		love.graphics.setColor(colors.ui.surface)
		love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5)

		-- Draw button text
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.printf(
			button.text,
			buttonX,
			buttonY + (buttonHeight - state.fonts.body:getHeight()) / 2,
			buttonWidth,
			"center"
		)
	end
end

-- Show modal with message
function modal.showModal(message, buttons)
	showModal = true
	modalMessage = message
	modalButtons = buttons
end

-- Hide modal
function modal.hideModal()
	showModal = false
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
	modalButtons = buttons
end

return modal
