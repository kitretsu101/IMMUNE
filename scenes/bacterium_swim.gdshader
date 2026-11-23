shader_type spatial;
// Neon bacterium. Swimming wobble in the vertex stage, mottled membrane and a hot fresnel rim in the fragment stage.
// Hue comes from the strain's antigen so strains can be told apart at a glance.

uniform vec3 body_color : source_color = vec3(0.12, 0.95, 0.5);
uniform float glow_scale = 1.0;
uniform float rim_energy = 2.0;
uniform float body_energy = 0.35;
uniform float wobble = 1.0;
uniform float speed = 6.3;
uniform float phase = 0.0;
uniform float boost = 0.0;

varying vec3 model_position;

void vertex() {
	model_position = VERTEX;
	float tail = smoothstep(0.015, 0.16, VERTEX.x);
	float stroke = TIME * speed + phase;
	float wave = stroke - VERTEX.x * 33.0;
	VERTEX.z += sin(wave) * mix(0.002, 0.016, tail) * wobble;
	VERTEX.y += cos(wave) * tail * 0.006 * wobble;
	VERTEX.y += sin(stroke) * 0.004 * wobble;
}

void fragment() {
	float mottling = 0.5 + 0.5 * sin(model_position.x * 113.0 + sin(model_position.z * 87.0) * 2.0);
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.2);
	float beat = 1.0 + 0.25 * sin(TIME * 2.6 + phase * 1.7) + boost;
	ALBEDO = mix(body_color * 0.35, body_color * 0.8, mottling);
	ROUGHNESS = 0.4;
	EMISSION = body_color * (body_energy * (0.5 + 0.5 * mottling) + rim * rim_energy) * beat * glow_scale;
}
