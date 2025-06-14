-- Theme preset
-- Retro-futuristic pink and teal for 80s nostalgia
return {
	themeName = "Vaporwave",
	background = {
		value = "#FFC1CC",
		type = "Solid",
	},
	backgroundGradient = {
		value = "#FFC1CC",
		direction = "Vertical",
	},
	foreground = {
		value = "#007F7F",
	},
	rgb = {
		value = "#007F7F",
		mode = "Solid",
		brightness = 5,
		speed = 0,
	},
	created = os.time(),
	boxArtWidth = 0,
	fontFamily = "Inter",
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
	batteryActive = "#4ADE80",
	batteryLow = "#F87171",
	batteryOpacity = 255,
}
