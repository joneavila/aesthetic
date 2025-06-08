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
	headerAlignment = 2,
	headerOpacity = 0,
	navigationAlignment = "Left",
	navigationOpacity = 100,
	statusAlignment = "Right",
	timeAlignment = "Left",
	datetimeOpacity = 255,
	glyphsEnabled = false,
	source = "built-in",
	batteryActive = "#4ADE80",
	batteryLow = "#F87171",
	batteryOpacity = 255,
}
