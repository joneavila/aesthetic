--- Color picker shared constants
local state = require("state")

local constants = {}

-- Calculate tab height as a percentage of the screen height
local TAB_HEIGHT_PERCENT = 0.08
local TAB_HEIGHT = math.floor(state.screenHeight * TAB_HEIGHT_PERCENT)

-- Function to provide tab height to main color picker screen
constants.getTabHeight = function()
	return TAB_HEIGHT
end

-- Function to calculate the content area dimensions for sub-screens (tab views)
constants.calculateContentArea = function()
	local controls = require("controls")
	return {
		x = 0,
		y = TAB_HEIGHT,
		width = state.screenWidth,
		height = state.screenHeight - TAB_HEIGHT - controls.HEIGHT,
	}
end

return constants
