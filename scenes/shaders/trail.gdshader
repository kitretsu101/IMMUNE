shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform float energy = 1.5;
uniform float glow_scale = 1.0;

void fragment() {
	ALBEDO = COLOR.rgb * energy * glow_scale;
	ALPHA = COLOR.a;
}
