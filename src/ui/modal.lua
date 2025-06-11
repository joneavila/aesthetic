--- Modal UI module
--- This file contains code for drawing modal dialogs throughout the application
local love = require("love")
local colors = require("colors")
local Component = require("ui.component").Component
local scrollable = require("ui.scrollable")
local InputManager = require("ui.InputManager")

local Modal = setmetatable({}, { __index = Component })
Modal.__index = Modal

function Modal:new(config)
	local instance = Component.new(self, config or {})
	instance.visible = false
	instance.message = ""
	instance.progressMessage = ""
	instance.progressHistory = {} -- Store multiple progress messages
	instance.buttons = {}
	instance.selectedIndex = 1
	instance.scrollPosition = 0
	instance.font = config and config.font or love.graphics.getFont()
	instance.onButtonPress = config and config.onButtonPress or nil

	-- Animation properties
	instance.animationTime = 0
	instance.showAnimation = false
	instance.isProgressModal = false

	-- Fixed modal dimensions for consistency
	instance.useFixedWidth = false
	instance.fixedWidth = 0

	return instance
end

function Modal:show(message, buttons, options)
	self.visible = true
	self.message = message or ""
	self.buttons = buttons or {}
	self.selectedIndex = 1
	self.scrollPosition = 0
	options = options or {}

	-- Check if this is a progress modal (no buttons and contains progress keywords)
	-- Can be overridden with options.forceSimple = true
	self.isProgressModal = (#self.buttons == 0)
		and not options.forceSimple
		and (
			string.find(self.message:lower(), "creating")
			or string.find(self.message:lower(), "applying")
			or string.find(self.message:lower(), "installing")
			or string.find(self.message:lower(), "loading")
			or string.find(self.message:lower(), "preparing")
			or string.find(self.message:lower(), "download")
			or string.find(self.message:lower(), "connecting")
		)

	-- If this is not a progress modal, reset progress message and history
	if not self.isProgressModal then
		self.progressMessage = ""
		self.progressHistory = {}
	else
		-- Clear history when starting a new progress modal
		self.progressHistory = {}
	end

	-- Enable animation for progress modals
	self.showAnimation = self.isProgressModal

	if self.showAnimation then
		self.animationTime = 0
	end
end

function Modal:updateProgress(progressText, _percent)
	if self.isProgressModal and progressText then
		self.progressMessage = progressText

		-- Add to history and maintain maximum of 4 lines
		table.insert(self.progressHistory, progressText)
		if #self.progressHistory > 4 then
			table.remove(self.progressHistory, 1) -- Remove oldest message
		end
	elseif progressText then
		-- Force progress modal mode if it wasn't detected
		self.isProgressModal = true
		self.showAnimation = true
		self.progressMessage = progressText
		table.insert(self.progressHistory, progressText)
	end
end

-- Function to set fixed width (height will be auto-calculated)
function Modal:setFixedWidth(width)
	self.useFixedWidth = true
	self.fixedWidth = width
end

function Modal:hide()
	self.visible = false
	self.showAnimation = false
	self.animationTime = 0
	self.progressMessage = ""
	self.progressHistory = {}
	self.isProgressModal = false
	-- Reset fixed width when hiding the modal
	self.useFixedWidth = false
	self.fixedWidth = 0
end

function Modal:isVisible()
	return self.visible
end

function Modal:getButtons()
	return self.buttons
end

function Modal:getMessage()
	return self.message
end

function Modal:update(dt)
	if self.showAnimation then
		self.animationTime = self.animationTime + dt
	end
end

function Modal:moveFocus(direction)
	if #self.buttons == 0 then
		return
	end
	local oldIndex = self.selectedIndex
	local newIndex = oldIndex + direction
	if newIndex < 1 then
		newIndex = #self.buttons
	elseif newIndex > #self.buttons then
		newIndex = 1
	end
	self.selectedIndex = newIndex
	for i, button in ipairs(self.buttons) do
		button.selected = (i == self.selectedIndex)
	end
end

function Modal:handleInput(input)
	if not self.visible then
		return false
	end

	-- Handle scrolling for modals with long content (regardless of button count)
	local isScrollable = self:isContentScrollable()
	if isScrollable then
		if InputManager.isActionPressed(InputManager.ACTIONS.NAVIGATE_UP) then
			self:scroll(-20) -- Scroll up
			return true
		elseif InputManager.isActionPressed(InputManager.ACTIONS.NAVIGATE_DOWN) then
			self:scroll(20) -- Scroll down
			return true
		end
	end

	-- Handle button navigation only if there are buttons
	if #self.buttons == 0 then
		-- For modals without buttons, still consume input but allow 'b' to close
		if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
			self:hide()
			return true
		end
		return true
	end

	-- Button navigation for modals with buttons
	if InputManager.isActionPressed(InputManager.ACTIONS.NAVIGATE_UP) then
		self:moveFocus(-1)
		return true
	elseif InputManager.isActionPressed(InputManager.ACTIONS.NAVIGATE_DOWN) then
		self:moveFocus(1)
		return true
	elseif InputManager.isActionPressed(InputManager.ACTIONS.CONFIRM) then
		local selectedOption = self.buttons[self.selectedIndex]
		if selectedOption and selectedOption.onSelect then
			selectedOption.onSelect()
		end
		if self.onButtonPress then
			self.onButtonPress(self.selectedIndex, selectedOption)
		end
		return true
	end

	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		self:hide()
		return true
	end

	return false
end

-- Helper method to determine if content is scrollable
function Modal:isContentScrollable()
	local screenHeight = love.graphics.getHeight()
	local maxTextHeight = screenHeight * 0.6

	-- Calculate content height
	local currentFont = self.font or love.graphics.getFont()
	local estimatedTextWidth = math.min(screenHeight * 0.8, screenHeight * 0.9) - 80 -- padding
	local _, mainMessageLines = currentFont:getWrap(self.message, estimatedTextWidth)
	local contentHeight = #mainMessageLines * currentFont:getHeight()

	return contentHeight > maxTextHeight
end

-- Helper method to handle scrolling
function Modal:scroll(amount)
	local screenHeight = love.graphics.getHeight()
	local maxTextHeight = screenHeight * 0.6

	-- Calculate content height
	local currentFont = self.font or love.graphics.getFont()
	local estimatedTextWidth = math.min(screenHeight * 0.8, screenHeight * 0.9) - 80 -- padding
	local _, mainMessageLines = currentFont:getWrap(self.message, estimatedTextWidth)
	local contentHeight = #mainMessageLines * currentFont:getHeight()

	local maxScrollPosition = math.max(0, contentHeight - maxTextHeight)

	self.scrollPosition = self.scrollPosition + amount
	self.scrollPosition = math.max(0, math.min(self.scrollPosition, maxScrollPosition))
end

function Modal:draw(screenWidth, screenHeight, font)
	if not self.visible then
		return
	end
	love.graphics.push("all")
	local controls = require("control_hints").ControlHints
	local fonts = require("ui.fonts")
	local controlsHeight = controls.calculateHeight()
	local padding = 40
	local maxWidth = screenWidth * 0.9
	local currentFont = font or self.font or love.graphics.getFont()
	love.graphics.setFont(currentFont)

	-- Calculate dimensions for main message
	local estimatedTextWidth = math.min(screenWidth * 0.8, maxWidth) - (padding * 2)
	local _, mainMessageLines = currentFont:getWrap(self.message, estimatedTextWidth)
	local mainMessageHeight = #mainMessageLines * currentFont:getHeight()

	-- Calculate progress box dimensions if this is a progress modal
	local progressBoxHeight = 0
	local progressBoxPadding = 12

	if self.isProgressModal then
		-- Use console font for progress messages
		local consoleFont = fonts.loaded.console or currentFont

		-- Calculate height for 4 lines minimum
		local lineHeight = consoleFont:getHeight()
		local minConsoleLines = 4
		local progressMessageHeight = lineHeight * minConsoleLines
		progressBoxHeight = progressMessageHeight + (progressBoxPadding * 2)
	end

	-- Calculate total content height
	local contentHeight = mainMessageHeight
	if self.isProgressModal then
		contentHeight = contentHeight + 20 -- spacing between main message and progress box
		contentHeight = contentHeight + progressBoxHeight
	end

	local maxTextHeight = screenHeight * 0.6
	local isScrollable = contentHeight > maxTextHeight

	-- Use fixed width if available, otherwise calculate dynamically
	local modalWidth, modalHeight
	if self.useFixedWidth and self.fixedWidth > 0 then
		modalWidth = self.fixedWidth
		-- Calculate height based on content and buttons
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = 0
		if #self.buttons > 0 then
			buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
		end
		modalHeight = contentHeight + (padding * 2) + buttonsExtraHeight
		local maxAvailableHeight = screenHeight - controlsHeight - 20
		if modalHeight > maxAvailableHeight then
			modalHeight = maxAvailableHeight
		end
	else
		local minWidth = math.min(screenWidth * 0.8, maxWidth)
		if #self.buttons == 0 and not isScrollable then
			minWidth = math.min(currentFont:getWidth(self.message) + (padding * 2), maxWidth)
		end
		local visibleHeight = math.min(maxTextHeight, contentHeight)
		modalWidth = minWidth
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = 0
		if #self.buttons > 0 then
			buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
		end
		modalHeight = visibleHeight + (padding * 2) + buttonsExtraHeight
		local maxAvailableHeight = screenHeight - controlsHeight - 20
		if modalHeight > maxAvailableHeight then
			modalHeight = maxAvailableHeight
		end
	end

	local availableTextWidth = modalWidth - (padding * 2)
	local visibleHeight = modalHeight - (padding * 2)
	if #self.buttons > 0 then
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
		visibleHeight = visibleHeight - buttonsExtraHeight
	end

	local x = (screenWidth - modalWidth) / 2
	local y = (screenHeight - modalHeight - controlsHeight) / 2

	-- Draw modal background
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.9)
	love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1)
	love.graphics.rectangle("fill", x, y, modalWidth, modalHeight, 10)
	love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, modalWidth, modalHeight, 10)

	-- Draw content
	if isScrollable then
		local drawContent = function()
			love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
			love.graphics.printf(self.message, 0, 0, availableTextWidth, "left")
		end
		local metrics = scrollable.drawContent({
			x = x + padding,
			y = y + padding,
			width = availableTextWidth,
			height = visibleHeight,
			scrollPosition = self.scrollPosition,
			contentSize = contentHeight,
			drawContent = drawContent,
			opacity = 1,
		})
		local maxScroll = metrics.maxScrollPosition
		if self.scrollPosition > maxScroll then
			self.scrollPosition = maxScroll
		end
	else
		local textY = y + padding

		-- Draw the main message
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
		love.graphics.printf(self.message, x + padding, textY, availableTextWidth, "center")

		-- Draw progress section for progress modals
		if self.isProgressModal then
			local progressY = textY + mainMessageHeight + 20
			local consoleFont = fonts.loaded.console or currentFont

			-- Calculate progress box dimensions
			local progressBoxX = x + padding
			local progressBoxWidth = availableTextWidth
			local actualProgressBoxHeight = progressBoxHeight

			-- Darker background for progress box
			love.graphics.setColor(
				colors.ui.background[1] * 0.7,
				colors.ui.background[2] * 0.7,
				colors.ui.background[3] * 0.7,
				1
			)
			love.graphics.rectangle("fill", progressBoxX, progressY, progressBoxWidth, actualProgressBoxHeight, 5)

			-- Draw console-like progress messages using console font
			love.graphics.setFont(consoleFont)
			love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)

			local lineHeight = consoleFont:getHeight()
			local startY = progressY + progressBoxPadding

			-- Draw up to 4 lines from history
			for i, historyMessage in ipairs(self.progressHistory) do
				local messageY = startY + (i - 1) * lineHeight
				love.graphics.print(historyMessage, progressBoxX + progressBoxPadding, messageY)
			end

			-- Reset font to original
			love.graphics.setFont(currentFont)
		end

		-- Reset color for subsequent drawing
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
	end

	if #self.buttons == 0 then
		love.graphics.pop()
		return
	end

	local buttonWidth = 300
	local buttonX = (screenWidth - buttonWidth) / 2
	local startButtonY
	if isScrollable then
		startButtonY = y + padding + visibleHeight + padding
	else
		startButtonY = y + padding + contentHeight + padding
	end
	local buttonHeight = 40
	local buttonSpacing = 20
	for i, button in ipairs(self.buttons) do
		local buttonY = startButtonY + ((i - 1) * (buttonHeight + buttonSpacing))
		local isSelected = (i == self.selectedIndex)
		button.selected = isSelected
		if isSelected then
			love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 1)
		else
			love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1)
		end
		love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5)
		love.graphics.setLineWidth(isSelected and 4 or 2)
		love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 1)
		love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 5)
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
		love.graphics.printf(
			button.text,
			buttonX,
			buttonY + (buttonHeight - currentFont:getHeight()) / 2,
			buttonWidth,
			"center"
		)
	end
	love.graphics.pop()
end

return {
	Modal = Modal,
}
