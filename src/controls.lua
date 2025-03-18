local love = require("love")
local state = require("state")
local colors = require("colors")
local controls = {}

-- Constants
controls.HEIGHT = 42
local PADDING = 14
local RIGHT_PADDING = 4
local ICON_SIZE = 24
local ICON_TEXT_SPACING = 4

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
-- Supports both single icons (control.icon = "icon.png") and lists of icons (control.icon = {"icon1.png", "icon2.png"})
-- When a list of icons is provided, they are drawn in sequence with a "/" separator between them
function controls.draw(controls_list)
	-- Set up graphics state
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.setFont(state.fonts.caption)

	-- Calculate total width needed for all controls
	local totalWidth = 0
	for _, control in ipairs(controls_list) do
		local textWidth = state.fonts.caption:getWidth(control.text)
		local iconsWidth = 0

		if type(control.icon) == "table" then
			-- Multiple icons with "/" between them
			for i = 1, #control.icon do
				iconsWidth = iconsWidth + ICON_SIZE
				-- Add width for "/" separator if not the last icon
				if i < #control.icon then
					iconsWidth = iconsWidth + state.fonts.caption:getWidth("/") + ICON_TEXT_SPACING * 2
				end
			end
		else
			-- Single icon
			iconsWidth = ICON_SIZE
		end

		totalWidth = totalWidth + iconsWidth + ICON_TEXT_SPACING + textWidth + PADDING
	end

	-- Start drawing from the right side, accounting for padding
	local x = state.screenWidth - totalWidth - RIGHT_PADDING
	local y = state.screenHeight - controls.HEIGHT + (controls.HEIGHT - ICON_SIZE) / 2

	-- Draw each control
	for _, control in ipairs(controls_list) do
		local startX = x

		if type(control.icon) == "table" then
			-- Draw multiple icons with "/" between them
			for i, iconPath in ipairs(control.icon) do
				-- Load and draw icon
				local icon = loadIcon(iconPath)
				love.graphics.draw(icon, x, y, 0, ICON_SIZE / icon:getWidth(), ICON_SIZE / icon:getHeight())
				x = x + ICON_SIZE

				-- Draw separator if not the last icon
				if i < #control.icon then
					love.graphics.print(
						"/",
						x + ICON_TEXT_SPACING,
						y + (ICON_SIZE - state.fonts.caption:getHeight()) / 2
					)
					x = x + state.fonts.caption:getWidth("/") + ICON_TEXT_SPACING * 2
				end
			end
		else
			-- Load and draw single icon
			local icon = loadIcon(control.icon)
			love.graphics.draw(icon, x, y, 0, ICON_SIZE / icon:getWidth(), ICON_SIZE / icon:getHeight())
			x = x + ICON_SIZE
		end

		-- Draw text
		love.graphics.print(control.text, x + ICON_TEXT_SPACING, y + (ICON_SIZE - state.fonts.caption:getHeight()) / 2)

		-- Move x position for next control
		local textWidth = state.fonts.caption:getWidth(control.text)

		if type(control.icon) == "table" then
			-- Calculate width for multiple icons
			local iconsWidth = ICON_SIZE * #control.icon
			for i = 1, #control.icon - 1 do
				iconsWidth = iconsWidth + state.fonts.caption:getWidth("/") + ICON_TEXT_SPACING * 2
			end
			x = startX + iconsWidth + ICON_TEXT_SPACING + textWidth + PADDING
		else
			-- Calculate width for single icon
			x = startX + ICON_SIZE + ICON_TEXT_SPACING + textWidth + PADDING
		end
	end
end

return controls
