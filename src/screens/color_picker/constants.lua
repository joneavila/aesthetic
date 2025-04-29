--- Color picker shared constants
local state = require("state")

local constants = {}

-- Calculate tab height as a percentage of the screen height
local TAB_HEIGHT_PERCENT = 0.08
local TAB_HEIGHT = math.floor(state.screenHeight * TAB_HEIGHT_PERCENT)
local TAB_TEXT_PADDING = 8 -- Add padding for tab text (8px)
local TAB_CONTAINER_HEIGHT = TAB_HEIGHT * 1.4 + (TAB_TEXT_PADDING * 2) -- Increased container height with text padding
local HEADER_HEIGHT = 50 -- Header height for the color context display
local TAB_CONTENT_OVERLAP = -25 -- Negative value to eliminate any gap between tabs and content

-- Outline constants
constants.OUTLINE = {
	NORMAL_WIDTH = 1,
	SELECTED_WIDTH = 3,
}

-- Function to provide tab height to main color picker screen
constants.getTabHeight = function()
	return TAB_HEIGHT
end

-- Function to calculate the content area dimensions for sub-screens (tab views)
constants.calculateContentArea = function()
	local controls = require("controls")
	-- Ensure HEIGHT is calculated before using it
	controls.calculateHeight()
	return {
		x = 0,
		y = HEADER_HEIGHT + TAB_CONTAINER_HEIGHT + TAB_CONTENT_OVERLAP, -- Negative margin
		width = state.screenWidth,
		-- Adjust height to compensate for overlap
		height = state.screenHeight - HEADER_HEIGHT - TAB_CONTAINER_HEIGHT - controls.HEIGHT - TAB_CONTENT_OVERLAP,
	}
end

return constants
