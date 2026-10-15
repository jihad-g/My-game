shader_type spatial;
// cull_disabled: ragged hems show the inside of the cloth.
render_mode cull_disabled;
// Style preview only (tests/style_preview.gd): pixel-art detail painted on
// plain boxes, 16 pixels per metre (docs/ART_BIBLE.md rule 1). Each box gets
// its own material with its half size, so the pixel grid lines up with its edges.

uniform vec3 half_size = vec3(0.5);
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 dark_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0);
uniform float pattern = 0.0;
uniform float seed = 0.0;
uniform float glow = 0.0;
uniform float metal = 0.0;
uniform float rag = 0.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec3 n = normalize(ln);
	vec3 an = abs(n);
	vec3 cells = max(vec3(1.0), floor(half_size * 32.0 + 0.5));
	vec3 p = (lp - n * 0.002 + half_size) / (half_size * 2.0) * cells;
	vec3 c = clamp(floor(p), vec3(0.0), cells - 1.0);
	float r = hash3(c + vec3(seed * 17.0) + n * 3.1);
	float vy = (c.y + 0.5) / cells.y;
	int pat = int(pattern + 0.5);

	// Ragged hem: columns end at different heights (capes, skirts, rags).
	if (rag > 0.0 && an.y < 0.5) {
		vec3 col_id = c;
		col_id.y = 0.0;
		float cut = hash3(col_id + vec3(seed * 5.0, 7.0, 3.0)) * rag;
		if (vy < cut) {
			discard;
		}
	}

	vec3 col = base_color.rgb;
	float emit = 0.0;
	if (pat == 0) { // plain, soft big patches + light noise
		float big = hash3(floor(c / 3.0) + vec3(seed));
		col *= 0.93 + 0.08 * big + 0.06 * r;
	} else if (pat == 1) { // metal: diagonal sheen bands
		float d = c.x + c.y * 1.0 + c.z;
		float band = fract(d / 10.0 + seed * 0.37);
		col = mix(dark_color.rgb, base_color.rgb, smoothstep(0.0, 0.45, band));
		if (band > 0.78 && band < 0.9) {
			col = mix(col, accent_color.rgb, 0.75);
		}
		col *= 0.95 + 0.08 * r;
	} else if (pat == 2) { // wood: grain along the longest axis
		vec3 g = c;
		if (cells.y >= cells.x && cells.y >= cells.z) { g.y = floor(c.y / 6.0); }
		else if (cells.x >= cells.z) { g.x = floor(c.x / 6.0); }
		else { g.z = floor(c.z / 6.0); }
		float s = hash3(g + vec3(seed));
		col = mix(dark_color.rgb, base_color.rgb, step(0.4, s)) * (0.94 + 0.08 * r);
	} else if (pat == 3) { // bone: pale with a few cracks and darker joints
		col *= 0.95 + 0.06 * r;
		if (r > 0.9) { col = mix(col, dark_color.rgb, 0.7); }
	} else if (pat == 4) { // cloth: soft weave
		float w = mod(c.x + c.y + c.z, 2.0);
		col *= (w < 0.5 ? 0.95 : 1.03) * (0.93 + 0.08 * r);
		if (mod(c.y, 5.0) < 0.5) { col = mix(col, dark_color.rgb, 0.45); }
	} else if (pat == 5) { // leather: speckles and stitched rows
		col *= 0.93 + 0.09 * r;
		if (r > 0.85) { col = mix(col, dark_color.rgb, 0.6); }
		if (mod(c.y, 4.0) < 0.5 && mod(c.x + c.z, 2.0) < 0.5) { col = mix(col, accent_color.rgb, 0.5); }
	} else if (pat == 6) { // hair / fur: vertical strands
		vec3 s = c;
		s.y = floor(c.y / 3.0);
		float k = hash3(s + vec3(seed));
		col = mix(dark_color.rgb, base_color.rgb, step(0.35, k)) * (0.95 + 0.07 * r);
	} else if (pat == 7) { // glow: emissive with a bright core
		col *= 0.9 + 0.2 * r;
		emit = glow;
	} else if (pat == 8) { // dark cloth with glowing specks (cursed cloak)
		float big = hash3(floor(c / 3.0) + vec3(seed));
		col = mix(dark_color.rgb, base_color.rgb, step(0.45, big)) * (0.9 + 0.12 * r);
		if (r > 0.965) { col = accent_color.rgb; emit = glow; }
		else if (r > 0.91) { col = mix(col, accent_color.rgb, 0.35); }
	} else if (pat == 9) { // teeth: light columns with dark gaps
		col = mod(c.x + c.z, 2.0) < 0.5 ? base_color.rgb : dark_color.rgb;
	} else if (pat == 10) { // tattooed skin: dark zigzag lines
		col *= 0.95 + 0.06 * r;
		float zig = mod(c.y + abs(mod(c.x + c.z, 4.0) - 2.0), 5.0);
		if (zig < 0.5 && r > 0.25) { col = mix(col, dark_color.rgb, 0.85); }
	} else if (pat == 11) { // wrapped grip: diagonal bands
		col = mod(c.y + c.x + c.z, 4.0) < 2.0 ? base_color.rgb : dark_color.rgb;
		col *= 0.95 + 0.07 * r;
	} else if (pat == 12) { // patina: copper with green verdigris patches
		float big = hash3(floor(c / 3.0) + vec3(seed));
		col *= 0.93 + 0.1 * r;
		if (big > 0.62) { col = mix(col, accent_color.rgb, 0.85) * (0.9 + 0.15 * r); }
	} else if (pat == 13) { // woven straw
		float w = mod(floor(c.x / 2.0) + floor(c.z / 2.0) + floor(c.y / 2.0), 2.0);
		col = (w < 1.0 ? base_color.rgb : dark_color.rgb) * (0.9 + 0.15 * r);
	}

	// Pixel outlines: light on the top/left edges, dark on the bottom/right
	// (light from the top-left, docs/ART_BIBLE.md rule 4).
	bool top_face = n.y > 0.5;
	bool bottom_face = n.y < -0.5;
	if (!top_face && !bottom_face) {
		float right_c = an.x > 0.5 ? c.z : c.x;
		float right_n = an.x > 0.5 ? cells.z : cells.x;
		bool flip = (an.x > 0.5) ? (n.x < 0.0) : (n.z < 0.0);
		float left_d = flip ? right_n - 1.0 - right_c : right_c;
		float right_d = right_n - 1.0 - left_d;
		if (c.y > cells.y - 1.5) { col *= 1.14; }
		else if (left_d < 0.5) { col *= 1.07; }
		else if (c.y < 0.5 || right_d < 0.5) { col *= 0.76; }
		// Soft shade toward the bottom of each part.
		col *= mix(0.84, 1.0, vy);
	} else if (top_face) {
		vec2 t = vec2(c.x, c.z);
		vec2 tn = vec2(cells.x, cells.z);
		if (t.x < 0.5 || t.y < 0.5) { col *= 1.1; }
		else if (t.x > tn.x - 1.5 || t.y > tn.y - 1.5) { col *= 0.84; }
		col *= 1.06;
	} else {
		col *= 0.7;
	}

	ALBEDO = col;
	ROUGHNESS = mix(0.9, 0.38, metal);
	METALLIC = metal * 0.3;
	SPECULAR = 0.35 + metal * 0.3;
	EMISSION = col * emit;
}
