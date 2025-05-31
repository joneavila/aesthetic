local logger = require("utils.logger")

local fonts = {
	{ name = "Inter", path = "assets/fonts/inter/inter_24pt_semibold.ttf" },
	{ name = "BPreplay", path = "assets/fonts/bpreplay/bpreplay_bold.otf" },
	{ name = "Silver", path = "assets/fonts/silver/silver.ttf" },
	{ name = "Montserrat", path = "assets/fonts/montserrat/montserrat_bold.ttf" },
	{ name = "Retro Pixel", path = "assets/fonts/retro_pixel/retro_pixel_thick.ttf" },
	{ name = "JetBrains Mono", path = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf" },
	{ name = "Cascadia Code", path = "assets/fonts/cascadia_code/cascadia_code_bold.ttf" },
	{ name = "Nunito", path = "assets/fonts/nunito/nunito_bold.ttf" },
}

local reference_font_name = "Inter"
local reference_size = 24

local font_calibration = {}

function font_calibration.run()
	local love = require("love")
	local reference_metrics = {}
	local results = {}

	-- Load reference font
	local ref_font = love.graphics.newFont(fonts[1].path, reference_size)
	reference_metrics.ascent = ref_font:getAscent()
	reference_metrics.descent = ref_font:getDescent()
	reference_metrics.height = ref_font:getHeight()
	reference_metrics.sum = reference_metrics.ascent + reference_metrics.descent

	logger.debug("Font Calibration Results (matching Inter 24pt)")
	logger.debug(string.format("%-16s %-8s %-8s %-8s %-8s %-8s", "Font", "Size", "Ascent", "Descent", "Height", "Sum"))

	for i, font in ipairs(fonts) do
		if font.name == reference_font_name then
			results[font.name] = {
				best_size = reference_size,
				best_diff = 0,
				ascent = reference_metrics.ascent,
				descent = reference_metrics.descent,
				height = reference_metrics.height,
				sum = reference_metrics.sum,
			}
		else
			local best_size = reference_size
			local best_diff = math.huge
			local best_metrics = {}
			for size = 12, 48 do
				local status, test_font = pcall(love.graphics.newFont, font.path, size)
				if status and test_font then
					local ascent = test_font:getAscent()
					local descent = test_font:getDescent()
					local sum = ascent + descent
					local diff = math.abs(sum - reference_metrics.sum)
					if diff < best_diff then
						best_diff = diff
						best_size = size
						best_metrics = {
							ascent = ascent,
							descent = descent,
							height = test_font:getHeight(),
							sum = sum,
						}
					end
				end
			end
			results[font.name] = {
				best_size = best_size,
				best_diff = best_diff,
				ascent = best_metrics.ascent,
				descent = best_metrics.descent,
				height = best_metrics.height,
				sum = best_metrics.sum,
			}
		end
	end

	for _, font in ipairs(fonts) do
		local r = results[font.name]
		logger.debug(
			string.format(
				"%-16s %-8d %-8.1f %-8.1f %-8.1f %-8.1f",
				font.name,
				r.best_size or 0,
				r.ascent or 0,
				r.descent or 0,
				r.height or 0,
				r.sum or 0
			)
		)
	end
end

return font_calibration
