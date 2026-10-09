// Textured blocks that fade softly near the camera (walls and big props between
// the camera and the hero). Same as blocky.gdshader plus the soft distance fade
// that the old StandardMaterial3D occluder had (pixel alpha + depth pre-pass).
// Materials.set_camera_fade() sets fade_min / fade_max every frame.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

#include "res://assets/shaders/block_texture.gdshaderinc"

uniform float fade_min = 6.0;
uniform float fade_max = 11.0;

varying float v_dist;

void vertex() {
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	ALBEDO = block_albedo(COLOR.rgb, UV, UV2, v_dist);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	float a = clamp((v_dist - fade_min) / max(0.001, fade_max - fade_min), 0.0, 1.0);
	ALPHA = a;
}
