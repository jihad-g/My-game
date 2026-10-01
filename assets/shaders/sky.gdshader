// Stylized sky (Milestone 10): gradient, sun and moon discs with glow, moon
// phases, twinkling stars, drifting blocky clouds whose cover follows the
// weather. DayNightCycle and WeatherSystem drive the uniforms.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.25, 0.5, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.65, 0.8, 1.0);
uniform vec3 ground_color : source_color = vec3(0.35, 0.4, 0.45);
uniform vec3 sun_dir = vec3(0.0, 0.7, 0.7);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float sun_size = 0.035;
uniform vec3 moon_dir = vec3(0.0, -0.7, -0.7);
uniform float moon_phase = 0.5; // 0 new .. 0.5 full .. 1 new
uniform float night = 0.0;      // 0 day .. 1 night (stars, moon)
uniform float cloud_cover = 0.35;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_speed = 0.01;
uniform float storm = 0.0;      // darkens clouds
uniform float flash = 0.0;      // lightning

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, zenith_color, clamp(pow(max(h, 0.0), 0.6), 0.0, 1.0));
	col = mix(col, ground_color, smoothstep(0.0, -0.25, h));
	if (AT_CUBEMAP_PASS) {
		COLOR = col;
	} else {
		// Sun: disc + glow (the glow also warms the horizon at dusk).
		float sd = dot(d, normalize(sun_dir));
		float sun_disc = smoothstep(1.0 - sun_size * 0.02, 1.0 - sun_size * 0.015, sd);
		float sun_glow = pow(max(sd, 0.0), 24.0) * 0.45 + pow(max(sd, 0.0), 4.0) * 0.12;
		col += sun_color * (sun_disc * 2.5 + sun_glow) * (1.0 - storm * 0.8);

		// Stars (blocky, twinkling), only at night and above the horizon.
		if (night > 0.01 && h > 0.0) {
			vec2 sp = vec2(atan(d.x, d.z), asin(d.y)) * 160.0;
			vec2 cell = floor(sp);
			float star = step(0.985, hash(cell));
			float tw = 0.6 + 0.4 * sin(TIME * (1.5 + hash(cell + 3.1) * 4.0) + hash(cell) * 30.0);
			vec2 fp = fract(sp) - 0.5;
			star *= smoothstep(0.35, 0.1, max(abs(fp.x), abs(fp.y)));
			col += vec3(0.9, 0.92, 1.0) * star * tw * night * smoothstep(0.0, 0.25, h) * (1.0 - cloud_cover);
		}

		// Moon with phase: a lit disc minus an offset shadow disc.
		float md = dot(d, normalize(moon_dir));
		if (md > 0.99) {
			vec3 mdir = normalize(moon_dir);
			vec3 right = normalize(cross(mdir, vec3(0.0, 1.0, 0.0)));
			vec3 up = cross(right, mdir);
			vec2 uv = vec2(dot(d - mdir, right), dot(d - mdir, up)) / 0.045;
			float disc = smoothstep(1.0, 0.92, length(uv));
			float off = (moon_phase - 0.5) * 4.0;
			float shadow = smoothstep(1.0, 0.92, length(uv - vec2(off, 0.0)));
			float lit = disc * (1.0 - shadow * step(0.02, abs(moon_phase - 0.5)));
			float crater = 0.85 + 0.15 * vnoise(uv * 3.0);
			col = mix(col, vec3(0.92, 0.94, 1.0) * crater, lit * night);
			col += vec3(0.5, 0.55, 0.8) * pow(max(md, 0.0), 300.0) * 0.25 * night;
		}

		// Clouds on a flat layer above, pixel-stepped for the voxel look.
		if (h > 0.02) {
			vec2 cp = d.xz / (h + 0.12) * 1.6 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
			cp = floor(cp * 24.0) / 24.0;
			float n = fbm(cp * 1.4);
			float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.18, n);
			float shade = 1.0 - 0.35 * smoothstep(0.5, 1.0, n) - storm * 0.55;
			vec3 cc = cloud_color * shade;
			col = mix(col, cc, cover * smoothstep(0.02, 0.18, h) * 0.95);
		}
		col += vec3(0.75, 0.8, 1.0) * flash;
		COLOR = col;
	}
}
