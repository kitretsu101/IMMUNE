shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;
// Additive fresnel rim laid over an organism model. High-glow tier: values above ~1.0 bloom.

uniform vec3 rim_color : source_color = vec3(0.16, 0.9, 1.0);
uniform float rim_energy = 1.7;
uniform float rim_power = 2.2;
uniform float core_fill = 0.1;
uniform float pulse_speed = 2.0;
uniform float pulse_amount = 0.3;
uniform float phase = 0.0;
uniform float boost = 0.0;
uniform float glow_scale = 1.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed + phase) + boost;
	vec3 c = rim_color * rim_energy * (fresnel + core_fill) * pulse * glow_scale;
	ALBEDO = c;
	ALPHA = clamp(fresnel + core_fill, 0.0, 1.0);
}
