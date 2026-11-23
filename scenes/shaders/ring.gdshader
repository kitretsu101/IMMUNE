shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// A flat glowing ring on the tile plane, drawn on a quad.

uniform vec3 ring_color : source_color = vec3(0.2, 0.9, 1.0);
uniform float energy = 1.2;
uniform float radius = 0.42;
uniform float thickness = 0.05;
uniform float alpha_scale = 1.0;
uniform float pulse_speed = 2.5;
uniform float pulse_amount = 0.25;
uniform float phase = 0.0;
uniform float arc = 1.0;
uniform float glow_scale = 1.0;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float ring = 1.0 - smoothstep(0.0, thickness, abs(r - radius * 2.0));
	float halo = (1.0 - smoothstep(0.0, thickness * 5.0, abs(r - radius * 2.0))) * 0.25;
	float ang = atan(p.y, p.x) / TAU + 0.5;
	float seg = 1.0 - step(arc, ang) * (1.0 - step(1.0, arc));
	float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed + phase);
	float a = (ring + halo) * seg * alpha_scale;
	ALBEDO = ring_color * energy * pulse * glow_scale;
	ALPHA = clamp(a, 0.0, 1.0);
}
