shader_type canvas_item;

uniform float wet_amount : hint_range(0.0, 1.0) = 0.0;

vec2 hash2(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.xx + p.yx) * p.xy);
}

float splash_layer(vec2 uv, float density, float max_active,
		float anim_speed, float blob_r, vec2 seed, float blur_inner) {
	vec2 g     = uv * density;
	vec2 cell  = floor(g);
	vec2 local = fract(g);
	float result = 0.0;

	for (int dx = -1; dx <= 1; dx++) {
		for (int dy = -1; dy <= 1; dy++) {
			vec2 c = cell + vec2(float(dx), float(dy));
			vec2 h = hash2(c + seed);

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
			}
		}
	}
	return result;
}

void fragment() {
	if (wet_amount > 0.001) {
		vec2 uv = UV;
		// Sharp at low damage (0.55), very soft at full damage (0.05).
		float blur_inner = mix(0.55, 0.05, wet_amount);

		// Layer 1: large sparse blobs — appear early.
		float s1 = splash_layer(uv, 4.5, 0.55, 0.05, 0.22, vec2(0.00, 0.00), blur_inner);
		// Layer 2: medium blobs — phase in after ~10% damage.
		float s2 = splash_layer(uv, 7.0, 0.40, 0.09, 0.17, vec2(4.13, 7.29), blur_inner)
		           * smoothstep(0.08, 0.25, wet_amount);
		// Layer 3: small droplets — phase in after ~35% damage.
		float s3 = splash_layer(uv, 11.0, 0.28, 0.13, 0.12, vec2(1.87, 3.64), blur_inner)
		           * smoothstep(0.32, 0.55, wet_amount);

		float mask = clamp(s1 + s2 * 0.85 + s3 * 0.70, 0.0, 1.0);

		if (mask > 0.001) {
			float grain      = hash2(floor(uv * 24.0 + TIME * 0.04)).x * 0.08;
			float brightness = 0.85 + grain;
			COLOR = vec4(brightness, brightness, brightness + 0.04, mask * 0.88);
		} else {
			COLOR = vec4(0.0);
		}
	} else {
		COLOR = vec4(0.0);
	}
}
