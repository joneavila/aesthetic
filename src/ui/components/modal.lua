--- Modal UI module
--- This file contains code for drawing modal dialogs throughout the application
local love = require("love")
local colors = require("colors")
local Component = require("ui.component").Component
local InputManager = require("ui.controllers.input_manager")
local constants = require("ui.components.constants")
local Button = require("ui.components.button").Button

local Modal = setmetatable({}, { __index = Component })
Modal.__index = Modal

-- Configurable button horizontal padding (space between modal edge and button)
local BUTTON_HORIZONTAL_PADDING = 32

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

	self.message = message and message:match("^%s*(.-)%s*$") or ""

	self.buttons = buttons or {}

	-- Set focus to Exit button by default if present
	self.selectedIndex = 1
	if self.buttons and #self.buttons > 0 then
		for i, btn in ipairs(self.buttons) do
			if btn.text and tostring(btn.text):lower() == "exit" then
				self.selectedIndex = i
				break
			end
		end
		for i, btn in ipairs(self.buttons) do
			btn.selected = (i == self.selectedIndex)
		end
	end

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
	local isScrollable, maxScrollPosition = self:isContentScrollable()
	if isScrollable then
		if InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_UP) then
			self:scroll(-20, maxScrollPosition) -- Scroll up
			return true
		elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_DOWN) then
			self:scroll(20, maxScrollPosition) -- Scroll down
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

-- Helper method to determine if content is scrollable and max scroll position
function Modal:isContentScrollable(visibleHeight)
	local currentFont = self.font or love.graphics.getFont()
	local estimatedTextWidth = self._lastTextWidth or 0
	local _, mainMessageLines = currentFont:getWrap(self.message, estimatedTextWidth)
	local contentHeight = #mainMessageLines * currentFont:getHeight()
	visibleHeight = visibleHeight or 0
	-- Correct maxScrollPosition so the last line is flush with the bottom
	local maxScrollPosition = math.max(0, contentHeight - visibleHeight)
	return contentHeight > visibleHeight, maxScrollPosition, contentHeight
end

-- Helper method to handle scrolling
function Modal:scroll(amount, maxScrollPosition)
	self.scrollPosition = self.scrollPosition + amount
	self.scrollPosition = math.max(0, math.min(self.scrollPosition, maxScrollPosition or 0))
end

-- Draw custom scrollbar for scrollable content
function Modal:drawScrollbar(x, y, height, contentHeight, scrollPosition, maxScrollPosition, opacity)
	local barWidth = constants.SCROLLBAR.WIDTH
	local handleMinHeight = constants.SCROLLBAR.HANDLE_MIN_HEIGHT
	local cornerRadius = constants.SCROLLBAR.CORNER_RADIUS
	local handleColor = constants.SCROLLBAR.HANDLE_COLOR
	local backgroundColor = constants.SCROLLBAR.BACKGROUND_COLOR

	-- Draw scrollbar track
	love.graphics.setColor(
		backgroundColor[1],
		backgroundColor[2],
		backgroundColor[3],
		backgroundColor[4] * (opacity or 1)
	)
	love.graphics.rectangle("fill", x, y, barWidth, height, cornerRadius)

	-- Calculate handle size and position
	local handleHeight = math.max((height / contentHeight) * height, handleMinHeight)
	local maxHandleTravel = height - handleHeight
	local handleY = y
	if maxScrollPosition > 0 then
		handleY = y + math.min((scrollPosition / maxScrollPosition) * maxHandleTravel, maxHandleTravel)
	end

	-- Clamp handleY to not exceed the track
	if handleY < y then
		handleY = y
	end
	if handleY + handleHeight > y + height then
		handleY = y + height - handleHeight
	end

	-- Draw handle
	love.graphics.setColor(handleColor[1], handleColor[2], handleColor[3], (handleColor[4] or 1) * (opacity or 1))
	love.graphics.rectangle("fill", x, handleY, barWidth, handleHeight, cornerRadius)
end

function Modal:draw(screenWidth, screenHeight, font)
	if not self.visible then
		return
	end

	local controls = require("control_hints").ControlHints
	local fonts = require("ui.fonts")
	local controlsHeight = controls.calculateHeight()
	local padding = 40
	local maxWidth = screenWidth * 0.9
	local scrollbarWidth = constants.SCROLLBAR.WIDTH
	local scrollbarGap = 4

	-- Use error font for error/failure messages
	local useErrorFont = false
	if self.message and type(self.message) == "string" then
		local msg = self.message:lower()
		if msg:find("error") or msg:find("failed") then
			useErrorFont = true
		end
	end
	local currentFont = font or self.font or love.graphics.getFont()
	if useErrorFont and fonts.loaded.error then
		currentFont = fonts.loaded.error
	end

	love.graphics.push("all")
	love.graphics.setFont(currentFont)

	-- Calculate dimensions for main message
	local estimatedTextWidth = math.min(screenWidth * 0.8, maxWidth) - (padding * 2)
	self._lastTextWidth = estimatedTextWidth - scrollbarWidth - scrollbarGap
	local _, mainMessageLines = currentFont:getWrap(self.message, self._lastTextWidth)
	local mainMessageHeight = #mainMessageLines * currentFont:getHeight()

	-- Calculate progress box dimensions if this is a progress modal
	local progressBoxHeight = 0
	local progressBoxPadding = 12

	if self.isProgressModal then
		local consoleFont = fonts.loaded.console or currentFont
		local lineHeight = consoleFont:getHeight()
		local minConsoleLines = 4
		local progressMessageHeight = lineHeight * minConsoleLines
		progressBoxHeight = progressMessageHeight + (progressBoxPadding * 2)
	end

	local contentHeight = mainMessageHeight
	if self.isProgressModal then
		contentHeight = contentHeight + 20
		contentHeight = contentHeight + progressBoxHeight
	end

	local maxTextHeight = screenHeight * 0.6
	local modalWidth, modalHeight
	if self.useFixedWidth and self.fixedWidth > 0 then
		modalWidth = self.fixedWidth
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
		if #self.buttons == 0 then
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

	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.9)
	love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1)
	love.graphics.rectangle("fill", x, y, modalWidth, modalHeight, 10)
	love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, modalWidth, modalHeight, 10)

	-- Calculate scrollable area and scrollbar position
	local textAreaWidth = availableTextWidth - scrollbarWidth - scrollbarGap
	local textAreaX = x + padding
	local textAreaY = y + padding
	local scrollbarX = textAreaX + textAreaWidth + scrollbarGap
	local scrollbarY = textAreaY

	-- Use new scrollable logic
	local isScrollable, maxScrollPosition, actualContentHeight = self:isContentScrollable(visibleHeight)
	if self.scrollPosition > maxScrollPosition then
		self.scrollPosition = maxScrollPosition
	end

	if isScrollable then
		-- Draw scrollable content with custom logic

		love.graphics.setScissor(textAreaX, textAreaY, textAreaWidth, visibleHeight)
		love.graphics.translate(0, -self.scrollPosition)
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
		love.graphics.printf(self.message, textAreaX, textAreaY, textAreaWidth, "left")
		love.graphics.setScissor()

		-- Draw custom scrollbar flush to the right of the text
		self:drawScrollbar(
			scrollbarX,
			scrollbarY,
			visibleHeight,
			actualContentHeight,
			self.scrollPosition,
			maxScrollPosition,
			1
		)
	else
		local textY = y + padding
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
		love.graphics.printf(self.message, x + padding, textY, availableTextWidth, "center")
		if self.isProgressModal then
			local progressY = textY + mainMessageHeight + 20
			local consoleFont = fonts.loaded.console or currentFont
			local progressBoxX = x + padding
			local progressBoxWidth = availableTextWidth
			local actualProgressBoxHeight = progressBoxHeight
			love.graphics.setColor(
				colors.ui.background[1] * 0.7,
				colors.ui.background[2] * 0.7,
				colors.ui.background[3] * 0.7,
				1
			)
			love.graphics.rectangle("fill", progressBoxX, progressY, progressBoxWidth, actualProgressBoxHeight, 5)
			love.graphics.setFont(consoleFont)
			love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
			local lineHeight = consoleFont:getHeight()
			local startY = progressY + progressBoxPadding
			for i, historyMessage in ipairs(self.progressHistory) do
				local messageY = startY + (i - 1) * lineHeight
				love.graphics.print(historyMessage, progressBoxX + progressBoxPadding, messageY)
			end
			love.graphics.setFont(currentFont)
		end
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
	end

	if #self.buttons == 0 then
		love.graphics.pop()
		return
	end

	local buttonWidth = modalWidth - (BUTTON_HORIZONTAL_PADDING * 2)
	local buttonX = x + BUTTON_HORIZONTAL_PADDING
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
		if button.type == "accented" then
			-- Use Button:drawAccented for accented buttons
			local tempButton = Button:new({
				text = button.text,
				type = "accented",
				screenWidth = buttonWidth,
				height = buttonHeight,
			})
			tempButton.y = buttonY
			tempButton.x = buttonX
			tempButton.focused = isSelected
			tempButton:drawAccented()
		else
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
	end
	love.graphics.pop()
end

return {
	Modal = Modal,
}
