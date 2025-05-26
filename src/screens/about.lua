local love = require("love")
local state = require("state")
local colors = require("colors")
local controls = require("controls")
local version = require("version")
local background = require("ui.background")
local virtualJoystick = require("input").virtualJoystick
local paths = require("paths")
local header = require("ui.header")

local about = {}

-- Constants
local PADDING = 20
local MENU_SCREEN = "main_menu"
local ABOUT_TEXT_PART1 = "Check out the source code on GitHub!"
local GITHUB_LINK = "https://github.com/joneavila/aesthetic"
local ABOUT_TEXT_PART2 = [[

Contact:
@mxdamp (muOS community forum)
@joneavila (GitHub)]]
local KOFI_TEXT = "Support the project, donate via Ko-Fi"

-- Store screen switching function
local switchScreen = nil
local qrCodeImage = nil

function about.load()
	-- Load QR code image
	qrCodeImage = love.graphics.newImage(paths.KOFI_QR_CODE_PATH)
end

function about.draw()
	-- Set background
	background.draw()

	local contentWidth = state.screenWidth - (PADDING * 2)
	local font = state.fonts.body

	-- Draw header using header module
	header.draw(state.applicationName .. " " .. version.getVersionString())
	local headerHeight = header.getContentStartY()

	-- Calculate Y positions for text
	local bodyY = headerHeight + PADDING

	love.graphics.setFont(font)

	-- Draw Part 1
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.printf(ABOUT_TEXT_PART1, PADDING, bodyY, contentWidth, "left")

	-- Draw GitHub link
	local part1Lines = 1
	love.graphics.setColor(colors.ui.accent)
	love.graphics.printf(GITHUB_LINK, PADDING, bodyY + font:getHeight() * part1Lines, contentWidth, "left")

	-- Draw Part 2
	love.graphics.setColor(colors.ui.foreground)
	-- Count lines in ABOUT_TEXT_PART2
	local about2Lines = 0
	for _ in ABOUT_TEXT_PART2:gmatch("\n") do
		about2Lines = about2Lines + 1
	end
	about2Lines = about2Lines + 1 -- for the last line
	love.graphics.printf(ABOUT_TEXT_PART2, PADDING, bodyY + font:getHeight() * (part1Lines + 1), contentWidth, "left")

	-- Calculate total lines above QR code
	local totalLines = part1Lines + 1 + about2Lines
	local qrY = bodyY + font:getHeight() * totalLines + PADDING

	if qrCodeImage then
		love.graphics.setColor(1, 1, 1, 1)
		local availableHeight = state.screenHeight - qrY - font:getHeight() - PADDING * 2
		local imageWidth = qrCodeImage:getWidth()
		local imageHeight = qrCodeImage:getHeight()
		local scale = math.min(1, availableHeight / imageHeight)
		local scaledWidth = imageWidth * scale
		local qrX = (state.screenWidth - scaledWidth) / 2
		love.graphics.draw(qrCodeImage, qrX, qrY, 0, scale, scale)
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.setFont(font)
		love.graphics.printf(KOFI_TEXT, PADDING, qrY + (imageHeight * scale) + PADDING, contentWidth, "center")
	end

	-- Draw controls
	controls.draw({ {
		button = "b",
		text = "Back",
	} })
end

function about.update(_dt)
	if virtualJoystick.isGamepadPressedWithDelay("b") then
		if switchScreen then
			switchScreen(MENU_SCREEN)
		end
	end
end

function about.setScreenSwitcher(switchFunc)
	switchScreen = switchFunc
end

return about
