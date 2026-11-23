shader_type canvas_item;
// Darkens everything except a rounded spotlight rectangle, with a vignette towards the screen edges.
uniform vec4 spot = vec4(0.0, 0.0, 0.0, 0.0); // x, y, w, h in pixels
uniform vec2 viewport = vec2(1200.0, 800.0);
uniform float dim = 0.72;
uniform float amount = 1.0;

float box(vec2 p, vec2 c, vec2 h, float r) {
	vec2 q = abs(p - c) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * viewport;
	vec2 half_size = spot.zw * 0.5;
	float d = box(p, spot.xy + half_size, half_size, 14.0);
	float hole = 1.0 - smoothstep(-6.0, 26.0, d);
	vec2 v = UV - 0.5;
	float vig = smoothstep(0.25, 0.8, length(v));
	float a = (dim * (1.0 - hole) + vig * 0.25) * amount;
	COLOR = vec4(0.01, 0.02, 0.06, a);
}
