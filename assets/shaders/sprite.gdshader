// Small plants on two crossed cut-out cards (v0.26.0): flowers, grass tufts,
// reeds, herbs, mushrooms, crops. UV = 0..1 across the card, UV2.x = layer + 1.
// The top of the card sways in the wind like foliage.gdshader.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

global uniform float wind_strength;
global uniform vec2 wind_dir;
uniform sampler2DArray block_tex : filter_nearest, repeat_disable;
uniform float sway = 0.25;
uniform float emission = 0.0;      // glowing plants (glowcap, moonpetal)

varying float v_layer;
// Milestone 28: seasons (see block_texture.gdshaderinc). Grass tufts and ferns turn
// olive-gold in autumn and dull in winter; snow dusts the tops of all small plants.
global uniform vec4 season_mix;
global uniform float snow_cover;
// Milestone 18d: fades in with its chunk.
#include "res://assets/shaders/chunk_fade.gdshaderinc"

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(wp.y - base.y, 0.0);
	float ph = base.x * 0.37 + base.z * 0.23;
	float gust = sin(TIME * 1.6 + ph) * 0.6 + sin(TIME * 3.3 + ph * 1.9) * 0.25;
	float w = 0.35 + wind_strength;
	wp.xz += normalize(wind_dir + vec2(0.0001)) * (gust * w + wind_strength * 0.6) * sway * h * h;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	v_layer = floor(UV2.x + 0.5) - 1.0;
	// Cards face the light like the ground, not like walls (no dark backs).
	NORMAL = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	if (appear_hidden(FRAGCOORD.xy, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz)) {
		discard;
	}
	vec4 t = texture(block_tex, vec3(UV, v_layer));
	vec3 tint = srgb_to_linear(COLOR.rgb);
	// Tinted sprites (tufts, ferns) carry 0.8 grey; full-colour ones are real colours.
	vec3 c = UV2.y < -0.5 ? srgb_to_linear(t.rgb) : srgb_to_linear(t.rgb * 1.25);
	vec3 col = tint * c;
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	if (UV2.y >= -0.5) {
		float green = smoothstep(0.02, 0.12, COLOR.g - max(COLOR.r, COLOR.b));
		vec3 gold = srgb_to_linear(vec3(0.66, 0.6, 0.26));
		col = mix(col, gold * (lum / 0.31) * 1.2, season_mix.z * green * 0.6);
		col = mix(col, vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))) * vec3(1.06, 1.0, 0.86), season_mix.w * green * 0.5);
		col = mix(col, vec3(0.78, 0.82, 0.88), snow_cover * green * clamp(1.1 - UV.y, 0.0, 1.0) * 0.8);
	} else if (emission <= 0.0) {
		col = mix(col, vec3(0.78, 0.82, 0.88), snow_cover * clamp(0.8 - UV.y, 0.0, 1.0) * 0.45);
	}
	ALBEDO = col;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	EMISSION = col * emission;
}
