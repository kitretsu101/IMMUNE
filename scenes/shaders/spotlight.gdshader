shader_type canvas_item;
// Darkens everything except a rounded spotlight, and draws a glowing coloured outline around it.
uniform vec4 spot = vec4(0.0, 0.0, 0.0, 0.0); // x, y, w, h in pixels
uniform float corner = 14.0;
uniform vec2 viewport = vec2(1920.0, 1080.0);
uniform float dim = 0.74;
uniform vec3 outline : source_color = vec3(0.1, 0.9, 1.0);
uniform float show_outline = 1.0;

float box(vec2 p, vec2 c, vec2 h, float r) {
	vec2 q = abs(p - c) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * viewport;
	vec2 half_size = spot.zw * 0.5;
	float d = box(p, spot.xy + half_size, half_size, corner);
	float hole = 1.0 - smoothstep(-2.0, 10.0, d);
	vec2 v = UV - 0.5;
	float vig = smoothstep(0.2, 0.75, length(v));
	float base_a = clamp(dim * (1.0 - hole) + vig * 0.3, 0.0, 0.95);
	float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
	float line = exp(-pow(abs(d) / 2.6, 2.0));
	float glow = exp(-max(d, 0.0) / 18.0) * step(0.0, d) * 0.55 + exp(-max(-d, 0.0) / 10.0) * step(d, 0.0) * 0.25;
	float k = clamp((line + glow) * pulse, 0.0, 1.0) * show_outline;
	vec3 col = mix(vec3(0.01, 0.02, 0.06), outline * 1.4, k);
	COLOR = vec4(col, max(base_a * (1.0 - k * 0.5), k));
}
