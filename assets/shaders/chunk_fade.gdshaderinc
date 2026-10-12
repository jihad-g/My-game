// Milestone 18d: chunks fade in with a fine dither instead of popping.
// ChunkManager keeps a small "fade map" around the player: one texel per chunk,
//   R = how far the chunk's ground has faded in (0..1),
//   G = how far its props (trees, rocks, plants, buildings) have faded in.
// chunk_fade_rect: xy = world position (m) of texel 0, z = size in metres,
// w = texels per side (0 = no fade map: everything fully drawn).
// fade_channel: 0 = ground, 1 = props (default), 2 = the old ground mesh of a
// chunk that changes detail - it disappears on exactly the pixels the new
// ground appears on, so there is never a hole or a double.

global uniform sampler2D chunk_fade;
global uniform vec4 chunk_fade_rect;
uniform int fade_channel = 1;

// 0..1 appear value of the chunk under a world position.
float chunk_appear(vec3 world) {
	if (chunk_fade_rect.w < 0.5) {
		return 1.0;
	}
	vec2 uv = (world.xz - chunk_fade_rect.xy) / chunk_fade_rect.z;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return 1.0;
	}
	vec2 v = texelFetch(chunk_fade, ivec2(uv * chunk_fade_rect.w), 0).rg;
	return fade_channel == 1 ? v.g : v.r;
}

bool appear_hidden(vec2 frag, vec3 world) {
	float a = chunk_appear(world);
	if (fade_channel != 2 && a >= 0.999) {
		return false;
	}
	const float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 px = ivec2(frag) % 4;
	float d = (bayer[px.y * 4 + px.x] + 0.5) / 16.0;
	return fade_channel == 2 ? d < a : d >= a;
}
