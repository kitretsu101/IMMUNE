shader_type canvas_item;
// Menu backdrop: deep navy with slow drifting micro-organism glows and a faint hex lattice.

uniform vec4 base : source_color = vec4(0.031, 0.043, 0.078, 1.0);
uniform float intensity = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float blob(vec2 uv, vec2 center, float r) {
	return smoothstep(r, 0.0, length(uv - center));
}

void fragment() {
	vec2 uv = UV;
	float aspect = 1.6;
	uv.x *= aspect;
	vec3 col = base.rgb;
	col += vec3(0.02, 0.05, 0.09) * (1.0 - length(UV - vec2(0.5, 0.45)));
	for (int i = 0; i < 14; i++) {
		float fi = float(i);
		float h = hash(vec2(fi, 3.7));
		vec2 c = vec2(fract(h * 7.1 + TIME * (0.006 + h * 0.01)) * aspect, fract(hash(vec2(fi, 9.1)) + sin(TIME * 0.05 * (1.0 + h) + fi) * 0.04));
		float r = 0.05 + 0.1 * hash(vec2(fi, 1.3));
		vec3 tint = i % 3 == 0 ? vec3(0.1, 1.0, 0.5) : (i % 3 == 1 ? vec3(0.15, 0.85, 1.0) : vec3(0.6, 0.35, 1.0));
		col += tint * blob(uv, c, r) * 0.1 * intensity * (0.7 + 0.3 * sin(TIME * (0.5 + h) + fi));
	}
	// hex lattice
	vec2 hp = UV * vec2(aspect * 14.0, 14.0);
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(hp, r) - h;
	vec2 b = mod(hp - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	float hex = max(dot(abs(g), normalize(vec2(1.0, 1.7320508))), abs(g).x);
	float line = smoothstep(0.43, 0.5, hex);
	col += vec3(0.1, 0.4, 0.6) * line * 0.07;
	// dust
	vec2 dp = UV * vec2(aspect * 90.0, 90.0) + vec2(TIME * 0.4, TIME * 0.2);
	vec2 dcell = floor(dp);
	vec2 dlocal = fract(dp) - 0.5 - (vec2(hash(dcell + 3.1), hash(dcell + 7.7)) - 0.5) * 0.5;
	float dust = step(0.985, hash(dcell)) * smoothstep(0.28, 0.0, length(dlocal)) * (0.5 + 0.5 * sin(TIME * 2.0 + hash(dcell) * 30.0));
	col += vec3(0.4, 0.8, 1.0) * dust * 0.3;
	COLOR = vec4(col, 1.0);
}
