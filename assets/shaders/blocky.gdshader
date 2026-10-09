// Vertex-coloured blocks with pixel-art textures (v0.26.0). Replaces the old
// StandardMaterial3D "vertex_color" material: same light response (rough,
// low specular, sRGB vertex colours), plus the block texture when the mesh has
// UV2 data. Characters and effects have no UV2 and look exactly as before.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/block_texture.gdshaderinc"

varying float v_dist;

void vertex() {
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	ALBEDO = block_albedo(COLOR.rgb, UV, UV2, v_dist);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
