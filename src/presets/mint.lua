-- Theme preset
-- The dev's favorite
return {
	themeName = "Mint",
	background = {
		value = "#104E64",
		type = "Gradient",
	},
	backgroundGradient = {
		value = "#0092B8",
		direction = "Vertical",
	},
	foreground = {
		value = "#A2F3FC",
	},
	rgb = {
		value = "#0092B8",
		mode = "Solid",
		brightness = 5,
		speed = 0,
	},
	created = os.time(),
	boxArtWidth = 280,
	fontFamily = "Inter",
	fontSize = "Default",
	homeScreenLayout = "Grid",
	headerAlignment = 2,
	headerOpacity = 0,
	navigationAlignment = "Left",
	navigationOpacity = 70,
	statusAlignment = "Right",
	timeAlignment = "Left",
	datetimeOpacity = 255,
	glyphsEnabled = true,
	source = "built-in",
}
