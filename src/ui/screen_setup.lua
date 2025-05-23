--- Screen Setup UI component
--- This file provides utilities for setting up common screen elements

local background = require("ui.background")
local header = require("ui.header")
local love = require("love")
local state = require("state")

-- Module table to export public functions
local screen_setup = {}

-- Set up common screen elements and return start Y position
function screen_setup.setup(params)
	-- Draw background
	background.draw()

	-- Draw header with title
	header.draw(params.title or "")

	-- Set font if provided
	if params.font then
		love.graphics.setFont(params.font)
	elseif state.fonts and state.fonts.body then
		love.graphics.setFont(state.fonts.body)
	end

	-- Calculate start Y position for the content
	local startY = params.startY or header.getHeight()

	return startY
end

return screen_setup
