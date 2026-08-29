shader_type canvas_item;

uniform float wet_amount : hint_range(0.0, 1.0) = 0.0;

vec2 hash2(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.xx + p.yx) * p.xy);
}

// Returns (total coverage, coverage of blobs randomly flagged dark ~10%).
vec2 splash_layer(vec2 uv, float density, float max_active,
		float anim_speed, float blob_r, vec2 seed, float blur_inner) {
	vec2 g     = uv * density;
	vec2 cell  = floor(g);
	vec2 local = fract(g);
	float result = 0.0;
	float result_dark = 0.0;

	for (int dx = -1; dx <= 1; dx++) {
		for (int dy = -1; dy <= 1; dy++) {
			vec2 c = cell + vec2(float(dx), float(dy));
			vec2 h = hash2(c + seed);
			bool is_dark = hash2(c + seed + vec2(31.7, 17.3)).x < 0.10;

			float cell_alpha = 0.0;
			if (h.x <= max_active) {
				float activate_at = h.x / max_active;
				cell_alpha = smoothstep(activate_at, activate_at + 0.15, wet_amount);
			}

			if (cell_alpha > 0.001) {
				float phase  = h.y * 6.283 + TIME * anim_speed;
				vec2 center  = h * 0.4 + 0.3
					+ vec2(sin(phase), cos(phase * 1.3 + 1.0)) * 0.035;

				vec2 off  = local + vec2(float(dx), float(dy)) - center;
				off      /= vec2(0.5 + h.y * 0.7, 0.35 + h.x * 0.5);
				float dist = length(off);

				float blob = (1.0 - smoothstep(blob_r * blur_inner, blob_r, dist)) * cell_alpha;
				result = max(result, blob);
				if (is_dark) {
					result_dark = max(result_dark, blob);
				}
			}
		}
	}
	return vec2(result, result_dark);
}

void fragment() {
	if (wet_amount > 0.001) {
		vec2 uv = UV;
		// Sharp at low damage (0.55), very soft at full damage (0.05).
		float blur_inner = mix(0.55, 0.05, wet_amount);

		// Layer 1: large sparse blobs — appear early.
		vec2 s1 = splash_layer(uv, 5.5, 0.72, 0.05, 0.22, vec2(0.00, 0.00), blur_inner);
		// Layer 2: medium blobs — phase in after ~10% damage.
		vec2 s2 = splash_layer(uv, 8.5, 0.58, 0.09, 0.17, vec2(4.13, 7.29), blur_inner)
		           * smoothstep(0.08, 0.25, wet_amount);
		// Layer 3: small droplets — phase in after ~35% damage.
		vec2 s3 = splash_layer(uv, 13.0, 0.45, 0.13, 0.12, vec2(1.87, 3.64), blur_inner)
		           * smoothstep(0.32, 0.55, wet_amount);

		float mask      = clamp(s1.x + s2.x * 0.85 + s3.x * 0.70, 0.0, 1.0);
		float dark_mask = clamp(s1.y + s2.y * 0.85 + s3.y * 0.70, 0.0, 1.0);

		if (mask > 0.001) {
			float grain      = hash2(floor(uv * 24.0 + TIME * 0.04)).x * 0.08;
			float brightness = 0.85 + grain;
			vec3 light_col = vec3(brightness, brightness, brightness + 0.04);
			vec3 dark_col  = vec3(0.14, 0.18, 0.26);
			// Blend toward dark where a dark-flagged blob covers this pixel.
			vec3 col = mix(light_col, dark_col, clamp(dark_mask / mask, 0.0, 1.0));
			COLOR = vec4(col, mask * 0.88);
		} else {
			COLOR = vec4(0.0);
		}
	} else {
		COLOR = vec4(0.0);
	}
}
