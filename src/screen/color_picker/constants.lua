--- Color picker shared constants
local state = require("state")

local constants = {}

-- Calculate tab height as a percentage of the screen height
local TAB_HEIGHT_PERCENT = 0.08
local TAB_HEIGHT = math.floor(state.screenHeight * TAB_HEIGHT_PERCENT)
local TAB_CONTAINER_HEIGHT = TAB_HEIGHT * 1.4 -- Match the increased container height in color_picker.lua
local HEADER_HEIGHT = 50 -- Header height for the color context display
local TAB_CONTENT_OVERLAP = -25 -- Negative value to eliminate any gap between tabs and content

-- Function to provide tab height to main color picker screen
constants.getTabHeight = function()
	return TAB_HEIGHT
end

-- Function to calculate the content area dimensions for sub-screens (tab views)
constants.calculateContentArea = function()
	local controls = require("controls")
	return {
		x = 0,
		y = HEADER_HEIGHT + TAB_CONTAINER_HEIGHT + TAB_CONTENT_OVERLAP, -- Negative margin
		width = state.screenWidth,
		-- Adjust height to compensate for overlap
		height = state.screenHeight - HEADER_HEIGHT - TAB_CONTAINER_HEIGHT - controls.HEIGHT - TAB_CONTENT_OVERLAP,
	}
end

return constants
