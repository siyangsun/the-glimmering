shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float posterize_levels : hint_range(2.0, 32.0) = 8.0;
uniform float dither_strength  : hint_range(0.0, 1.0)  = 0.05;

// 8×8 clustered-dot pattern — concentric rings rather than the mechanical
// Bayer crosshatch, giving a more organic halftone feel.
float clustered_dot(vec2 pos) {
	int x = int(mod(pos.x, 8.0));
	int y = int(mod(pos.y, 8.0));
	int idx = y * 8 + x;
	int t[64] = int[64](
		24, 10, 12, 26, 35, 47, 49, 37,
		 8,  0,  2, 14, 45, 59, 61, 51,
		22,  6,  4, 16, 43, 57, 63, 53,
		30, 20, 18, 28, 33, 41, 55, 39,
		34, 46, 48, 36, 25, 11, 13, 27,
		44, 58, 60, 50,  9,  1,  3, 15,
		42, 56, 62, 52, 23,  7,  5, 17,
		32, 40, 54, 38, 31, 21, 19, 29
	);
	return float(t[idx]) / 64.0 - 0.5;
}

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	float threshold = clustered_dot(floor(FRAGCOORD.xy)) * dither_strength;
	col = clamp(floor(col * posterize_levels + threshold + 0.5) / posterize_levels, 0.0, 1.0);
	COLOR = vec4(col, 1.0);
}
