--- Splash screen animation (terminal-style typing effect)
local love = require("love")
local splash = {}
local colors = require("colors")

function splash.new(init)
	local self = {}

	-- Store onDone callback from init if provided
	self.onDone = init and init.onDone

	-- Use provided font
	self.font = init and init.font
	if not self.font then
		error("Font must be provided to splash screen")
	end

	-- Animation settings
	self.title = require("state").applicationName
	self.typingDelay = 0.05
	self.cursorBlinkRate = 0.3
	self.cursorChar = "_"
	self.holdDuration = 1.3
	self.fadeOutDuration = 0.2

	-- Initialize animation state
	self.currentIndex = 0 -- How many letters have been revealed
	self.letterTimer = 0 -- Timer for next letter
	self.cursorTimer = 0 -- Timer for cursor blink
	self.showCursor = true -- Whether cursor is currently visible
	self.alpha = 1 -- Overall opacity for fade out
	self.holdTimer = 0 -- Timer for hold phase
	self.fadeTimer = 0 -- Timer for fade phase

	self.textWidth = self.font:getWidth(self.title)
	self.cursorWidth = self.font:getWidth(self.cursorChar)
	self.textHeight = self.font:getHeight()

	-- Calculate the fixed center position
	local screenWidth, screenHeight = love.graphics.getDimensions()
	self.centerX = screenWidth / 2 - self.textWidth / 2
	self.centerY = screenHeight / 2 - self.textHeight / 2

	-- State machine
	self.state = "waiting"

	-- Background settings
	self.background = {
		color = { colors.bg[1], colors.bg[2], colors.bg[3], 1 },
	}

	-- Bind methods to the instance
	self.update = splash.update
	self.draw = splash.draw

	return self
end

function splash:draw()
	-- Draw the background
	love.graphics.clear(self.background.color)

	-- Set the title font
	if not self.font then
		return
	end
	love.graphics.setFont(self.font)

	love.graphics.push()
	love.graphics.setColor(colors.fg[1], colors.fg[2], colors.fg[3], self.alpha)

	-- Get visible text and draw it
	if self.currentIndex > 0 then
		local text = string.sub(self.title, 1, self.currentIndex)
		love.graphics.print(text, self.centerX, self.centerY)
	end

	-- Draw cursor at current position if it should be visible
	if (self.state == "typing" or self.state == "holding") and self.showCursor then
		local cursorX = self.centerX
		if self.currentIndex > 0 then
			cursorX = cursorX + self.font:getWidth(string.sub(self.title, 1, self.currentIndex))
		end
		love.graphics.print(self.cursorChar, cursorX, self.centerY)
	end

	love.graphics.pop()
end

function splash:update(dt)
	if not dt then
		return
	end

	if self.state == "done" then
		return
	end

	self.cursorTimer = self.cursorTimer + dt
	if self.cursorTimer >= self.cursorBlinkRate then
		self.cursorTimer = 0
		self.showCursor = not self.showCursor
	end

	-- State machine
	if self.state == "waiting" then
		self.letterTimer = self.letterTimer + dt
		if self.letterTimer >= 0.3 then
			self.state = "typing"
			self.letterTimer = 0
		end
	elseif self.state == "typing" then
		self.letterTimer = self.letterTimer + dt
		if self.letterTimer >= self.typingDelay then
			self.letterTimer = 0
			self.currentIndex = self.currentIndex + 1
			if self.currentIndex >= string.len(self.title) then
				self.state = "holding"
				self.holdTimer = self.holdDuration
			end
		end
	elseif self.state == "holding" then
		self.holdTimer = self.holdTimer - dt
		if self.holdTimer <= 0 then
			self.state = "fading"
		end
	elseif self.state == "fading" then
		self.fadeTimer = self.fadeTimer + dt
		self.alpha = math.max(0, 1 - (self.fadeTimer / self.fadeOutDuration))
		if self.alpha <= 0 then
			self.state = "done"
			if self.onDone then
				self.onDone()
			end
		end
	end
end

setmetatable(splash, {
	__call = function(_, ...)
		return splash.new(...)
	end,
})

return splash
