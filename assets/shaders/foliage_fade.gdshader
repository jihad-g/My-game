// Vertex-coloured foliage that sways in the wind (Milestone 10). Height above
// the prop's base drives the bend, so trunks stay planted and crowns move.
// Milestone 18 art pass: the near-camera fade is a soft see-through blend
// instead of a grainy pixel pattern. Trees far from the camera stay fully
// solid (the depth pre-pass draws them like normal opaque blocks).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

global uniform float wind_strength;
global uniform vec2 wind_dir;
uniform float sway = 0.03;
uniform bool fade_near = false;
uniform float fade_min = 6.0;
uniform float fade_max = 11.0;
// The hero's chest (CameraRig sets it every frame). Tree parts inside a soft
// tube from the camera to the hero fade, so the hero is never hidden.
uniform vec3 focus_pos = vec3(0.0, -1000000.0, 0.0);
uniform float focus_radius = 2.6;

varying float v_depth;
varying vec3 v_world;

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
	v_world = wp;
}

void fragment() {
	ALBEDO = block_albedo(COLOR.rgb, UV, UV2, v_depth);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	float a = 1.0;
	if (fade_near) {
		a = clamp((v_depth - fade_min) / max(0.001, fade_max - fade_min), 0.0, 1.0);
		a = a * a * (3.0 - 2.0 * a);  // smooth in and out
		// Distance from this point to the camera -> hero line (only in front of the hero).
		vec3 cam = CAMERA_POSITION_WORLD;
		vec3 seg = focus_pos - cam;
		float len2 = max(dot(seg, seg), 0.0001);
		float t = dot(v_world - cam, seg) / len2;
		if (t > 0.0 && t < 0.97) {
			float d = length(v_world - (cam + seg * t));
			float tube = smoothstep(focus_radius * 0.55, focus_radius, d);
			a = min(a, tube);
		}
	}
	// A faint ghost stays so you can still see where the tree is.
	ALPHA = mix(0.16, 1.0, a);
}
