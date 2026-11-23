shader_type canvas_item;

// Drowning tunnel-vision vignette. intensity 0.2 (mild edge) → 1.0 (aggressive
// tunnel that covers most of the screen), with a writhing, tentacle-like rim.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float beat_phase = 0.0;  // accumulated on the CPU so rate changes don't jump the beat
uniform vec4 tunnel_color : source_color = vec4(0.0, 0.02, 0.03, 0.5);

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;       // viewport size in px
	float aspect = res.x / res.y;
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);  // aspect-corrected, centred
	float dist = length(p);
	float ang = atan(p.y, p.x);

	float t = TIME;
	// Layered animated sines → writhing, tentacle-like edge.
	float wob =
		  sin(ang * 3.0  + t * 0.9) * 0.55
		+ sin(ang * 7.0  - t * 1.4) * 0.30
		+ sin(ang * 13.0 + t * 2.1) * 0.15;

	// Tunnel radius shrinks toward the centre as intensity rises.
	float radius  = mix(0.95, 0.14, intensity);
	float wob_amp = mix(0.04, 0.16, intensity);
	float edge    = mix(0.55, 0.34, intensity);
	radius += wob * wob_amp;
	// Heartbeat: the tunnel squeezes in on each beat; faster and harder as intensity rises.
	float beat = pow(max(sin(beat_phase), 0.0), 3.0);
	radius -= beat * 0.10 * intensity;

	// 0 in the clear centre → 1 at the dark rim.
	float v = smoothstep(radius, radius + edge, dist);
	float alpha = mix(tunnel_color.a, 0.9, intensity * intensity);  // rim goes near-opaque when deep
	COLOR = vec4(tunnel_color.rgb, v * alpha);
}
