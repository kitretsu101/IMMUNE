shader_type spatial;
render_mode cull_disabled;

uniform sampler2D cell_color : source_color, filter_linear_mipmap;
uniform sampler2D cell_metallic_roughness : filter_linear_mipmap;
uniform float cut_height = 0.148;
varying float source_height;

void vertex() {
	source_height = VERTEX.y;
	vec2 radial = VERTEX.xz / vec2(0.15, 0.136);
	float radius = length(radial);
	if (radius > 0.0001) {
		float angle = atan(radial.y, radial.x);
		float side_angle = mod(angle + PI / 6.0, PI / 3.0) - PI / 6.0;
		float hex_edge = cos(PI / 6.0) / cos(side_angle);
		VERTEX.xz = (radial / radius) * pow(radius, 0.84) * hex_edge * 0.173;
	}
	VERTEX.y = VERTEX.y * 0.41 + 0.062;
	NORMAL = normalize(vec3(NORMAL.x, NORMAL.y / 0.41, NORMAL.z));
}

void fragment() {
	if (source_height > cut_height) {
		discard;
	}
	vec4 surface = texture(cell_metallic_roughness, UV);
	ALBEDO = texture(cell_color, UV).rgb;
	ROUGHNESS = clamp(surface.g, 0.28, 0.9);
	METALLIC = surface.b * 0.35;
}
