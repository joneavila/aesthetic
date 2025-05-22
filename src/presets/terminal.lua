-- Theme preset
-- Classic green-on-black hacker aesthetic
return {
	displayName = "Terminal",
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
	boxArtWidth = "Disabled",
	font = "Retro Pixel",
	fontSize = "Large",
	glyphs_enabled = false,
	source = "built-in",
}
