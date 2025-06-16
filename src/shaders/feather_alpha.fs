extern float radius;        // normalized [0.0, 1.0] - controls fade distance
extern float edgeSoftness;   // falloff control
extern float cornerRadius;   // corner radius in normalized coordinates [0.0, 0.5]
// extern float fadeStart;      // start of fade zone
// extern float fadeEnd;        // end of fade zone

vec4 effect(vec4 color, Image texture, vec2 texCoords, vec2 screenCoords)
{
    vec4 pixel = Texel(texture, texCoords);

    // Convert to centered coordinates [-0.5, 0.5]
    vec2 p = texCoords - vec2(0.5, 0.5);

    // Ensure cornerRadius is used and clamped to valid range
    float r = clamp(cornerRadius, 0.0, 0.4);

    // Calculate distance to rounded rectangle
    vec2 d = abs(p) - vec2(0.5 - r, 0.5 - r);
    float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;

    // Create non-linear fade: full opacity for 80% of shape, then fade over remaining 20%
    // The fade starts at 80% of the radius distance and goes to 100%
    float fadeStart = -radius * 0.1;  // 20% into the shape (negative because inside)
    float fadeEnd = fadeStart + edgeSoftness;  // fade zone width controlled by edgeSoftness

    float fade = 1.0 - smoothstep(fadeStart, fadeEnd, dist);

    pixel.a *= fade;
    return pixel * color;
}