--- Splash screen animation (terminal-style typing effect)
local love = require("love")
local splash = {}
local colors = require("colors")
local state = require("state")
local virtualJoystick = require("input").virtualJoystick

-- Screen switching function set by the screens manager
local switchScreen = nil

function splash.setScreenSwitcher(switcher)
	switchScreen = switcher
end

function splash.load()
	-- Animation settings
	splash.title = state.applicationName
	splash.typingDelay = 0.05 -- Delay between revealing each character
	splash.cursorBlinkRate = 0.3 -- How fast the cursor blinks
	splash.cursorChar = "_" -- Character used to represent the cursor
	splash.holdDuration = 1.3 -- Duration to display the complete text before fading out
	splash.fadeOutDuration = 0.2 -- Duration of the fade out animation

	-- Initialize animation state
	splash.currentIndex = 0 -- How many letters have been revealed
	splash.letterTimer = 0 -- Timer for next letter
	splash.cursorTimer = 0 -- Timer for cursor blink
	splash.showCursor = true -- Whether cursor is currently visible
	splash.alpha = 1 -- Overall opacity for fade out
	splash.holdTimer = 0 -- Timer for hold phase
	splash.fadeTimer = 0 -- Timer for fade phase

	-- Use the mono title font
	splash.font = state.fonts.monoTitle

	-- Dimensions for positioning
	splash.textWidth = splash.font:getWidth(splash.title)
	splash.cursorWidth = splash.font:getWidth(splash.cursorChar)
	splash.textHeight = splash.font:getHeight()

	-- Calculate the fixed center position (ensure pixel-perfect alignment)
	splash.centerX = math.floor(state.screenWidth / 2 - splash.textWidth / 2)
	splash.centerY = math.floor(state.screenHeight / 2 - splash.textHeight / 2)

	-- State machine: controls the animation phase (waiting, typing, holding, fading, done)
	splash.state = "waiting"

	-- Background settings
	splash.background = {
		color = { colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1 },
	}
end

function splash.onEnter()
	-- Reset animation state when entering the screen
	splash.currentIndex = 0
	splash.letterTimer = 0
	splash.cursorTimer = 0
	splash.showCursor = true
	splash.alpha = 1
	splash.holdTimer = 0
	splash.fadeTimer = 0
	splash.state = "waiting"
end

function splash.draw()
	-- Draw the background
	love.graphics.clear(splash.background.color)

	-- Set the title font
	if not splash.font then
		return
	end
	love.graphics.setFont(splash.font)

	love.graphics.push()
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], splash.alpha)

	-- Get visible text and draw it
	if splash.currentIndex > 0 then
		local text = string.sub(splash.title, 1, splash.currentIndex)
		love.graphics.print(text, splash.centerX, splash.centerY)
	end

	-- Draw cursor at current position if it should be visible
	if (splash.state == "typing" or splash.state == "holding") and splash.showCursor then
		local cursorX = splash.centerX
		if splash.currentIndex > 0 then
			cursorX = cursorX + splash.font:getWidth(string.sub(splash.title, 1, splash.currentIndex))
		end
		-- Ensure pixel-perfect alignment for cursor position
		cursorX = math.floor(cursorX)
		love.graphics.print(splash.cursorChar, cursorX, splash.centerY)
	end

	love.graphics.pop()
end

function splash.update(dt)
	if not dt then
		return
	end

	if splash.state == "done" then
		return
	end

	splash.cursorTimer = splash.cursorTimer + dt
	if splash.cursorTimer >= splash.cursorBlinkRate then
		splash.cursorTimer = 0
		splash.showCursor = not splash.showCursor
	end

	-- State machine
	if splash.state == "waiting" then
		splash.letterTimer = splash.letterTimer + dt
		if splash.letterTimer >= 0.3 then
			splash.state = "typing"
			splash.letterTimer = 0
		end
	elseif splash.state == "typing" then
		splash.letterTimer = splash.letterTimer + dt
		if splash.letterTimer >= splash.typingDelay then
			splash.letterTimer = 0
			splash.currentIndex = splash.currentIndex + 1
			if splash.currentIndex >= string.len(splash.title) then
				splash.state = "holding"
				splash.holdTimer = splash.holdDuration
			end
		end
	elseif splash.state == "holding" then
		splash.holdTimer = splash.holdTimer - dt
		if splash.holdTimer <= 0 then
			splash.state = "fading"
		end
	elseif splash.state == "fading" then
		splash.fadeTimer = splash.fadeTimer + dt
		splash.alpha = math.max(0, 1 - (splash.fadeTimer / splash.fadeOutDuration))
		if splash.alpha <= 0 then
			splash.state = "done"
			-- When done, switch to the menu screen
			if switchScreen then
				-- Initialize the fade effect before switching
				state.fading = true
				state.fadeTimer = 0
				switchScreen("main_menu")
			end
		end
	end
end

return splash
