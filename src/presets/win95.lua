-- Theme preset
-- Classic teal and white interface from the 1990s
return {
	themeName = "Win95",
	background = {
		value = "#008080",
		type = "Solid",
	},
	backgroundGradient = {
		value = "#008080",
		direction = "Vertical",
	},
	foreground = {
		value = "#FFFFFF",
	},
	rgb = {
		value = "#008080",
		mode = "Solid",
		brightness = 5,
		speed = 0,
	},
	created = os.time(),
	boxArtWidth = 0,
	fontFamily = "Cascadia Code",
	fontSize = "Default",
	homeScreenLayout = "Grid",
	headerTextAlignment = 2,
	headerTextAlpha = 0,
	navigationAlignment = "Left",
	navigationAlpha = 100,
	statusAlignment = "Right",
	timeAlignment = "Left",
	glyphsEnabled = true,
	source = "built-in",
}
