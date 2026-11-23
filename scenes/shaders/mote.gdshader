shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// Floating specks. Per-instance custom data: x = phase, y = presence (0..1), z = speed, w = size jitter.

uniform vec3 mote_color : source_color = vec3(1.0, 0.9, 0.25);
uniform float energy = 1.1;
uniform float drift = 0.14;
uniform float glow_scale = 1.0;

varying float vis;
varying float flicker;

void vertex() {
	float t = TIME * INSTANCE_CUSTOM.z + INSTANCE_CUSTOM.x * 6.2831;
	vec3 offset = vec3(sin(t) * drift, 0.18 + 0.1 * sin(t * 1.3), cos(t * 0.8) * drift);
	vis = INSTANCE_CUSTOM.y;
	flicker = 0.6 + 0.4 * sin(TIME * 3.0 + INSTANCE_CUSTOM.x * 20.0);
	float s = INSTANCE_CUSTOM.y * (0.7 + 0.6 * INSTANCE_CUSTOM.w);
	vec4 center = MODEL_MATRIX * vec4(offset, 1.0);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 pos = center.xyz + (right * VERTEX.x + up * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
}

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	float a = (1.0 - smoothstep(0.0, 1.0, d));
	a *= a;
	ALBEDO = mote_color * energy * glow_scale * flicker;
	ALPHA = a * vis;
}
