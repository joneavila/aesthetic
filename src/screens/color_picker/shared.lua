-- Shared utilities for color_picker subscreens
local header = require("ui.header")
local TabBar = require("ui.tab_bar")

local M = {}

function M.calculateContentArea()
	local controls = require("control_hints")
	local state = require("state")
	local headerContentStartY = header.getContentStartY()
	local tabBarHeight = TabBar.getHeight()
	local controlsHeight = controls.calculateHeight()
	local contentTopPadding = 8
	return {
		x = 0,
		y = headerContentStartY + tabBarHeight + contentTopPadding,
		width = state.screenWidth,
		height = state.screenHeight - (headerContentStartY + tabBarHeight) - controlsHeight,
	}
end

return M
