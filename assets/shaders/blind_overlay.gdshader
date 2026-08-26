shader_type canvas_item;

uniform float blind_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	if (blind_amount > 0.001) {
		float s   = blind_amount * 0.030;
		float wx  = sin(UV.x * 13.5 + TIME * 2.6)               * s
		          + sin(UV.y *  9.0 - TIME * 1.9)               * s * 0.70
		          + sin(UV.x *  6.0 + UV.y * 8.0 + TIME * 1.4)  * s * 0.50;
		float wy  = sin(UV.y * 11.0 + TIME * 2.1)               * s
		          + sin(UV.x *  8.5 - TIME * 2.4)               * s * 0.70
		          + sin(UV.y *  6.5 - UV.x * 7.0 + TIME * 1.8)  * s * 0.50;

		vec4 screen_col  = texture(screen_texture, SCREEN_UV + vec2(wx, wy));
		vec3 water_col   = vec3(0.01, 0.04, 0.14);
		COLOR = vec4(mix(screen_col.rgb, water_col, blind_amount * 0.88), 1.0);
	} else {
		COLOR = vec4(0.0);
	}
}
