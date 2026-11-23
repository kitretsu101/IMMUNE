shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// Ground aura under a nutrient pickup: soft pool of light, outward ripples and a slowly turning dashed ring.

uniform vec3 aura_color : source_color = vec3(1.0, 0.85, 0.2);
uniform float energy = 1.2;
uniform float glow_scale = 1.0;
uniform float collect = 0.0; // 0..1, ramps up when the pickup is taken: ripples speed up and flash

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float angle = atan(p.y, p.x);
	float pool = smoothstep(1.0, 0.0, r);
	pool = pool * pool * 0.55;
	float speed = 1.2 + collect * 5.0;
	float ripple = 0.5 + 0.5 * sin(r * 16.0 - TIME * speed * 2.0);
	ripple *= smoothstep(1.0, 0.15, r) * smoothstep(0.1, 0.3, r) * 0.5;
	float dash = step(0.5, fract(angle * 1.9099 + TIME * 0.35));
	float ring = (1.0 - smoothstep(0.0, 0.035, abs(r - 0.78))) * (0.4 + 0.6 * dash);
	float flash = collect * (1.0 - smoothstep(0.0, 0.25, abs(r - (0.2 + collect * 0.8)))) ;
	float a = pool + ripple + ring * 0.8 + flash;
	a *= smoothstep(1.0, 0.85, r);
	ALBEDO = aura_color * energy * (1.0 + collect) * glow_scale;
	ALPHA = clamp(a, 0.0, 1.0);
}
