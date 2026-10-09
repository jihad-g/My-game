// Vertex-coloured foliage that sways in the wind (Milestone 10). Height above
// the prop's base drives the bend, so trunks stay planted and crowns move.
// Optional pixel-dither fade near the camera (trees between camera and player).
// (Milestone 18 art pass: trees now use foliage_fade.gdshader, a soft
// see-through fade; this dither path is kept for old saves/materials.)
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float wind_strength;
global uniform vec2 wind_dir;
uniform float sway = 0.03;
uniform bool fade_near = false;
uniform float fade_min = 6.0;
uniform float fade_max = 11.0;

varying float v_depth;

// v0.26.0: leaves, bark and bushes get pixel-art block textures (UV/UV2 from BlockMesh).
#include "res://assets/shaders/block_texture.gdshaderinc"

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(wp.y - base.y, 0.0);
	float ph = base.x * 0.37 + base.z * 0.23;
	float gust = sin(TIME * 1.6 + ph) * 0.6 + sin(TIME * 3.3 + ph * 1.9) * 0.25;
	float w = 0.35 + wind_strength;
	vec2 bend = normalize(wind_dir + vec2(0.0001)) * (gust * w + wind_strength * 0.6) * sway * h * h;
	wp.xz += bend;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	v_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	ALBEDO = block_albedo(COLOR.rgb, UV, UV2, v_depth);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	if (fade_near) {
		float a = clamp((v_depth - fade_min) / max(0.001, fade_max - fade_min), 0.0, 1.0);
		const float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		ivec2 px = ivec2(FRAGCOORD.xy) % 4;
		if (a < (bayer[px.y * 4 + px.x] + 0.5) / 16.0) {
			discard;
		}
	}
}
