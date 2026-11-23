shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix;
// Health bar with a bold complementary outline so it reads against any tile.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec3 fill_color : source_color = vec3(0.3, 1.0, 0.6);
uniform vec3 outline_color : source_color = vec3(1.0, 0.55, 0.15);
uniform float opacity = 1.0;
uniform float glow_scale = 1.0;
uniform vec2 bar_size = vec2(1.7, 0.34);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 px = UV * bar_size;
	float edge = min(min(px.x, bar_size.x - px.x), min(px.y, bar_size.y - px.y));
	float border = 1.0 - smoothstep(0.05, 0.065, edge);
	vec2 inner = (px - vec2(0.08)) / (bar_size - vec2(0.16));
	float bar = step(inner.x, fill);
	vec3 back = vec3(0.01, 0.02, 0.05);
	vec3 c = mix(back, fill_color * (1.0 + 0.3 * glow_scale), bar);
	c = mix(c, outline_color * (1.0 + 0.4 * glow_scale), border);
	ALBEDO = c;
	ALPHA = opacity;
}
