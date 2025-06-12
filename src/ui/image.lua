--- Image component for displaying images with rounded corners and outline
local love = require("love")
local colors = require("colors")
local logger = require("utils.logger")

local imageComponent = {}

-- Default corner radius and outline color (match gradient_preview.lua)
local DEFAULT_CORNER_RADIUS = 8 -- Matches default button corner radius
local OUTLINE_COLOR = colors.ui.foreground

-- Gaussian blur shader code (separable, horizontal/vertical pass)
local BLUR_SHADER_CODE = [[
extern number direction; // 0 = horizontal, 1 = vertical
extern number radius;    // blur radius
vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords) {
    vec2 size = love_ScreenSize.xy;
    vec2 dir = direction == 0.0 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    float sigma = radius / 2.0;
    float twoSigmaSq = 2.0 * sigma * sigma;
    float norm = 0.0;
    vec4 sum = vec4(0.0);
    for (float i = -radius; i <= radius; i++) {
        float weight = exp(-(i * i) / twoSigmaSq);
        vec2 offset = dir * i / size;
        sum += Texel(tex, tex_coords + offset) * weight;
        norm += weight;
    }
    return sum / norm * color;
}
]]

-- Default halo parameters
local HALO_PARAMS = {
	enabled = true,
	scaleFactor = 1.05, -- How much larger the halo is than the image
	blurRadius = 8, -- Blur radius in pixels
	intensity = 0.25, -- Alpha of the halo
}

-- Utility function to get or create blur shaders
local blurShaders = { h = nil, v = nil }
local function getBlurShaders()
	if not blurShaders.h then
		blurShaders.h = love.graphics.newShader(BLUR_SHADER_CODE)
		blurShaders.h:send("direction", 0)
	end
	if not blurShaders.v then
		blurShaders.v = love.graphics.newShader(BLUR_SHADER_CODE)
		blurShaders.v:send("direction", 1)
	end
	return blurShaders.h, blurShaders.v
end

--- Draws an image with rounded corners and outline
function imageComponent.drawWithOutline(image, x, y, width, height, cornerRadius)
	logger.debug("drawWithOutline called")
	cornerRadius = cornerRadius or DEFAULT_CORNER_RADIUS
	if not image then
		logger.debug("drawWithOutline: image is nil, returning early")
		return
	end

	love.graphics.push("all")
	-- Create stencil for rounded corners
	if cornerRadius and cornerRadius > 0 then
		love.graphics.stencil(function()
			love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)
		end, "replace", 1)
		love.graphics.setStencilTest("greater", 0)
	end

	-- Draw the image
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, x, y, 0, width / image:getWidth(), height / image:getHeight())

	if cornerRadius and cornerRadius > 0 then
		love.graphics.setStencilTest()
	end

	-- Draw outline
	love.graphics.setColor(OUTLINE_COLOR)
	if cornerRadius and cornerRadius > 0 then
		love.graphics.rectangle("line", x, y, width, height, cornerRadius, cornerRadius)
	else
		love.graphics.rectangle("line", x, y, width, height)
	end

	love.graphics.pop()
end
function imageComponent.drawWithHalo(image, x, y, width, height, cornerRadius, haloParams)
	if cornerRadius <= 0 then
		logger.warning(
			"drawWithHalo: cornerRadius is 0, using default cornerRadius=" .. tostring(DEFAULT_CORNER_RADIUS)
		)
	end

	logger.debug("drawWithHalo called, haloParams.enabled=" .. tostring(haloParams and haloParams.enabled))
	cornerRadius = cornerRadius or DEFAULT_CORNER_RADIUS
	haloParams = haloParams or HALO_PARAMS
	if not image then
		logger.debug("drawWithHalo: image is nil, returning early")
		return
	end
	if not haloParams.enabled then
		logger.debug("drawWithHalo: haloParams.enabled is false, falling back to drawWithOutline")
		return imageComponent.drawWithOutline(image, x, y, width, height, cornerRadius)
	end
	love.graphics.push("all")
	-- 1. Render image to a canvas
	local imgW, imgH = width, height
	local canvas = love.graphics.newCanvas(imgW, imgH)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, 0, 0, 0, imgW / image:getWidth(), imgH / image:getHeight())
	love.graphics.setCanvas()
	-- 2. Blur horizontally
	local blurH, blurV = getBlurShaders()
	blurH:send("radius", haloParams.blurRadius)
	blurV:send("radius", haloParams.blurRadius)
	local blur1 = love.graphics.newCanvas(imgW, imgH)
	love.graphics.setCanvas(blur1)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setShader(blurH)
	love.graphics.draw(canvas)
	love.graphics.setShader()
	love.graphics.setCanvas()
	-- 3. Blur vertically
	local blur2 = love.graphics.newCanvas(imgW, imgH)
	love.graphics.setCanvas(blur2)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setShader(blurV)
	love.graphics.draw(blur1)
	love.graphics.setShader()
	love.graphics.setCanvas()

	-- local scaleFactor = haloParams.scale or 1.2
	local scaleFactor = 1.05
	local scaledWidth = width * scaleFactor
	local scaledHeight = height * scaleFactor
	local haloX = x + (width - scaledWidth) / 2
	local haloY = y + (height - scaledHeight) / 2

	love.graphics.setColor(1, 1, 1, haloParams.intensity or 0.15)

	local featherShader = love.graphics.newShader("shaders/feather_alpha.fs")
	featherShader:send("radius", 0.5) -- full shape extent (to edges)
	featherShader:send("edgeSoftness", 0.1) -- fade zone width (20% of 0.5 = 0.1)
	-- featherShader:send("fadeStart", -0.4)
	-- featherShader:send("fadeEnd", 0.0)

	-- Convert corner radius to normalized coordinates
	-- Assuming square aspect ratio; adjust if needed for rectangular shapes
	local normalizedCornerRadius = cornerRadius / math.min(width, height)
	print("Sending cornerRadius:", normalizedCornerRadius) -- Debug output
	featherShader:send("cornerRadius", normalizedCornerRadius)

	love.graphics.setShader(featherShader)
	love.graphics.setColor(1, 1, 1, haloParams.intensity or 0.2)
	love.graphics.draw(blur2, haloX, haloY, 0, scaledWidth / imgW, scaledHeight / imgH)
	love.graphics.setShader()

	-- Stencil for original image (normal rounded rect)
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)
	end, "replace", 1)
	love.graphics.setStencilTest("equal", 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, x, y, 0, width / image:getWidth(), height / image:getHeight())
	love.graphics.pop()
end

-- function imageComponent.drawWithHalo(image, x, y, width, height, cornerRadius, haloParams)
-- 	if cornerRadius <= 0 then
-- 		logger.warning(
-- 			"drawWithHalo: cornerRadius is 0, using default cornerRadius=" .. tostring(DEFAULT_CORNER_RADIUS)
-- 		)
-- 	end

-- 	logger.debug("drawWithHalo called, haloParams.enabled=" .. tostring(haloParams and haloParams.enabled))
-- 	cornerRadius = cornerRadius or DEFAULT_CORNER_RADIUS
-- 	haloParams = haloParams or HALO_PARAMS
-- 	if not image then
-- 		logger.debug("drawWithHalo: image is nil, returning early")
-- 		return
-- 	end
-- 	if not haloParams.enabled then
-- 		logger.debug("drawWithHalo: haloParams.enabled is false, falling back to drawWithOutline")
-- 		return imageComponent.drawWithOutline(image, x, y, width, height, cornerRadius)
-- 	end
-- 	love.graphics.push("all")
-- 	-- 1. Render image to a canvas
-- 	local imgW, imgH = width, height
-- 	local canvas = love.graphics.newCanvas(imgW, imgH)
-- 	love.graphics.setCanvas(canvas)
-- 	love.graphics.clear(0, 0, 0, 0)
-- 	love.graphics.setColor(1, 1, 1, 1)
-- 	love.graphics.draw(image, 0, 0, 0, imgW / image:getWidth(), imgH / image:getHeight())
-- 	love.graphics.setCanvas()
-- 	-- 2. Blur horizontally
-- 	local blurH, blurV = getBlurShaders()
-- 	blurH:send("radius", haloParams.blurRadius)
-- 	blurV:send("radius", haloParams.blurRadius)
-- 	local blur1 = love.graphics.newCanvas(imgW, imgH)
-- 	love.graphics.setCanvas(blur1)
-- 	love.graphics.clear(0, 0, 0, 0)
-- 	love.graphics.setShader(blurH)
-- 	love.graphics.draw(canvas)
-- 	love.graphics.setShader()
-- 	love.graphics.setCanvas()
-- 	-- 3. Blur vertically
-- 	local blur2 = love.graphics.newCanvas(imgW, imgH)
-- 	love.graphics.setCanvas(blur2)
-- 	love.graphics.clear(0, 0, 0, 0)
-- 	love.graphics.setShader(blurV)
-- 	love.graphics.draw(blur1)
-- 	love.graphics.setShader()
-- 	love.graphics.setCanvas()

-- 	-- local scaleFactor = haloParams.scale or 1.2
-- 	local scaleFactor = 1.5
-- 	local scaledWidth = width * scaleFactor
-- 	local scaledHeight = height * scaleFactor
-- 	local haloX = x + (width - scaledWidth) / 2
-- 	local haloY = y + (height - scaledHeight) / 2

-- 	love.graphics.setColor(1, 1, 1, haloParams.intensity or 0.15)

-- 	local featherShader = love.graphics.newShader("shaders/feather_alpha.fs")
-- 	featherShader:send("radius", 0.3) -- full intensity inside 30%
-- 	featherShader:send("edgeSoftness", 0.2) -- fade from 30% to 50%

-- 	love.graphics.setShader(featherShader)
-- 	love.graphics.setColor(1, 1, 1, haloParams.intensity or 0.2)
-- 	love.graphics.draw(blur2, haloX, haloY, 0, scaledWidth / imgW, scaledHeight / imgH)
-- 	love.graphics.setShader()

-- 	-- Stencil for original image (normal rounded rect)
-- 	love.graphics.stencil(function()
-- 		love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)
-- 	end, "replace", 1)
-- 	love.graphics.setStencilTest("equal", 1)
-- 	love.graphics.setColor(1, 1, 1, 1)
-- 	love.graphics.draw(image, x, y, 0, width / image:getWidth(), height / image:getHeight())
-- 	love.graphics.pop()
-- end

-- Make this the default draw
function imageComponent.draw(image, x, y, width, height, cornerRadius, haloParams)
	haloParams = haloParams or HALO_PARAMS
	logger.debug("draw called, haloParams.enabled=" .. tostring(haloParams and haloParams.enabled))
	if haloParams.enabled ~= false then
		logger.debug("draw: using drawWithHalo")
		return imageComponent.drawWithHalo(image, x, y, width, height, cornerRadius, haloParams)
	end
	logger.debug("draw: using drawWithOutline fallback")
	return imageComponent.drawWithOutline(image, x, y, width, height, cornerRadius)
end

return imageComponent
