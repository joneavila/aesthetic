local love = require("love")
local state = require("state")

local controls = {}

-- Constants
controls.HEIGHT = 42
local PADDING = 20
local RIGHT_PADDING = 20
local ICON_SIZE = 24
local ICON_TEXT_SPACING = 8

-- Cache for loaded icons with size limit
local iconCache = {
	items = {},
	maxSize = 8,
	-- Get current number of items in cache
	count = function(self)
		local count = 0
		for _ in pairs(self.items) do
			count = count + 1
		end
		return count
	end,
}

-- Load an icon from the assets directory, using cache if available
local function loadIcon(path)
	if not path then
		error("Icon path cannot be nil")
	end

	-- Check cache first
	if not iconCache.items[path] then
		-- If cache is full, remove oldest entry
		if iconCache:count() >= iconCache.maxSize then
			local oldest = next(iconCache.items)
			if oldest then
				iconCache.items[oldest] = nil
			end
		end

		-- Load new icon
		local fullPath = "assets/input_prompts/" .. path
		local success, result = pcall(love.graphics.newImage, fullPath)
		if not success then
			error("Failed to load icon: " .. fullPath)
		end
		iconCache.items[path] = result
	end

	return iconCache.items[path]
end

-- Draw the controls area at the bottom of the screen
function controls.draw(controls_list)
	-- Set up graphics state
	love.graphics.setColor(1, 1, 1, 0.7)
	love.graphics.setFont(state.fonts.caption)

	-- Calculate total width needed for all controls
	local totalWidth = 0
	for _, control in ipairs(controls_list) do
		local textWidth = state.fonts.caption:getWidth(control.text)
		totalWidth = totalWidth + ICON_SIZE + ICON_TEXT_SPACING + textWidth + PADDING
	end

	-- Start drawing from the right side, accounting for padding
	local x = state.screenWidth - totalWidth - RIGHT_PADDING
	local y = state.screenHeight - controls.HEIGHT + (controls.HEIGHT - ICON_SIZE) / 2

	-- Draw each control
	for _, control in ipairs(controls_list) do
		-- Load and draw icon
		local icon = loadIcon(control.icon)
		love.graphics.draw(icon, x, y, 0, ICON_SIZE / icon:getWidth(), ICON_SIZE / icon:getHeight())

		-- Draw text
		love.graphics.print(
			control.text,
			x + ICON_SIZE + ICON_TEXT_SPACING,
			y + (ICON_SIZE - state.fonts.caption:getHeight()) / 2
		)

		-- Move x position for next control
		local textWidth = state.fonts.caption:getWidth(control.text)
		x = x + ICON_SIZE + ICON_TEXT_SPACING + textWidth + PADDING
	end
end

return controls
