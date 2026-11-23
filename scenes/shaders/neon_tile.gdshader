shader_type spatial;

// Neon grid tile: near-black blue face with a glowing gray-blue hex outline.
uniform vec3 edge_color : source_color = vec3(0.42, 0.58, 0.85);
uniform float edge_energy = 2.0;
uniform float edge_start = 0.86;
uniform float glow_scale = 1.0;
uniform float hover : hint_range(0.0, 1.0) = 0.0;
uniform vec3 hover_color : source_color = vec3(0.3, 0.8, 1.0);
uniform vec3 face_color : source_color = vec3(0.02, 0.035, 0.1);
uniform vec3 face_glow : source_color = vec3(0.12, 0.24, 0.6);

varying vec2 plane_pos;

void vertex() {
	plane_pos = VERTEX.xz;
}

void fragment() {
	float d = 0.0;
	for (int i = 0; i < 3; i++) {
		float a = float(i) * PI / 3.0;
		d = max(d, abs(dot(plane_pos, vec2(cos(a), sin(a)))));
	}
	float edge = smoothstep(edge_start, 0.97, d);
	ALBEDO = mix(face_color, edge_color * 0.5, edge);
	ROUGHNESS = 0.5;
	EMISSION = face_glow + edge_color * edge_energy * edge;
	EMISSION += hover * hover_color * (1.6 + edge * 3.0);
	EMISSION *= glow_scale;
}
