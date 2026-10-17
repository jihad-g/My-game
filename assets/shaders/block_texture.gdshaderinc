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
// v0.26.0 tuning: how strongly the pixel detail shows (1 = full art-bible contrast).
// Lower = calmer ground. Detail is also divided by the texture's own average,
// so a texture can make a block lighter or darker in spots but never darker overall.
uniform float tex_strength = 0.55;
// Small lift for textured blocks (dark specks make textured ground read darker).
uniform float tex_brightness = 1.08;

const float TEX_GAIN = 1.25;

#include "res://assets/shaders/chunk_fade.gdshaderinc"

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

// Linear multiplier for a tinted texel, normalised by the layer's average colour
// (its 1 x 1 mip) so the block keeps its colour on average.
vec3 detail(vec3 texel, float layer) {
	vec3 avg = textureLod(block_tex, vec3(0.5, 0.5, layer), 4.0).rgb;
	return srgb_to_linear(texel * TEX_GAIN) / max(srgb_to_linear(avg * TEX_GAIN), vec3(0.02));
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
		vec3 top = base * mix(vec3(1.0), srgb_to_linear(e.rgb * TEX_GAIN) * tex_brightness, k * tex_strength);
		if (block_textures <= 0.0) {
			return base;
		}
		vec3 wall_col = srgb_to_linear(unpack_rgb(meta.y - 1.0));
		vec3 s = textureGrad(block_tex, vec3(uv, side), gx, gy).rgb;
		vec3 wall = wall_col * mix(vec3(1.0), detail(s, side) * tex_brightness, k * tex_strength);
		return mix(wall, top, step(0.5, e.a));
	}
	vec4 t = textureGrad(block_tex, vec3(uv, layer), gx, gy);
	if (meta.y < -0.5) {
		// Full colour (ores, berry bushes): the vertex colour only carries the face shade.
		// Far away / textures off: the texture's average colour (its 1 x 1 mip).
		vec3 avg = textureLod(block_tex, vec3(0.5, 0.5, layer), 4.0).rgb;
		return base * mix(srgb_to_linear(avg), srgb_to_linear(t.rgb), k);
	}
	return base * mix(vec3(1.0), detail(t.rgb, layer) * tex_brightness, k * tex_strength);
}

// --- Seasons (Milestone 28) -----------------------------------------------------------
// WeatherSystem sets these every frame from Seasons (src/world/seasons.gd).
// season_mix = weights of (spring, summer, autumn, winter); snow_cover = snow on the grass.
// Only green, textured surfaces change (grass, leaves, bushes): characters, stone,
// wood and buildings keep their colours. Far terrain sets season_all (it has no UV2).
global uniform vec4 season_mix;
global uniform float snow_cover;
uniform bool season_all = false;

float season_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float season_lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// `alb` = linear albedo from block_albedo(), `col_srgb` = vertex colour, `uv`/`meta` = UV/UV2,
// world position and world normal. `foliage` = leaves (blossoms on all faces).
vec3 season_albedo(vec3 alb, vec3 col_srgb, vec2 uv, vec2 meta, vec3 wpos, vec3 wnormal, bool foliage) {
	float code = floor(meta.x + 0.5);
	if (!season_all && code < 0.5) {
		return alb;
	}
	float green = smoothstep(0.02, 0.12, col_srgb.g - max(col_srgb.r, col_srgb.b));
	if (code >= 256.0) {
		// Grass-edge band: only its grass part (texture alpha 1) changes, not the soil below.
		float layer = mod(code, 256.0) - 1.0;
		green *= step(0.5, textureLod(block_tex, vec3(uv.x, mod(uv.y, 0.5), layer), 0.0).a);
	}
	if (green <= 0.0) {
		return alb;
	}
	// Pines and spruces (blue-green) barely change colour.
	float conifer = smoothstep(0.0, 0.06, col_srgb.b - col_srgb.r);
	float up = smoothstep(0.55, 0.85, wnormal.y);
	float lum = season_lum(alb);
	vec3 c = alb;
	// Spring: fresher green and little blossoms (2 x 2 pixel dots, 8 per metre).
	float sp = season_mix.x;
	if (sp > 0.001) {
		c = mix(c, c * vec3(0.94, 1.1, 0.9), sp * green);
		vec3 cell = floor(wpos * 8.0 + 0.001);
		float chance = foliage ? 0.04 * (1.0 - conifer) : 0.011 * up;
		if (!season_all && season_hash(cell) < chance * sp * green) {
			float k = season_hash(cell + vec3(17.0, 3.0, 5.0));
			vec3 b = k < 0.3 ? vec3(1.0, 0.6, 0.75) : (k < 0.6 ? vec3(1.0, 0.97, 0.92) : (k < 0.85 ? vec3(1.0, 0.86, 0.3) : vec3(0.8, 0.65, 1.0)));
			c = srgb_to_linear(b) * 0.85;
		}
	}
	// Autumn: gold, orange and red crowns (one colour per ~4 m), olive-gold grass.
	float au = season_mix.z;
	if (au > 0.001) {
		vec3 tgt;
		if (foliage) {
			float k = season_hash(vec3(floor(wpos.xz / 3.5), 1.0));
			tgt = k < 0.35 ? vec3(0.9, 0.62, 0.14) : (k < 0.7 ? vec3(0.9, 0.42, 0.12) : (k < 0.88 ? vec3(0.74, 0.26, 0.14) : vec3(0.85, 0.75, 0.2)));
		} else {
			tgt = vec3(0.66, 0.6, 0.26);
		}
		vec3 tl = srgb_to_linear(tgt);
		vec3 turned = tl * (lum / max(season_lum(tl), 0.001)) * 1.25;
		c = mix(c, turned, au * green * (1.0 - conifer * 0.85) * (foliage ? 0.92 : 0.6));
	}
	// Winter: dull, dry green; snow on everything green that faces up.
	float wi = season_mix.w;
	if (wi > 0.001) {
		vec3 dull = vec3(season_lum(c)) * vec3(1.06, 1.0, 0.86);
		c = mix(c, dull, wi * green * (foliage ? 0.45 * (1.0 - conifer) : 0.5));
	}
	if (snow_cover > 0.001) {
		float speck = season_hash(floor(wpos * 16.0 + 0.001));
		vec3 snow = vec3(0.78, 0.82, 0.88) * (0.92 + 0.08 * speck);
		float s = snow_cover * up * green;
		// Patchy at the edges of the snow season: more snow in hollows of the noise.
		s *= smoothstep(0.0, 0.35, snow_cover * 1.3 - season_hash(vec3(floor(wpos.xz * 2.0), 9.0)) * 0.3);
		c = mix(c, snow, clamp(s, 0.0, 1.0));
	}
	return c;
}
