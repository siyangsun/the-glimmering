shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float t = blur_amount * blur_amount;

	if (t < 0.005) {
		COLOR = texture(screen_texture, SCREEN_UV);
		return;
	}

	float r = t * 0.18;
	float s07 = 0.7071;

	vec4 col  = texture(screen_texture, SCREEN_UV) * 3.0;
	float tot = 3.0;

	float r1 = r * 0.35;
	col += texture(screen_texture, SCREEN_UV + vec2( r1,      0.0));
	col += texture(screen_texture, SCREEN_UV + vec2(-r1,      0.0));
	col += texture(screen_texture, SCREEN_UV + vec2( 0.0,     r1));
	col += texture(screen_texture, SCREEN_UV + vec2( 0.0,    -r1));
	col += texture(screen_texture, SCREEN_UV + vec2( r1*s07,  r1*s07));
	col += texture(screen_texture, SCREEN_UV + vec2(-r1*s07,  r1*s07));
	col += texture(screen_texture, SCREEN_UV + vec2( r1*s07, -r1*s07));
	col += texture(screen_texture, SCREEN_UV + vec2(-r1*s07, -r1*s07));
	tot += 8.0;

	float r2 = r * 0.65;
	col += texture(screen_texture, SCREEN_UV + vec2( r2,      0.0));
	col += texture(screen_texture, SCREEN_UV + vec2(-r2,      0.0));
	col += texture(screen_texture, SCREEN_UV + vec2( 0.0,     r2));
	col += texture(screen_texture, SCREEN_UV + vec2( 0.0,    -r2));
	col += texture(screen_texture, SCREEN_UV + vec2( r2*s07,  r2*s07));
	col += texture(screen_texture, SCREEN_UV + vec2(-r2*s07,  r2*s07));
	col += texture(screen_texture, SCREEN_UV + vec2( r2*s07, -r2*s07));
	col += texture(screen_texture, SCREEN_UV + vec2(-r2*s07, -r2*s07));
	tot += 8.0;

	col += texture(screen_texture, SCREEN_UV + vec2( r,       0.0));
	col += texture(screen_texture, SCREEN_UV + vec2(-r,       0.0));
	col += texture(screen_texture, SCREEN_UV + vec2( 0.0,     r));
	col += texture(screen_texture, SCREEN_UV + vec2( 0.0,    -r));
	col += texture(screen_texture, SCREEN_UV + vec2( r*s07,   r*s07));
	col += texture(screen_texture, SCREEN_UV + vec2(-r*s07,   r*s07));
	col += texture(screen_texture, SCREEN_UV + vec2( r*s07,  -r*s07));
	col += texture(screen_texture, SCREEN_UV + vec2(-r*s07,  -r*s07));
	tot += 8.0;

	COLOR = col / tot;
}
