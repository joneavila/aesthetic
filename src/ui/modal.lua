--- Modal UI module
--- This file contains code for drawing modal dialogs throughout the application
local love = require("love")
local colors = require("colors")
local Component = require("ui.component").Component
local scrollable = require("ui.scrollable")

local Modal = setmetatable({}, { __index = Component })
Modal.__index = Modal

function Modal:new(config)
	local instance = Component.new(self, config or {})
	instance.visible = false
	instance.message = ""
	instance.buttons = {}
	instance.selectedIndex = 1
	instance.scrollPosition = 0
	instance.font = config and config.font or love.graphics.getFont()
	instance.onButtonPress = config and config.onButtonPress or nil
	return instance
end

function Modal:show(message, buttons)
	self.visible = true
	self.message = message or ""
	self.buttons = buttons or {}
	self.selectedIndex = 1
	self.scrollPosition = 0
end

function Modal:hide()
	self.visible = false
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
	-- No-op for now
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

	if #self.buttons == 0 then
		return true
	end

	if input.isPressed("dpup") then
		self:moveFocus(-1)
		return true
	elseif input.isPressed("dpdown") then
		self:moveFocus(1)
		return true
	elseif input.isPressed("a") then
		local selectedOption = self.buttons[self.selectedIndex]
		if selectedOption and selectedOption.onSelect then
			selectedOption.onSelect()
		end
		if self.onButtonPress then
			self.onButtonPress(self.selectedIndex, selectedOption)
		end
		return true
	end

	if input.isPressed("b") then
		self:hide()
		return true
	end

	return false
end

function Modal:draw(screenWidth, screenHeight, font)
	if not self.visible then
		return
	end
	local controls = require("controls")
	local controlsHeight = controls.HEIGHT or controls.calculateHeight()
	local padding = 40
	local maxWidth = screenWidth * 0.9
	local currentFont = font or self.font or love.graphics.getFont()
	love.graphics.setFont(currentFont)
	local maxTextHeight = screenHeight * 0.6
	local estimatedTextWidth = math.min(screenWidth * 0.8, maxWidth) - (padding * 2)
	local _, estimatedLines = currentFont:getWrap(self.message, estimatedTextWidth)
	local estimatedTextHeight = #estimatedLines * currentFont:getHeight()
	local isScrollable = estimatedTextHeight > maxTextHeight
	local minWidth = math.min(screenWidth * 0.8, maxWidth)
	if #self.buttons == 0 and not isScrollable then
		minWidth = math.min(currentFont:getWidth(self.message) + (padding * 2), maxWidth)
	end
	local availableTextWidth = minWidth - (padding * 2)
	local _, lines = currentFont:getWrap(self.message, availableTextWidth)
	local lineHeight = currentFont:getHeight()
	local textHeight = #lines * lineHeight
	local contentHeight = textHeight
	local visibleHeight = math.min(screenHeight * 0.6, contentHeight)
	isScrollable = contentHeight > visibleHeight
	local modalWidth = minWidth
	local buttonHeight = 40
	local buttonSpacing = 20
	local buttonsExtraHeight = 0
	if #self.buttons > 0 then
		buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
	end
	local modalHeight = visibleHeight + (padding * 2) + buttonsExtraHeight
	local maxAvailableHeight = screenHeight - controlsHeight - 20
	if modalHeight > maxAvailableHeight then
		modalHeight = maxAvailableHeight
		visibleHeight = modalHeight - (padding * 2) - buttonsExtraHeight
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
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
	if isScrollable then
		local drawContent = function()
			love.graphics.printf(self.message, x + padding, y + padding, availableTextWidth, "left")
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
		love.graphics.printf(self.message, x + padding, textY, availableTextWidth, "center")
	end
	if #self.buttons > 0 then
		local buttonWidth = 300
		local buttonX = (screenWidth - buttonWidth) / 2
		local startButtonY
		if isScrollable then
			startButtonY = y + padding + visibleHeight + padding
		else
			startButtonY = y + padding + textHeight + padding
		end
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
	end
end

return {
	Modal = Modal,
}
