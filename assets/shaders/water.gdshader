// Stylized water (Milestone 10): gentle waves, blocky ripple bands, a brighter
// rim at grazing angles, sun glints and rain rings. World-space, so the per-
// column quads of every chunk join seamlessly.
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

global uniform float wind_strength;
global uniform float rain_amount;
uniform vec3 shallow : source_color = vec3(0.32, 0.7, 0.95);
uniform vec3 deep : source_color = vec3(0.12, 0.38, 0.72);
uniform float alpha = 0.68;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float amp = 0.035 + wind_strength * 0.05;
	VERTEX.y += (sin(wp.x * 0.7 + TIME * 1.3) + sin(wp.z * 0.9 + TIME * 1.1)) * amp;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 cell = floor(wp.xz * 2.0) / 2.0;
	float band = sin(cell.x * 0.8 + cell.y * 0.6 + TIME * 1.5) * 0.5 + 0.5;
	vec3 col = mix(deep, shallow, 0.35 + band * 0.25);
	// Sparkles on the ripple tops.
	float glint = step(0.985, hash(cell + floor(TIME * 2.0))) * band;
	col += vec3(0.6) * glint;
	// Rain rings: random cells pulse.
	if (rain_amount > 0.01) {
		float r = hash(cell * 1.7 + floor(TIME * 6.0));
		col += vec3(0.25) * step(1.0 - rain_amount * 0.08, r);
	}
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = col + vec3(0.25, 0.3, 0.35) * fres;
	ALPHA = clamp(alpha + fres * 0.25, 0.0, 0.95);
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	METALLIC = 0.0;
}
