-- Theme preset
-- Dark theme with lavender accents for late-night sessions
return {
	themeName = "Purple Noir",
	background = {
		value = "#1C1B29",
		type = "Solid",
	},
	backgroundGradient = {
		value = "#1C1B29",
		direction = "Vertical",
	},
	foreground = {
		value = "#D0A9F5",
	},
	rgb = {
		value = "#D0A9F5",
		mode = "Solid",
		brightness = 5,
		speed = 0,
	},
	created = os.time(),
	boxArtWidth = 0,
	fontFamily = "Cascadia Code",
	fontSize = "Default",
	homeScreenLayout = "Grid",
	headerAlignment = 2,
	headerOpacity = 0,
	navigationAlignment = "Left",
	navigationOpacity = 100,
	statusAlignment = "Right",
	timeAlignment = "Left",
	datetimeOpacity = 255,
	glyphsEnabled = true,
	source = "built-in",
}
