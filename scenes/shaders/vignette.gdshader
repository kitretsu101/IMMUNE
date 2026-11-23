shader_type canvas_item;
// Dark cinematic vignette plus a faint scanning pulse. Sits above the 3D view, below the HUD.

uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform vec3 tint : source_color = vec3(0.01, 0.02, 0.06);

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.1;
	float d = length(p);
	float v = smoothstep(0.32, 0.85, d);
	float scan = 0.012 * sin(UV.y * 900.0 + TIME * 0.5);
	COLOR = vec4(tint, v * strength + scan * v);
}
