// Block textures (v0.26.0): pixel-art 16 x 16 textures from a Texture2DArray,
// multiplied with the vertex colour. See docs/ART_BIBLE.md, section 6.
//
// Per-vertex data written by BlockMesh and TerrainGenerator:
//   UV  = texture position in metres (16 texels per metre; the sampler repeats).
//         Plant cards (sprite.gdshader) use 0..1 instead.
//   UV2 = (code, extra)
//     code  = layer + 1 (0 = no texture: characters, effects, old meshes)
//             + 256 * (side_layer + 1) on grass-edge bands
//     extra = 0 for tinted textures, -1 for full-colour ones,
//             on grass-edge bands: 1 + packed side colour (r*65536 + g*256 + b, sRGB 0..255)
// Meshes without UV2 read (0, 0) and stay exactly as before.

global uniform float block_textures;      // 1 = on, 0 = off (Settings "Block textures")
uniform sampler2DArray block_tex : filter_nearest_mipmap, repeat_enable;
uniform float tex_fade_start = 36.0;      // metres from the camera
uniform float tex_fade_end = 72.0;

const float TEX_GAIN = 1.25;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec3 unpack_rgb(float p) {
	float v = floor(p + 0.5);
	float r = floor(v / 65536.0);
	float g = floor((v - r * 65536.0) / 256.0);
	float b = v - r * 65536.0 - g * 256.0;
	return vec3(r, g, b) / 255.0;
}

// Linear albedo for a vertex colour (sRGB), texture position, UV2 and camera distance.
vec3 block_albedo(vec3 col_srgb, vec2 uv, vec2 meta, float dist) {
	vec3 base = srgb_to_linear(col_srgb);
	float code = floor(meta.x + 0.5);
	if (code < 0.5) {
		return base;
	}
	float layer = mod(code, 256.0) - 1.0;
	float side = floor(code / 256.0) - 1.0;
	float k = clamp(block_textures, 0.0, 1.0) * (1.0 - smoothstep(tex_fade_start, tex_fade_end, dist));
	vec2 gx = dFdx(uv);
	vec2 gy = dFdy(uv);
	if (side >= 0.0) {
		// Grass-edge band: alpha 1 = top part (grass, snow, moss), alpha 0 = the wall below.
		vec4 e = textureGrad(block_tex, vec3(uv.x, mod(uv.y, 0.5), layer), gx, gy);
		vec3 top = base * mix(vec3(1.0), srgb_to_linear(e.rgb * TEX_GAIN), k);
		if (block_textures <= 0.0) {
			return base;
		}
		vec3 wall_col = srgb_to_linear(unpack_rgb(meta.y - 1.0));
		vec3 s = textureGrad(block_tex, vec3(uv, side), gx, gy).rgb;
		vec3 wall = wall_col * mix(vec3(1.0), srgb_to_linear(s * TEX_GAIN), k);
		return mix(wall, top, step(0.5, e.a));
	}
	vec4 t = textureGrad(block_tex, vec3(uv, layer), gx, gy);
	if (meta.y < -0.5) {
		// Full colour (ores, berry bushes): the vertex colour only carries the face shade.
		// Far away / textures off: the texture's average colour (its 1 x 1 mip).
		vec3 avg = textureLod(block_tex, vec3(0.5, 0.5, layer), 4.0).rgb;
		return base * mix(srgb_to_linear(avg), srgb_to_linear(t.rgb), k);
	}
	return base * mix(vec3(1.0), srgb_to_linear(t.rgb * TEX_GAIN), k);
}
