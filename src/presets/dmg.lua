-- Theme preset
-- Green palette inspired by the original handheld console
return {
	themeName = "DMG",
	background = {
		value = "#9BBC0F",
		type = "Solid",
	},
	backgroundGradient = {
		value = "#9BBC0F",
		direction = "Vertical",
	},
	foreground = {
		value = "#0F380F",
	},
	rgb = {
		value = "#9BBC0F",
		mode = "Solid",
		brightness = 5,
		speed = 0,
	},
	created = os.time(),
	boxArtWidth = 0,
	fontFamily = "Retro Pixel",
	fontSize = "Default",
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
