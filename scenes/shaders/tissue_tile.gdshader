shader_type spatial;
render_mode specular_schlick_ggx;
// Tissue tile. Glow hierarchy: grid and tissue stay under the bloom threshold (low),
// nutrients / chemicals / hints sit around it (medium), infections and selections punch above it (high).

uniform vec3 base_a : source_color = vec3(0.012, 0.06, 0.08);
uniform vec3 base_b : source_color = vec3(0.02, 0.11, 0.13);
uniform vec3 tissue_tint : source_color = vec3(0.04, 0.3, 0.33);
uniform vec3 edge_color : source_color = vec3(0.15, 0.62, 0.82);
uniform float edge_energy = 0.42;
uniform float infection = 0.0;
uniform vec3 infection_color : source_color = vec3(1.0, 0.07, 0.14);
uniform float damage = 0.0;
uniform vec3 damage_color : source_color = vec3(0.9, 0.38, 0.1);
uniform float destroyed = 0.0;
uniform float nutrient = 0.0;
uniform float chem = 0.0;
uniform float chem_immune = 0.0;
uniform float biofilm = 0.0;
uniform vec3 overlay_color : source_color = vec3(0.0);
uniform float overlay_amount = 0.0;
uniform float hover = 0.0;
uniform vec3 hover_color : source_color = vec3(0.2, 0.9, 1.0);
uniform float hint = 0.0;
uniform vec3 hint_color : source_color = vec3(0.2, 0.9, 1.0);
uniform float selected = 0.0;
uniform float glow_scale = 1.0;
uniform float seed = 0.0;

varying vec3 local_pos;
varying vec3 world_pos;
varying float top;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + 17.13));
}

// Returns vec3(F1, F2 - F1, cell id) for a voronoi pattern.
vec3 voronoi(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(cell + g);
			o = 0.5 + 0.42 * sin(TIME * 0.35 + 6.2831 * o);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = hash21(cell + g);
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec3(f1, f2 - f1, id);
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top = NORMAL.y;
}

void fragment() {
	vec2 p = local_pos.xz;
	float d = 0.0;
	for (int i = 0; i < 3; i++) {
		float a = float(i) * PI / 3.0;
		d = max(d, abs(dot(p, vec2(cos(a), sin(a)))));
	}
	float is_top = smoothstep(0.35, 0.8, top);
	float wave = 0.5 + 0.5 * sin(TIME * 0.7 - (world_pos.x * 0.3 + world_pos.z * 0.42) + seed * 6.0);
	float breathe = 0.5 + 0.5 * sin(TIME * 0.9 + seed * 12.0);

	vec3 v = voronoi(p * 3.4 + seed * 9.0);
	float membrane = 1.0 - smoothstep(0.0, 0.1, v.y);
	float nucleus = 1.0 - smoothstep(0.05, 0.2, v.x);

	vec3 albedo = mix(base_a, base_b, v.z * 0.6 + 0.2);
	albedo = mix(albedo, tissue_tint * 0.55, 0.5);
	albedo += membrane * tissue_tint * 0.35;
	albedo = mix(albedo, damage_color * 0.25, damage * 0.6);
	albedo = mix(albedo, vec3(0.06, 0.065, 0.075), destroyed * 0.85);
	albedo = mix(albedo, infection_color * 0.22, infection * 0.7);
	// Dark side walls.
	albedo = mix(base_a * 0.5, albedo, is_top);

	float edge = smoothstep(0.84, 0.975, d) * is_top;
	vec3 emit = vec3(0.0);
	// LOW: tissue texture and grid boundary.
	emit += tissue_tint * (membrane * 0.35 + nucleus * 0.12 * (0.6 + 0.4 * breathe)) * is_top;
	vec3 edge_tint = mix(edge_color, infection_color, clamp(infection * 0.85, 0.0, 1.0));
	emit += edge_tint * edge * edge_energy * (0.78 + 0.22 * wave);
	// Damaged and destroyed tissue.
	emit += damage_color * damage * (membrane * 0.7 + 0.1) * is_top;
	emit *= 1.0 - destroyed * 0.8;
	// HIGH: infection. Red veins along the cell membranes with a slow throb.
	float throb = 0.75 + 0.25 * sin(TIME * 2.2 + seed * 20.0);
	emit += infection_color * infection * (membrane * 1.1 + 0.1 + edge * 0.55) * throb * is_top;
	// MEDIUM: nutrients as electric yellow specks.
	vec2 sp = p * 7.0 + vec2(TIME * 0.12, -TIME * 0.09);
	float speck = step(0.962, hash21(floor(sp) + seed * 31.0)) * (0.55 + 0.45 * sin(TIME * 3.0 + hash21(floor(sp)) * 20.0));
	emit += vec3(1.0, 0.86, 0.18) * nutrient * (speck * 0.0 + 0.05) * is_top;
	// MEDIUM: chemical signals as drifting purple haze.
	float haze = 0.5 + 0.5 * sin(p.x * 4.0 + TIME * 0.8 + sin(p.y * 3.0 + TIME * 0.6) * 1.5);
	emit += vec3(0.65, 0.35, 1.0) * chem * (0.12 + 0.55 * haze * v.x) * is_top;
	emit += vec3(0.2, 0.8, 1.0) * chem_immune * (0.1 + 0.4 * haze * v.x) * is_top;
	// Biofilm: translucent magenta lattice.
	float lattice = 1.0 - smoothstep(0.0, 0.07, abs(fract(length(p * vec2(2.0, 1.2)) * 3.0 - TIME * 0.2) - 0.5) - 0.38);
	emit += vec3(0.95, 0.25, 0.85) * biofilm * (0.18 + membrane * 0.5 + lattice * 0.3) * is_top * 0.45;
	albedo = mix(albedo, vec3(0.3, 0.05, 0.28), clamp(biofilm * 0.18, 0.0, 0.5));
	// View-mode overlay and interaction states.
	emit += overlay_color * overlay_amount * (0.55 + 0.6 * membrane + 0.15 * breathe) * is_top;
	emit += hover_color * hover * (0.55 + edge * 1.6) * is_top;
	emit += hint_color * hint * (0.2 + 0.1 * breathe + edge * 1.0 + membrane * 0.25) * is_top;
	emit += vec3(0.4, 1.0, 1.0) * selected * (edge * 2.0 + 0.2 + 0.12 * breathe) * is_top;
	emit += edge_color * 0.05 * (1.0 - is_top);

	ALBEDO = albedo;
	ROUGHNESS = 0.38;
	SPECULAR = 0.55;
	METALLIC = 0.0;
	EMISSION = emit * glow_scale;
}
