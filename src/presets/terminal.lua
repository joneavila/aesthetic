-- Theme preset
-- Classic green-on-black hacker aesthetic
return {
	themeName = "Terminal",
	background = {
		value = "#000000",
		type = "Solid",
	},
	backgroundGradient = {
		value = "#000000",
		direction = "Vertical",
	},
	foreground = {
		value = "#00FF00",
	},
	rgb = {
		value = "#00FF00",
		mode = "Solid",
		brightness = 5,
		speed = 0,
	},
	created = os.time(),
	boxArtWidth = 0,
	fontFamily = "Retro Pixel",
	fontSize = "Large",
	homeScreenLayout = "Grid",
	headerTextAlignment = 2,
	headerTextAlpha = 0,
	navigationAlignment = "Left",
	navigationAlpha = 100,
	statusAlignment = "Right",
	timeAlignment = "Left",
	glyphsEnabled = false,
	source = "built-in",
}
