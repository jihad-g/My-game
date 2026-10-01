#!/usr/bin/env python3
"""Synthesizes every sound in the game (Milestone 10).

No samples, no downloads: each sound effect, ambience loop and music track is
built from oscillators, noise, envelopes, filters, plucked strings (Karplus-
Strong), FM bells and a small reverb, with fixed random seeds so the output is
identical on every run.

  assets/audio/sfx/*.wav        short effects (16-bit mono 22.05 kHz)
  assets/audio/ambience/*.ogg   seamless loops (wind, rain, birds, crickets, caves, sea, fire)
  assets/audio/music/*.ogg      looping tracks (day, night, town, combat, dungeon, boss, menu)

Run:  python3 tools/gen_audio.py [--only=sfx|ambience|music]   (needs ffmpeg for .ogg)
"""
import array, math, os, random, subprocess, sys, wave

SR = 22050
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio")
TAU = math.tau


# --- Building blocks ---------------------------------------------------------------

def silence(sec):
    return [0.0] * int(sec * SR)


def mix_into(dst, src, at=0.0, gain=1.0):
    o = int(at * SR)
    if o + len(src) > len(dst):
        dst.extend([0.0] * (o + len(src) - len(dst)))
    for i, v in enumerate(src):
        dst[o + i] += v * gain
    return dst


def env_adsr(n, a, d, s, r, sustain_level=0.6):
    """Envelope over n samples: attack, decay, sustain (rest), release (seconds)."""
    out = [0.0] * n
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    for i in range(n):
        if i < na:
            v = i / max(1, na)
        elif i < na + nd:
            v = 1.0 - (1.0 - sustain_level) * (i - na) / max(1, nd)
        else:
            v = sustain_level
        if i > n - nr:
            v *= max(0.0, (n - i) / max(1, nr))
        out[i] = v
    return out


def exp_env(n, decay):
    k = math.exp(-1.0 / max(1.0, decay * SR))
    out, v = [0.0] * n, 1.0
    for i in range(n):
        out[i] = v
        v *= k
    return out


def osc(freq, sec, kind="sine", phase=0.0, fm=None):
    n = int(sec * SR)
    out = [0.0] * n
    p = phase
    for i in range(n):
        f = freq(i / SR) if callable(freq) else freq
        p += f / SR
        x = p % 1.0
        if kind == "sine":
            v = math.sin(TAU * p)
        elif kind == "saw":
            v = 2.0 * x - 1.0
        elif kind == "square":
            v = 1.0 if x < 0.5 else -1.0
        elif kind == "tri":
            v = 4.0 * abs(x - 0.5) - 1.0
        else:
            v = 0.0
        out[i] = v
    return out


def noise(sec, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(sec * SR))]


def lowpass(sig, cutoff):
    """One-pole lowpass; cutoff may be a function of time."""
    out = [0.0] * len(sig)
    y = 0.0
    for i, x in enumerate(sig):
        c = cutoff(i / SR) if callable(cutoff) else cutoff
        a = 1.0 - math.exp(-TAU * c / SR)
        y += a * (x - y)
        out[i] = y
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, cutoff)
    return [x - l for x, l in zip(sig, lp)]


def bandpass(sig, lo, hi):
    return lowpass(highpass(sig, lo), hi)


def biquad_lp(sig, cutoff, q=0.9):
    w = TAU * cutoff / SR
    alpha = math.sin(w) / (2 * q)
    cw = math.cos(w)
    b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    out = [0.0] * len(sig)
    x1 = x2 = y1 = y2 = 0.0
    for i, x in enumerate(sig):
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out[i] = y
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def scale(sig, g):
    return [x * g for x in sig]


def pluck(freq, sec, rng, bright=0.5, decay=0.996):
    """Karplus-Strong plucked string (lute, harp, guitar)."""
    period = max(2, int(SR / freq))
    buf = [rng.uniform(-1, 1) for _ in range(period)]
    # Soften the excitation for a warmer tone.
    for _ in range(int((1.0 - bright) * 4)):
        buf = [(buf[i] + buf[i - 1]) * 0.5 for i in range(period)]
    n = int(sec * SR)
    out = [0.0] * n
    for i in range(n):
        v = buf[i % period]
        nxt = buf[(i + 1) % period]
        buf[i % period] = decay * 0.5 * (v + nxt)
        out[i] = v
    return out


def fm_bell(freq, sec, ratio=3.5, index=2.5, decay=0.8):
    n = int(sec * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        e = math.exp(-t / decay)
        out[i] = math.sin(TAU * freq * t + index * e * math.sin(TAU * freq * ratio * t)) * e
    return out


def pad(freq, sec, rng, voices=3, detune=0.006, cutoff=1400.0, a=0.6, r=0.8):
    sig = [0.0] * int(sec * SR)
    for v in range(voices):
        f = freq * (1.0 + (v - (voices - 1) / 2) * detune)
        s = osc(f, sec, "saw", phase=rng.random())
        for i in range(len(sig)):
            sig[i] += s[i] / voices
    sig = lowpass(lowpass(sig, cutoff), cutoff * 1.5)
    return mul(sig, env_adsr(len(sig), a, 0.3, 0, r, 0.85))


def kick(rng, sec=0.35):
    s = osc(lambda t: 45 + 110 * math.exp(-t * 35), sec, "sine")
    return mul(s, exp_env(len(s), 0.12))


def snare(rng, sec=0.25):
    nz = bandpass(noise(sec, rng), 900, 6000)
    body = osc(lambda t: 190 - 40 * t, sec, "tri")
    return [0.7 * a * e + 0.35 * b * e2 for a, b, e, e2 in zip(nz, body, exp_env(int(sec * SR), 0.07), exp_env(int(sec * SR), 0.04))]


def hat(rng, sec=0.07):
    nz = highpass(noise(sec, rng), 6000)
    return mul(nz, exp_env(len(nz), 0.018))


def tom(freq, rng, sec=0.4):
    s = osc(lambda t: freq * (1 + 0.6 * math.exp(-t * 20)), sec, "sine")
    return mul(s, exp_env(len(s), 0.15))


def reverb(sig, room=0.82, wet=0.28, damp=0.35):
    """Small Schroeder reverb: 4 damped combs + 2 allpasses."""
    combs = [1557, 1617, 1491, 1422]
    combs = [int(c * SR / 44100) for c in combs]
    aps = [int(225 * SR / 44100), int(556 * SR / 44100)]
    n = len(sig)
    acc = [0.0] * n
    for d in combs:
        buf = [0.0] * d
        idx = 0
        filt = 0.0
        for i in range(n):
            y = buf[idx]
            filt = y * (1 - damp) + filt * damp
            buf[idx] = sig[i] + filt * room
            idx = (idx + 1) % d
            acc[i] += y * 0.25
    for d in aps:
        buf = [0.0] * d
        idx = 0
        for i in range(n):
            bo = buf[idx]
            x = acc[i]
            y = -x + bo
            buf[idx] = x + bo * 0.5
            idx = (idx + 1) % d
            acc[i] = y
    return [d * (1 - wet) + w * wet for d, w in zip(sig, acc)]


def normalize(sig, peak=0.9):
    m = max(1e-9, max(abs(x) for x in sig))
    return [x * peak / m for x in sig]


def fade(sig, fin=0.005, fout=0.02):
    n = len(sig)
    a, b = int(fin * SR), int(fout * SR)
    for i in range(min(a, n)):
        sig[i] *= i / max(1, a)
    for i in range(min(b, n)):
        sig[n - 1 - i] *= i / max(1, b)
    return sig


def loopify(sig, xfade=1.0):
    """Crossfades the tail into the head so the loop has no click."""
    x = int(xfade * SR)
    body = sig[:-x]
    tail = sig[-x:]
    for i in range(x):
        t = i / x
        body[i] = body[i] * t + tail[i] * (1 - t)
    return body


def write_wav(path, sig):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = array.array("h", [max(-32767, min(32767, int(v * 32767))) for v in sig])
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path, sig, quality=3):
    tmp = path[:-4] + ".tmp.wav"
    write_wav(tmp, sig)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.remove(tmp)


def note(n):
    """MIDI note number -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12.0)


# --- Sound effects -------------------------------------------------------------------

def sfx_defs():
    d = {}

    def whoosh(seed, length=0.28, lo=500, hi=2600):
        rng = random.Random(seed)
        nz = noise(length, rng)
        sweep = lambda t: lo + (hi - lo) * math.sin(math.pi * min(1.0, t / length))
        s = lowpass(nz, sweep)
        return mul(s, env_adsr(len(s), length * 0.45, 0.05, 0, length * 0.5, 0.8))

    for k in range(3):
        d["swing_%d" % k] = lambda k=k: whoosh(10 + k, 0.24 + k * 0.03, 400 + k * 150, 2600 + k * 300)
    d["swing_heavy"] = lambda: whoosh(20, 0.42, 250, 1500)
    d["dodge"] = lambda: whoosh(21, 0.3, 300, 1800)

    def thud(seed, f0=120, length=0.22, noise_amt=0.6, cutoff=2400):
        rng = random.Random(seed)
        body = osc(lambda t: f0 * (1 + 1.5 * math.exp(-t * 30)), length, "sine")
        nz = lowpass(noise(length, rng), cutoff)
        e = exp_env(int(length * SR), length * 0.25)
        return [(b * 0.9 + n * noise_amt) * v for b, n, v in zip(body, nz, e)]

    d["hit_flesh_0"] = lambda: thud(30, 110, 0.2, 0.8, 1800)
    d["hit_flesh_1"] = lambda: thud(31, 95, 0.24, 0.9, 1400)
    d["hit_crit"] = lambda: mix_into(thud(32, 80, 0.3, 1.0, 3000), fm_bell(1200, 0.3, 2.7, 1.5, 0.1), 0, 0.35)

    def metal(seed, f=1100, length=0.5):
        rng = random.Random(seed)
        s = [0.0] * int(length * SR)
        for r, a in [(1.0, 1.0), (2.76, 0.6), (5.4, 0.4), (8.9, 0.25)]:
            mix_into(s, fm_bell(f * r, length, 1.41, 0.8, length * 0.35 / r ** 0.3), 0, a)
        mix_into(s, mul(highpass(noise(0.05, rng), 2000), exp_env(int(0.05 * SR), 0.01)), 0, 0.8)
        return s

    d["block"] = lambda: metal(40, 700, 0.35)
    d["parry"] = lambda: metal(41, 1500, 0.8)
    d["hit_metal"] = lambda: metal(42, 950, 0.4)
    d["hurt"] = lambda: mix_into(thud(43, 140, 0.25, 0.7, 2200), osc(lambda t: 320 - 300 * t, 0.2, "tri"), 0.0, 0.2)

    def growl(seed, f=90, length=0.7, rough=0.6):
        rng = random.Random(seed)
        base = osc(lambda t: f * (1 + 0.15 * math.sin(t * 18)), length, "saw")
        nz = noise(length, rng)
        s = [b * (1 - rough) + b * n * rough for b, n in zip(base, nz)]
        s = biquad_lp(s, 900, 2.0)
        return mul(s, env_adsr(len(s), 0.08, 0.2, 0, 0.3, 0.7))

    d["boar_grunt"] = lambda: growl(50, 120, 0.45, 0.7)
    d["monster_growl"] = lambda: growl(51, 70, 0.9, 0.5)
    d["enemy_die"] = lambda: mix_into(growl(52, 100, 0.6, 0.6), thud(53, 70, 0.4, 0.8, 900), 0.25, 0.8)

    def rattle(seed):
        rng = random.Random(seed)
        s = silence(0.45)
        for k in range(9):
            click = mul(bandpass(noise(0.03, rng), 1500, 5000), exp_env(int(0.03 * SR), 0.006))
            mix_into(s, click, 0.02 + k * 0.045 + rng.uniform(0, 0.015), rng.uniform(0.5, 1.0))
        return s

    d["bones"] = lambda: rattle(54)

    def footstep(seed, kind):
        rng = random.Random(seed)
        if kind == "grass":
            s = mul(bandpass(noise(0.12, rng), 400, 3500), env_adsr(int(0.12 * SR), 0.01, 0.03, 0, 0.08, 0.4))
            return scale(s, 0.7)
        if kind == "stone":
            return mix_into(thud(seed, 160, 0.09, 0.9, 3500), mul(highpass(noise(0.04, rng), 3000), exp_env(int(0.04 * SR), 0.008)), 0, 0.4)
        if kind == "sand":
            return mul(bandpass(noise(0.16, rng), 1200, 7000), env_adsr(int(0.16 * SR), 0.02, 0.04, 0, 0.1, 0.5))
        if kind == "snow":
            s = noise(0.2, rng)
            s = [x * (1.0 if rng.random() < 0.3 else 0.2) for x in s]
            return mul(bandpass(s, 600, 4000), env_adsr(len(s), 0.03, 0.05, 0, 0.12, 0.5))
        if kind == "wood":
            return thud(seed, 210, 0.12, 0.4, 2000)
        return thud(seed, 140, 0.1)

    for kind in ["grass", "stone", "sand", "snow", "wood"]:
        for k in range(3):
            d["step_%s_%d" % (kind, k)] = lambda kind=kind, k=k: footstep(60 + k * 7 + len(kind), kind)

    def splash(seed, length=0.6, big=1.0):
        rng = random.Random(seed)
        nz = noise(length, rng)
        s = lowpass(highpass(nz, 300), lambda t: 6000 * math.exp(-t * 4) + 500)
        s = mul(s, env_adsr(len(s), 0.01, 0.1, 0, length * 0.7, 0.5))
        for k in range(int(6 * big)):
            mix_into(s, mul(osc(lambda t, f=rng.uniform(600, 1400): f * (1 + t * 6), 0.06, "sine"), exp_env(int(0.06 * SR), 0.02)),
                     rng.uniform(0.05, length * 0.6), 0.3)
        return s

    d["splash"] = lambda: splash(70, 0.7, 1.5)
    d["swim"] = lambda: scale(splash(71, 0.4, 0.6), 0.6)

    def chop(seed):
        rng = random.Random(seed)
        s = thud(seed, 180, 0.18, 1.0, 2600)
        mix_into(s, mul(bandpass(noise(0.08, rng), 800, 3000), exp_env(int(0.08 * SR), 0.02)), 0, 0.8)
        return s

    d["chop"] = lambda: chop(80)
    d["mine"] = lambda: mix_into(metal(81, 2100, 0.25), thud(82, 120, 0.15, 1.0, 4000), 0, 0.9)
    d["tree_fall"] = lambda: mix_into(mul(lowpass(noise(1.2, random.Random(83)), lambda t: 300 + 2500 * t), env_adsr(int(1.2 * SR), 0.6, 0.2, 0, 0.3, 0.8)),
                                      thud(84, 60, 0.6, 1.0, 600), 1.0, 1.4)
    d["rock_break"] = lambda: mix_into(thud(85, 90, 0.4, 1.2, 3000), rattle(86), 0.05, 0.6)
    d["gather"] = lambda: mul(bandpass(noise(0.25, random.Random(87)), 1500, 6000),
                              [0.6 + 0.4 * math.sin(i / SR * 60) for i in range(int(0.25 * SR))])

    def pop(f=700, length=0.12):
        s = osc(lambda t: f * (1 + 1.2 * t / length), length, "sine")
        return mul(s, exp_env(len(s), length * 0.3))

    d["pickup"] = lambda: mix_into(pop(650), pop(980), 0.05, 0.7)
    d["coin"] = lambda: mix_into(fm_bell(1900, 0.4, 2.0, 1.2, 0.15), fm_bell(2530, 0.4, 2.0, 1.2, 0.15), 0.07, 0.8)
    d["eat"] = lambda: (lambda rng: mix_into(mix_into(silence(0.5), mul(bandpass(noise(0.08, rng), 600, 3000), exp_env(int(0.08 * SR), 0.03)), 0.0),
                                             mul(bandpass(noise(0.08, rng), 500, 2500), exp_env(int(0.08 * SR), 0.03)), 0.2))(random.Random(88))
    d["drink"] = lambda: (lambda: [math.sin(TAU * (300 + 200 * math.sin(i / SR * 25)) * i / SR) * 0.6 * (1 - i / (0.5 * SR)) for i in range(int(0.5 * SR))])()

    def chime(notes, length=0.9, gap=0.09, ratio=2.0, decay=0.5):
        s = silence(length + gap * len(notes))
        for k, n in enumerate(notes):
            mix_into(s, fm_bell(note(n), length, ratio, 1.2, decay), k * gap, 0.6)
        return reverb(s, 0.8, 0.3)

    d["level_up"] = lambda: chime([72, 76, 79, 84, 88], 1.2, 0.1)
    d["notify"] = lambda: chime([79, 84], 0.6, 0.08)
    d["discover"] = lambda: chime([67, 71, 74, 79], 1.4, 0.16, 3.0, 0.7)
    d["learn"] = lambda: chime([72, 79, 76, 84], 1.0, 0.12, 1.5)
    d["error"] = lambda: mul(osc(lambda t: 180 if t < 0.09 else 140, 0.2, "square"), env_adsr(int(0.2 * SR), 0.005, 0.05, 0, 0.05, 0.4))
    d["ui_click"] = lambda: mix_into(pop(1200, 0.05), mul(highpass(noise(0.02, random.Random(89)), 3000), exp_env(int(0.02 * SR), 0.004)), 0, 0.4)
    d["ui_open"] = lambda: mul(lowpass(noise(0.25, random.Random(90)), lambda t: 500 + 6000 * t), env_adsr(int(0.25 * SR), 0.15, 0.05, 0, 0.05, 0.6))
    d["ui_close"] = lambda: mul(lowpass(noise(0.2, random.Random(91)), lambda t: 4000 - 15000 * t if t < 0.25 else 400), env_adsr(int(0.2 * SR), 0.02, 0.05, 0, 0.12, 0.6))
    d["craft"] = lambda: mix_into(mix_into(metal(92, 1300, 0.3), metal(93, 1250, 0.3), 0.18), chime([84, 91], 0.5, 0.05), 0.36, 0.5)
    d["build"] = lambda: mix_into(thud(94, 130, 0.25, 0.7, 1500), thud(95, 170, 0.15, 0.5, 2500), 0.12, 0.7)
    d["door"] = lambda: mix_into(mul(osc(lambda t: 220 + 80 * math.sin(t * 30), 0.35, "saw"), env_adsr(int(0.35 * SR), 0.05, 0.1, 0, 0.1, 0.25)), thud(96, 120, 0.15), 0.3)
    d["chest_open"] = lambda: mix_into(thud(97, 150, 0.2, 0.5, 1800), chime([76, 83], 0.4, 0.05), 0.15, 0.4)
    d["fire_ignite"] = lambda: mul(lowpass(noise(0.6, random.Random(98)), lambda t: 300 + 4000 * t), env_adsr(int(0.6 * SR), 0.3, 0.1, 0, 0.2, 0.7))
    d["bow"] = lambda: mix_into(mul(osc(lambda t: 160 * (1 + 0.2 * math.exp(-t * 30)), 0.25, "tri"), exp_env(int(0.25 * SR), 0.06)), whoosh(99, 0.2, 800, 3000), 0.02, 0.6)
    d["arrow_hit"] = lambda: thud(100, 240, 0.12, 0.9, 3000)

    def boom(seed, length=1.4):
        rng = random.Random(seed)
        nz = noise(length, rng)
        s = lowpass(nz, lambda t: 2500 * math.exp(-t * 5) + 120)
        s = mul(s, exp_env(len(s), 0.35))
        mix_into(s, mul(osc(lambda t: 40 + 60 * math.exp(-t * 8), length, "sine"), exp_env(int(length * SR), 0.3)), 0, 0.9)
        return s

    d["explosion"] = lambda: boom(101)
    d["thunder_0"] = lambda: (lambda: mul(lowpass(noise(3.0, random.Random(102)), lambda t: 900 * math.exp(-t * 1.2) + 80),
                                          [min(1.0, t / (0.06 * SR)) * math.exp(-t / (1.1 * SR)) * (0.7 + 0.3 * math.sin(t / SR * 9)) for t in range(int(3.0 * SR))]))()
    d["thunder_1"] = lambda: (lambda: mul(lowpass(noise(4.0, random.Random(103)), lambda t: 500 * math.exp(-t * 0.8) + 60),
                                          [min(1.0, t / (0.4 * SR)) * math.exp(-t / (1.6 * SR)) for t in range(int(4.0 * SR))]))()

    # Magic
    d["cast"] = lambda: mix_into(mul(osc(lambda t: 300 + 900 * t, 0.4, "tri"), env_adsr(int(0.4 * SR), 0.05, 0.1, 0, 0.2, 0.5)),
                                  scale(whoosh(110, 0.4, 800, 4000), 0.5))
    d["fire"] = lambda: mul(lowpass(noise(0.7, random.Random(111)), lambda t: 2500 - 2000 * t), env_adsr(int(0.7 * SR), 0.05, 0.2, 0, 0.3, 0.7))
    d["frost"] = lambda: mix_into(chime([96, 91, 100], 0.6, 0.03, 3.3, 0.2), mul(highpass(noise(0.5, random.Random(112)), 4000), exp_env(int(0.5 * SR), 0.12)), 0, 0.5)
    d["zap"] = lambda: (lambda rng: mul([rng.choice([-1.0, 1.0]) * (1 if rng.random() < 0.4 else 0.2) for _ in range(int(0.45 * SR))],
                                        exp_env(int(0.45 * SR), 0.12)))(random.Random(113))
    d["heal"] = lambda: chime([72, 76, 79, 83, 86], 1.2, 0.07, 1.0, 0.6)
    d["shield"] = lambda: mul(osc(lambda t: 220 + 10 * math.sin(t * 40), 0.8, "tri"), env_adsr(int(0.8 * SR), 0.1, 0.2, 0, 0.4, 0.6))
    d["teleport"] = lambda: mix_into(mul(osc(lambda t: 1600 - 1400 * t, 0.5, "sine"), exp_env(int(0.5 * SR), 0.2)), chime([84, 79], 0.4, 0.06), 0.1, 0.4)
    d["poison"] = lambda: bubble(114)
    d["warning"] = lambda: chime([60, 63, 60, 63], 0.6, 0.25, 1.0, 0.3)
    d["horn"] = lambda: reverb(mul(biquad_lp(osc(lambda t: note(50) * (1 + 0.01 * math.sin(t * 30)), 2.0, "saw"), 1100, 1.2),
                                   env_adsr(int(2.0 * SR), 0.25, 0.3, 0, 0.6, 0.8)), 0.85, 0.35)
    d["boss_roar"] = lambda: mix_into(growl(115, 55, 1.6, 0.7), boom(116, 1.2), 0.0, 0.4)
    return d


def bubble(seed):
    rng = random.Random(seed)
    s = silence(0.7)
    for k in range(7):
        f = rng.uniform(300, 700)
        b = mul(osc(lambda t, f=f: f * (1 + t * 8), 0.08, "sine"), exp_env(int(0.08 * SR), 0.03))
        mix_into(s, b, rng.uniform(0, 0.55), rng.uniform(0.3, 0.7))
    return s


# --- Ambience loops ----------------------------------------------------------------------

def ambience_defs():
    d = {}

    def wind(seed, length=12.0, base=400, gust=0.6):
        rng = random.Random(seed)
        nz = noise(length + 1, rng)
        lfo = lambda t: base * (1 + gust * (0.5 + 0.5 * math.sin(TAU * t / 6.0) * math.sin(TAU * t / 2.7 + 1)))
        s = lowpass(lowpass(nz, lfo), lfo)
        amp = [0.6 + 0.4 * math.sin(TAU * i / SR / 6.0) for i in range(len(s))]
        return loopify(mul(s, amp))

    d["wind"] = lambda: wind(200)
    d["wind_strong"] = lambda: wind(201, 12.0, 900, 0.9)

    def rain(seed, length=10.0, heavy=False):
        rng = random.Random(seed)
        s = highpass(lowpass(noise(length + 1, rng), 5000 if heavy else 3500), 400)
        s = scale(s, 0.5)
        drops = 900 if heavy else 400
        for _ in range(int(drops * length / 10)):
            f = rng.uniform(1500, 4500)
            dr = mul(osc(f, 0.02, "sine"), exp_env(int(0.02 * SR), 0.004))
            mix_into(s, dr, rng.uniform(0, length), rng.uniform(0.05, 0.25))
        return loopify(s[:int((length + 1) * SR)])

    d["rain"] = lambda: rain(210)
    d["rain_heavy"] = lambda: rain(211, 10.0, True)

    def birds(seed, length=16.0):
        rng = random.Random(seed)
        s = scale(lowpass(noise(length + 1, rng), 300), 0.05)
        t = 0.3
        while t < length - 1:
            f = rng.uniform(2200, 4200)
            for k in range(rng.randint(2, 6)):
                ff = f * rng.uniform(0.9, 1.25)
                chirp = mul(osc(lambda x, ff=ff: ff * (1 + 0.4 * math.sin(x * 70)), 0.07, "sine"), env_adsr(int(0.07 * SR), 0.01, 0.02, 0, 0.03, 0.6))
                mix_into(s, chirp, t + k * 0.1, rng.uniform(0.15, 0.35))
            t += rng.uniform(0.8, 2.6)
        return loopify(reverb(s, 0.7, 0.2))

    d["birds"] = lambda: birds(220)

    def crickets(seed, length=12.0):
        rng = random.Random(seed)
        s = scale(lowpass(noise(length + 1, rng), 250), 0.06)
        for c in range(3):
            f = rng.uniform(3800, 5200)
            rate = rng.uniform(2.5, 4.0)
            t = rng.uniform(0, 0.5)
            while t < length:
                for k in range(3):
                    pulse = mul(osc(f, 0.025, "sine"), env_adsr(int(0.025 * SR), 0.003, 0.01, 0, 0.01, 0.6))
                    mix_into(s, pulse, t + k * 0.035, 0.15)
                t += 1.0 / rate
        return loopify(s)

    d["crickets"] = lambda: crickets(230)

    def cave(seed, length=14.0):
        rng = random.Random(seed)
        s = scale(lowpass(noise(length + 1, rng), 120), 0.5)
        t = 0.5
        while t < length - 1:
            f = rng.uniform(900, 1700)
            drip = mul(osc(lambda x, f=f: f * (1 + 2.5 * x), 0.1, "sine"), exp_env(int(0.1 * SR), 0.03))
            mix_into(s, drip, t, rng.uniform(0.2, 0.5))
            t += rng.uniform(0.7, 2.5)
        return loopify(reverb(s, 0.9, 0.45))

    d["cave"] = lambda: cave(240)

    def sea(seed, length=16.0):
        rng = random.Random(seed)
        nz = noise(length + 1, rng)
        swell = lambda t: 300 + 1500 * (0.5 + 0.5 * math.sin(TAU * t / 5.3)) ** 2
        s = lowpass(nz, swell)
        amp = [0.35 + 0.65 * (0.5 + 0.5 * math.sin(TAU * i / SR / 5.3)) ** 2 for i in range(len(s))]
        return loopify(mul(s, amp))

    d["sea"] = lambda: sea(250)

    def fire(seed, length=8.0):
        rng = random.Random(seed)
        s = scale(lowpass(noise(length + 1, rng), 600), 0.4)
        for _ in range(int(length * 14)):
            c = mul(bandpass(noise(0.015, rng), 1500, 7000), exp_env(int(0.015 * SR), 0.003))
            mix_into(s, c, rng.uniform(0, length), rng.uniform(0.2, 0.8))
        return loopify(s)

    d["fire"] = lambda: fire(260)

    def town(seed, length=14.0):
        rng = random.Random(seed)
        s = scale(bandpass(noise(length + 1, rng), 200, 1200), 0.25)
        for _ in range(int(length * 2)):
            f = rng.uniform(150, 280)
            v = mul(osc(lambda x, f=f: f * (1 + 0.1 * math.sin(x * 20)), 0.3, "saw"), env_adsr(int(0.3 * SR), 0.05, 0.1, 0, 0.1, 0.5))
            mix_into(s, biquad_lp(v, 900, 1.5), rng.uniform(0, length), rng.uniform(0.05, 0.12))
        for _ in range(int(length / 3)):
            mix_into(s, scale(fm_bell(rng.uniform(1500, 2500), 0.3, 1.41, 0.8, 0.08), 0.1), rng.uniform(0, length))
        return loopify(s)

    d["town"] = lambda: town(270)
    return d


# --- Music ------------------------------------------------------------------------------

SCALES = {
    "major_penta": [0, 2, 4, 7, 9],
    "minor_penta": [0, 3, 5, 7, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "ionian": [0, 2, 4, 5, 7, 9, 11],
}


def melody(rng, scale_steps, root, bars, beats_per_bar, density=0.6, rng_range=(0, 9)):
    """Random-walk melody on a scale; returns [(beat, length_beats, midi)]."""
    notes = []
    deg = rng.randint(2, 5)
    beat = 0.0
    total = bars * beats_per_bar
    while beat < total:
        length = rng.choice([0.5, 0.5, 1.0, 1.0, 1.5, 2.0])
        if rng.random() < density:
            deg = max(rng_range[0], min(rng_range[1], deg + rng.choice([-2, -1, -1, 0, 1, 1, 2])))
            octave, idx = divmod(deg, len(scale_steps))
            notes.append((beat, length, root + 12 * octave + scale_steps[idx]))
        beat += length
    return notes


def render_track(name, bpm, bars, root, scale_name, progression, inst, seed, drums=None, pads=True,
                 bass=True, arp=False, lead_density=0.6, length_bars=None):
    rng = random.Random(seed)
    spb = 60.0 / bpm
    bpbar = 4
    total = bars * bpbar * spb
    mixbuf = silence(total + 3.0)
    sc = SCALES[scale_name]

    # Chords: progression of scale degrees, one per bar (repeating).
    def chord(deg):
        tones = []
        for k in (0, 2, 4):
            octave, idx = divmod(deg + k, len(sc))
            tones.append(root + 12 * octave + sc[idx])
        return tones

    for b in range(bars):
        deg = progression[b % len(progression)]
        tones = chord(deg)
        t0 = b * bpbar * spb
        if pads:
            for tn in tones:
                mix_into(mixbuf, pad(note(tn - 12), bpbar * spb + 0.6, rng, cutoff=900 if inst == "dark" else 1600), t0, 0.07)
        if bass:
            bn = tones[0] - 24
            for beat in ([0, 2] if inst != "drive" else [0, 1, 2, 3, 3.5]):
                s = osc(note(bn), spb * 1.4, "tri")
                s = mul(lowpass(s, 600), env_adsr(len(s), 0.01, 0.2, 0, 0.2, 0.5))
                mix_into(mixbuf, s, t0 + beat * spb, 0.28)
        if arp:
            for k in range(8):
                tn = tones[[0, 1, 2, 1, 2, 0, 1, 2][k]] + (12 if k >= 4 else 0)
                p = pluck(note(tn), spb * 1.2, rng, 0.6, 0.994)
                mix_into(mixbuf, p, t0 + k * spb * 0.5, 0.16)
        if drums:
            for beat_i in range(bpbar * 2):
                t = t0 + beat_i * spb * 0.5
                if drums == "march":
                    if beat_i % 4 == 0:
                        mix_into(mixbuf, kick(rng), t, 0.5)
                    if beat_i % 4 == 2:
                        mix_into(mixbuf, snare(rng), t, 0.3)
                    mix_into(mixbuf, hat(rng), t, 0.12)
                elif drums == "war":
                    if beat_i % 2 == 0 or rng.random() < 0.25:
                        mix_into(mixbuf, tom(70 if beat_i % 4 == 0 else 95, rng), t, 0.5)
                    if beat_i % 4 == 2:
                        mix_into(mixbuf, snare(rng), t, 0.35)
                    mix_into(mixbuf, hat(rng), t, 0.1)
                elif drums == "soft":
                    if beat_i == 0:
                        mix_into(mixbuf, tom(80, rng), t, 0.25)
                    if beat_i in (3, 7) and rng.random() < 0.6:
                        mix_into(mixbuf, hat(rng), t, 0.06)
                elif drums == "deep":
                    if beat_i == 0 or beat_i == 5:
                        mix_into(mixbuf, tom(55, rng, 0.8), t, 0.45)

    # Lead melody (two 4-bar phrases repeated with variation).
    phrase = melody(rng, sc, root + 12, 4, bpbar, lead_density)
    phrase2 = melody(rng, sc, root + 12, 4, bpbar, lead_density)
    for b0 in range(0, bars, 4):
        use = phrase if (b0 // 4) % 4 in (0, 2) else (phrase2 if (b0 // 4) % 4 == 1 else [])
        if b0 < 4 and inst in ("dark", "ambient"):
            use = []  # let it breathe
        for beat, ln, mn in use:
            t = (b0 * bpbar + beat) * spb
            dur = ln * spb
            if inst in ("lute", "drive"):
                s = pluck(note(mn), dur + 0.6, rng, 0.7 if inst == "drive" else 0.5, 0.995)
                g = 0.3
            elif inst == "bell":
                s = fm_bell(note(mn), dur + 1.2, 3.5, 1.8, 0.9)
                g = 0.18
            elif inst == "flute":
                s = osc(lambda t, f=note(mn): f * (1 + 0.004 * math.sin(t * 30)), dur + 0.15, "sine")
                s2 = osc(note(mn) * 2, dur + 0.15, "sine")
                s = [a + 0.15 * b for a, b in zip(s, s2)]
                s = mul(s, env_adsr(len(s), 0.07, 0.1, 0, 0.12, 0.8))
                g = 0.2
            else:  # dark / ambient: low bell-pad
                s = fm_bell(note(mn - 12), dur + 2.0, 1.0, 1.0, 1.4)
                g = 0.16
            mix_into(mixbuf, s, t, g)

    out = reverb(mixbuf, 0.86, 0.32 if inst not in ("dark", "ambient") else 0.45)
    # Loop: wrap the reverb tail back onto the start, then cut to the exact length.
    n = int(total * SR)
    tail = out[n:]
    out = out[:n]
    for i, v in enumerate(tail):
        if i < n:
            out[i] += v
    return normalize(out, 0.8)


def music_defs():
    return {
        "explore_day": lambda: render_track("explore_day", 92, 32, 57, "major_penta", [0, 3, 4, 2], "lute", 300, drums="soft", arp=True),
        "explore_night": lambda: render_track("explore_night", 70, 24, 52, "aeolian", [0, 5, 3, 4], "bell", 301, drums=None, lead_density=0.45),
        "town": lambda: render_track("town", 108, 32, 60, "ionian", [0, 3, 4, 0, 5, 3, 4, 4], "flute", 302, drums="march", arp=True),
        "combat": lambda: render_track("combat", 138, 32, 50, "dorian", [0, 0, 5, 6], "drive", 303, drums="war", pads=True, lead_density=0.75),
        "dungeon": lambda: render_track("dungeon", 66, 20, 45, "phrygian", [0, 1, 0, 6], "dark", 304, drums="deep", lead_density=0.35),
        "boss": lambda: render_track("boss", 150, 32, 47, "phrygian", [0, 1, 5, 4], "drive", 305, drums="war", arp=True, lead_density=0.8),
        "menu": lambda: render_track("menu", 76, 24, 55, "dorian", [0, 3, 6, 4], "bell", 306, drums=None, arp=True, lead_density=0.4),
    }


def main():
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = a[7:]
    if only in (None, "sfx"):
        for name, fn in sfx_defs().items():
            write_wav(os.path.join(OUT, "sfx", name + ".wav"), fade(normalize(fn(), 0.85)))
            print("sfx", name)
    if only in (None, "ambience"):
        for name, fn in ambience_defs().items():
            write_ogg(os.path.join(OUT, "ambience", name + ".ogg"), normalize(fn(), 0.7))
            print("ambience", name)
    if only in (None, "music"):
        for name, fn in music_defs().items():
            write_ogg(os.path.join(OUT, "music", name + ".ogg"), fn(), 4)
            print("music", name)


if __name__ == "__main__":
    main()
