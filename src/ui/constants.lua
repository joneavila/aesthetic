--- UI Constants
--- This file provides constants that are shared between the UI and menu screens

local UI_CONSTANTS = {
	BUTTON = {
		WIDTH = 0, -- Will be set dynamically
		HEIGHT = 50,
		PADDING = 20,
		COLOR_DISPLAY_SIZE = 30,
		CORNER_RADIUS = 8,
		SELECTED_OUTLINE_WIDTH = 4,
		BOTTOM_MARGIN = 100, -- Margin from bottom for the "Create theme" button
	},
	TRIANGLE = {
		HEIGHT = 20,
		WIDTH = 12,
		PADDING = 16,
	},
	SCROLL_BAR_WIDTH = 10,
}

return UI_CONSTANTS
