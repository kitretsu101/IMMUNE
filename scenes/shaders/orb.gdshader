shader_type spatial;
render_mode unshaded, cull_back;
// Nutrient pickup orb. Medium glow tier.

uniform vec3 orb_color : source_color = vec3(1.0, 0.85, 0.15);
uniform float energy = 2.0;
uniform float glow_scale = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float shimmer = 0.9 + 0.1 * sin(TIME * 4.0);
	ALBEDO = orb_color * energy * (0.6 + 1.0 * fres) * shimmer * glow_scale;
}
