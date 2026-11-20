shader_type spatial;

varying vec3 model_position;

void vertex() {
	model_position = VERTEX;
	float tail = smoothstep(0.015, 0.16, VERTEX.x);
	float stroke = TIME * 6.3 + MODEL_MATRIX[3].x;
	float wave = stroke - VERTEX.x * 33.0;
	VERTEX.z += sin(wave) * mix(0.002, 0.016, tail);
	VERTEX.y += cos(wave) * tail * 0.006;
	VERTEX.y += sin(stroke) * 0.004;
}

void fragment() {
	vec3 pink = vec3(0.83, 0.12, 0.33);
	float mottling = 0.5 + 0.5 * sin(model_position.x * 113.0 + sin(model_position.z * 87.0) * 2.0);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	ALBEDO = mix(pink * 0.65, pink, mottling);
	ROUGHNESS = 0.46;
	EMISSION = pink * (0.09 + rim * 0.38);
}
