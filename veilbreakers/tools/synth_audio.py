"""Procedural audio pack for OOF COMBAT.

Synthesises every sound effect, voice grunt, ambience bed and music track the game
references (Assets.Sounds keys) and writes them to ../audio as .ogg files ready for
upload to Roblox. Deterministic: the same seed always produces the same pack.

    python3 tools/synth_audio.py            # writes audio/*.ogg
"""
import os
import subprocess
import sys
import numpy as np
from scipy.signal import butter, lfilter, sosfilt

SR = 44100
RNG = np.random.default_rng(20261031)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


# --------------------------------------------------------------------------- utils
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return RNG.uniform(-1, 1, int(dur * SR))


def sos(kind, f, order=2):
    nyq = SR / 2
    if kind == "band":
        lo, hi = f
        return butter(order, [max(10, lo) / nyq, min(hi, nyq * 0.95) / nyq], btype="band", output="sos")
    return butter(order, min(f, nyq * 0.95) / nyq, btype=kind, output="sos")


def lp(x, f, order=2):
    return sosfilt(sos("low", f, order), x)


def hp(x, f, order=2):
    return sosfilt(sos("high", f, order), x)


def bp(x, lo, hi, order=2):
    return sosfilt(sos("band", (lo, hi), order), x)


def sweep_filter(x, f0, f1, q_width=0.6, steps=48):
    """Band-pass with a moving centre (block-wise)."""
    out = np.zeros_like(x)
    n = len(x)
    edges = np.linspace(0, n, steps + 1).astype(int)
    for i in range(steps):
        a, b = edges[i], edges[i + 1]
        if b <= a:
            continue
        fc = f0 * (f1 / f0) ** (i / max(1, steps - 1))
        lo, hi = fc * (1 - q_width / 2), fc * (1 + q_width / 2)
        seg = x[max(0, a - 512):b]
        y = bp(seg, lo, hi)
        out[a:b] = y[-(b - a):]
    return out


def env_exp(n, decay):
    return np.exp(-np.arange(n) / (decay * SR))


def env_ad(n, attack, decay):
    a = int(attack * SR)
    e = np.ones(n)
    if a > 0:
        e[:a] = np.linspace(0, 1, a)
    e[a:] = np.exp(-np.arange(n - a) / (decay * SR))
    return e


def bell(n, peak=0.4):
    x = np.linspace(0, 1, n)
    return np.where(x < peak, x / peak, 1 - (x - peak) / (1 - peak)) ** 1.5


def sine_sweep(dur, f0, f1, curve=3.0):
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t * curve / dur * 3)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


def osc(freq, dur, kind="sine", detune=0.0):
    t = t_axis(dur)
    f = freq * (1 + detune)
    ph = 2 * np.pi * f * t
    if kind == "sine":
        return np.sin(ph)
    if kind == "saw":
        return 2 * ((f * t) % 1) - 1
    if kind == "square":
        return np.sign(np.sin(ph))
    if kind == "tri":
        return 2 * np.abs(2 * ((f * t) % 1) - 1) - 1
    raise ValueError(kind)


def partials(freqs, amps, decays, dur):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f, a, d in zip(freqs, amps, decays):
        out += a * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28)) * np.exp(-t / d)
    return out


def drive(x, k):
    return np.tanh(x * k) / np.tanh(k)


def reverb(x, mix=0.3, size=1.0):
    """Small Schroeder reverb."""
    out = np.copy(x)
    combs = [int(SR * d * size) for d in (0.0297, 0.0371, 0.0411, 0.0437)]
    wet = np.zeros(len(x) + int(SR * 1.5 * size))
    src = np.concatenate([x, np.zeros(len(wet) - len(x))])
    for i, d in enumerate(combs):
        g = 0.78 - i * 0.02
        y = np.copy(src)
        b = np.zeros(d + 1)
        b[0] = 1
        a = np.zeros(d + 1)
        a[0] = 1
        a[d] = -g
        y = lfilter(b, a, src)
        wet += y
    for d in (int(SR * 0.005), int(SR * 0.0017)):
        g = 0.7
        b = np.zeros(d + 1)
        b[0] = -g
        b[d] = 1
        a = np.zeros(d + 1)
        a[0] = 1
        a[d] = -g
        wet = lfilter(b, a, wet)
    wet = lp(wet, 6000) * 0.25
    out = np.concatenate([out, np.zeros(len(wet) - len(out))])
    return out * (1 - mix) + wet * mix


def fit(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, fin=0.002, fout=0.02):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0 and b < n:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def pad_to(x, dur):
    n = int(dur * SR)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def write(name, x, stereo=None, peak=0.9):
    os.makedirs(OUT, exist_ok=True)
    x = fit(np.nan_to_num(x), peak)
    if stereo is not None:
        st = fit(np.nan_to_num(stereo), peak)
        data = np.stack([x, st], axis=1)
        ch = 2
    else:
        data = x[:, None]
        ch = 1
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT, name + ".ogg")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", str(ch), "-i", "-", "-c:a", "libvorbis", "-q:a", "6", path],
        input=pcm,
        check=True,
    )
    return path


# --------------------------------------------------------------------------- building blocks
def thump(f0, f1, dur, curve=4.0):
    return sine_sweep(dur, f0, f1, curve) * env_exp(int(dur * SR), dur / 4)


def click(dur=0.01, f=3000):
    return hp(noise(dur), f) * env_exp(int(dur * SR), dur / 3)


def whoosh(dur, f0, f1, width=0.7):
    n = noise(dur)
    return sweep_filter(n, f0, f1, width) * bell(int(dur * SR), 0.45)


def metal(base, dur, n=6, spread=(1.0, 2.76, 5.4, 8.93, 13.3, 19.1)):
    fr = [base * s for s in spread[:n]]
    amps = [1 / (i + 1) ** 0.6 for i in range(n)]
    dec = [dur / (1 + i * 0.6) for i in range(n)]
    return partials(fr, amps, dec, dur)


def karplus(freq, dur, damp=0.996):
    n = int(dur * SR)
    period = int(SR / freq)
    buf = RNG.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out


def karplus_fast(freq, dur, damp=0.996):
    """Vectorised-ish Karplus-Strong using per-period averaging."""
    n = int(dur * SR)
    period = max(2, int(SR / freq))
    cycles = n // period + 2
    buf = RNG.uniform(-1, 1, period)
    out = []
    for _ in range(cycles):
        out.append(buf.copy())
        buf = damp * 0.5 * (buf + np.roll(buf, -1))
    return np.concatenate(out)[:n]


def formant_voice(f0, dur, vowels, gender_shift=1.0, breath=0.25, pitch_drop=0.0, vib=0.0):
    t = t_axis(dur)
    f = f0 * (1 - pitch_drop * t / dur) * (1 + vib * np.sin(2 * np.pi * 5.5 * t))
    ph = np.cumsum(f) / SR
    glottal = 2 * (ph % 1) - 1
    src = glottal * (1 - breath) + noise(dur) * breath
    out = np.zeros_like(src)
    for (f1, f2, f3) in vowels:
        out += bp(src, f1 * gender_shift * 0.85, f1 * gender_shift * 1.15) * 1.0
        out += bp(src, f2 * gender_shift * 0.9, f2 * gender_shift * 1.1) * 0.6
        out += bp(src, f3 * gender_shift * 0.92, f3 * gender_shift * 1.08) * 0.3
    return out


# --------------------------------------------------------------------------- SFX
def sfx():
    S = {}
    S["hit_light"] = mix(thump(160, 70, 0.12) * 0.9, bp(noise(0.06), 900, 3500) * env_exp(int(0.06 * SR), 0.012) * 0.8, click(0.008))
    S["hit_medium"] = drive(mix(thump(120, 50, 0.2) * 1.0, bp(noise(0.09), 600, 2600) * env_exp(int(0.09 * SR), 0.02) * 0.9, click(0.01, 2500)), 1.8)
    S["hit_heavy"] = reverb(drive(mix(thump(95, 32, 0.38) * 1.2, lp(noise(0.16), 1800) * env_exp(int(0.16 * SR), 0.04) * 1.0, bp(noise(0.05), 2000, 6000) * env_exp(int(0.05 * SR), 0.01) * 0.6), 2.4), 0.18, 0.7)
    blade = mix(hp(noise(0.25), 3500) * env_exp(int(0.25 * SR), 0.05) * 0.6, metal(1850, 0.5, 5) * 0.35, thump(140, 60, 0.15) * 0.7)
    S["hit_blade"] = reverb(blade, 0.15, 0.6)
    S["block"] = reverb(mix(metal(520, 0.45, 6) * 0.7, click(0.012, 2000) * 0.8, thump(200, 90, 0.08) * 0.5), 0.2, 0.6)
    S["whoosh_light"] = whoosh(0.2, 700, 2600)
    S["whoosh_heavy"] = whoosh(0.34, 220, 1100, 0.9)
    S["dash_slash"] = mix(whoosh(0.28, 400, 3000), np.concatenate([np.zeros(int(0.16 * SR)), metal(2400, 0.4, 4) * 0.4]))
    S["jump"] = whoosh(0.16, 500, 1200) * 0.7
    S["land"] = mix(thump(110, 45, 0.18), lp(noise(0.2), 900) * env_exp(int(0.2 * SR), 0.05) * 0.5)
    S["dash"] = mix(whoosh(0.18, 300, 1500), thump(100, 50, 0.1) * 0.6)
    S["throw_slam"] = reverb(drive(mix(thump(75, 28, 0.5) * 1.3, lp(noise(0.35), 700) * env_exp(int(0.35 * SR), 0.08)), 2.0), 0.25, 0.8)
    S["tech"] = mix(click(0.02, 1500), metal(1600, 0.35, 4) * 0.5, whoosh(0.2, 1500, 400) * 0.5)
    S["knockdown"] = reverb(mix(thump(90, 35, 0.35), lp(noise(0.4), 600) * env_exp(int(0.4 * SR), 0.1) * 0.6), 0.15, 0.6)
    S["getup"] = bp(noise(0.3), 300, 2000) * bell(int(0.3 * SR)) * 0.5
    # elements
    crack = np.zeros(int(0.5 * SR))
    for i in range(40):
        p = int(RNG.uniform(0, 0.35) * SR)
        crack[p] += RNG.uniform(-1, 1)
    crackle = hp(lfilter([1], [1, -0.6], crack), 1500)
    S["cast_lightning"] = reverb(mix(crackle * 1.4, sine_sweep(0.4, 2200, 220, 2) * env_exp(int(0.4 * SR), 0.1) * 0.5, whoosh(0.3, 800, 4000) * 0.5), 0.2)
    chime = partials([880, 1320, 1760, 2640], [1, 0.7, 0.5, 0.3], [0.6, 0.5, 0.4, 0.3], 0.9) * (1 + 0.3 * np.sin(2 * np.pi * 9 * t_axis(0.9)))
    S["cast_radiant"] = reverb(mix(chime * 0.6, whoosh(0.4, 600, 3000) * 0.5), 0.35, 1.0)
    S["cast_shadow"] = reverb(mix(whoosh(0.5, 2000, 200)[::-1] * 0.8, drive(osc(55, 0.5, "saw"), 2) * env_ad(int(0.5 * SR), 0.2, 0.2) * 0.3), 0.3)
    S["cast_ice"] = reverb(mix(partials([2400, 3100, 4700, 6300], [1, 0.7, 0.5, 0.4], [0.3, 0.25, 0.2, 0.15], 0.6) * 0.6, hp(noise(0.08), 3000) * env_exp(int(0.08 * SR), 0.015)), 0.35)
    choirish = sum(bp(osc(220 * r, 0.7, "saw", d), 600, 1300) for r, d in ((1, 0.0), (1.5, 0.004), (2, -0.003)))
    S["cast_soul"] = reverb(mix(choirish * env_ad(int(0.7 * SR), 0.15, 0.3) * 0.5, whoosh(0.6, 300, 1600) * 0.7), 0.45, 1.2)
    roar = bp(noise(0.7), 200, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * t_axis(0.7))) * bell(int(0.7 * SR), 0.3)
    S["fire_whoosh"] = mix(roar, whoosh(0.5, 300, 1200) * 0.6)
    S["fire_burst"] = reverb(drive(mix(lp(noise(0.6), 1200) * env_exp(int(0.6 * SR), 0.15) * 1.2, thump(80, 30, 0.4)), 2), 0.25)
    S["lightning_crack"] = reverb(mix(hp(noise(0.12), 2000) * env_exp(int(0.12 * SR), 0.02) * 1.5, lp(noise(1.2), 300) * env_exp(int(1.2 * SR), 0.4) * 0.8, crackle * 0.6), 0.3, 1.2)
    grains = np.zeros(int(0.45 * SR))
    for i in range(70):
        p = int(RNG.uniform(0, 0.4) * SR)
        g = lp(noise(0.02), RNG.uniform(400, 1500)) * env_exp(int(0.02 * SR), 0.005)
        grains[p : p + len(g)] += g[: len(grains) - p]
    S["ground_crack"] = mix(grains, thump(90, 40, 0.3) * 0.6)
    S["ground_slam"] = reverb(drive(mix(thump(60, 24, 0.7) * 1.4, lp(noise(0.8), 400) * env_exp(int(0.8 * SR), 0.25), grains * 0.5), 2.2), 0.3, 1.0)
    f = 85 + 25 * np.sin(2 * np.pi * 3.1 * t_axis(0.8)) + RNG.normal(0, 4, int(0.8 * SR))
    creak = lp(2 * ((np.cumsum(f) / SR) % 1) - 1, 900) * bell(int(0.8 * SR), 0.3)
    S["roots"] = mix(creak * 0.7, bp(noise(0.8), 800, 3000) * bell(int(0.8 * SR)) * 0.3, grains * 0.4)
    S["teleport"] = reverb(mix(whoosh(0.35, 3000, 300)[::-1], sine_sweep(0.3, 300, 1800, 1) * env_ad(int(0.3 * SR), 0.05, 0.1) * 0.4), 0.3)
    shing = mix(metal(3100, 0.6, 4) * 0.5, hp(noise(0.3), 5000) * env_ad(int(0.3 * SR), 0.05, 0.08) * 0.6)
    S["parry_ready"] = shing
    S["parry"] = reverb(mix(metal(1100, 0.8, 6), click(0.02, 1200), partials([3000, 4500], [0.5, 0.3], [0.4, 0.3], 0.6)), 0.3)
    fl = np.zeros(int(0.5 * SR))
    for i in range(5):
        w = whoosh(0.09, 900, 3500) * 0.8
        p = int(i * 0.075 * SR)
        fl[p : p + len(w)] += w
    S["dagger_flurry"] = fl
    whir = bp(noise(0.6), 800, 2500) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(np.linspace(12, 30, int(0.6 * SR))) / SR)) * bell(int(0.6 * SR), 0.2)
    S["chakram_throw"] = mix(whir, metal(2600, 0.3, 3) * 0.3)
    S["crossbow"] = mix(karplus_fast(180, 0.35, 0.99) * env_exp(int(0.35 * SR), 0.1), click(0.015, 1500), whoosh(0.15, 1500, 4000) * 0.6)
    ch = np.zeros(int(0.5 * SR))
    for i in range(9):
        m = metal(RNG.uniform(1800, 3200), 0.08, 3) * 0.5
        p = int(i * 0.045 * SR)
        ch[p : p + len(m)] += m
    S["chain"] = ch
    S["smoke"] = lp(noise(0.5), 1200) * env_ad(int(0.5 * SR), 0.03, 0.12)
    S["trap_set"] = mix(metal(700, 0.4, 5) * 0.6, click(0.02, 1000), karplus_fast(320, 0.3) * 0.3)
    S["charge"] = mix(whoosh(0.5, 150, 700), *[np.concatenate([np.zeros(int(i * 0.12 * SR)), thump(90, 45, 0.1) * 0.6]) for i in range(4)])
    S["slide"] = bp(noise(0.45), 400, 2200) * (0.7 + 0.3 * RNG.uniform(0, 1, int(0.45 * SR))) * bell(int(0.45 * SR), 0.2)
    wf = np.zeros(int(0.5 * SR))
    for p in (0.0, 0.2):
        w = lp(noise(0.18), 500) * bell(int(0.18 * SR), 0.3)
        wf[int(p * SR) : int(p * SR) + len(w)] += w
    S["wing_flap"] = wf
    S["spin"] = whoosh(0.4, 400, 1800, 1.0)
    S["projectile_hit"] = reverb(mix(lp(noise(0.25), 2500) * env_exp(int(0.25 * SR), 0.05), thump(130, 50, 0.2) * 0.7), 0.2)
    pad = sum(osc(f, 1.0, "sine") for f in (523.25, 659.25, 783.99, 1046.5)) * env_ad(int(1.0 * SR), 0.3, 0.3)
    S["echo_summon"] = reverb(mix(pad * 0.4, whoosh(0.7, 3000, 500)[::-1] * 0.6), 0.5, 1.3)
    tt = t_axis(1.5)
    howl_f = 420 + 260 * np.sin(np.clip(tt / 1.5, 0, 1) * np.pi) * (1 + 0.02 * np.sin(2 * np.pi * 6 * tt))
    howl = np.sin(2 * np.pi * np.cumsum(howl_f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(howl_f) / SR)
    S["wolf_howl"] = reverb(howl * env_ad(int(1.5 * SR), 0.2, 0.5) * 0.6 + bp(noise(1.5), 600, 1800) * 0.08, 0.4, 1.4)
    caws = np.zeros(int(0.9 * SR))
    for i in range(3):
        c = formant_voice(RNG.uniform(380, 480), 0.16, [(900, 1500, 2600)], breath=0.5, pitch_drop=0.4) * env_ad(int(0.16 * SR), 0.01, 0.06)
        p = int(i * 0.26 * SR)
        caws[p : p + len(c)] += drive(c, 3)
    S["ravens"] = reverb(caws, 0.25)
    S["lantern"] = reverb(mix(partials([1500, 2250, 3400], [1, 0.6, 0.4], [0.5, 0.4, 0.3], 0.7) * 0.4, whoosh(0.4, 400, 1600) * 0.6), 0.35)
    S["flare"] = mix(whoosh(0.4, 600, 4000), hp(noise(0.5), 3000) * env_exp(int(0.5 * SR), 0.15) * 0.4)
    S["palm"] = reverb(mix(thump(100, 40, 0.3) * 1.2, lp(noise(0.12), 800) * env_exp(int(0.12 * SR), 0.03)), 0.2)
    riser = mix(sweep_filter(noise(1.3), 200, 6000, 0.5) * np.linspace(0.1, 1, int(1.3 * SR)), sine_sweep(1.3, 800, 100, -1.0) * np.linspace(0, 0.5, int(1.3 * SR)))
    boom = np.concatenate([np.zeros(int(1.2 * SR)), drive(thump(70, 25, 0.9) * 1.4 + lp(noise(0.9), 500) * env_exp(int(0.9 * SR), 0.3), 2)])
    S["super_start"] = reverb(mix(riser * 0.7, boom), 0.3, 1.2)
    S["super_impact"] = reverb(drive(mix(thump(65, 22, 1.0) * 1.5, lp(noise(0.9), 900) * env_exp(int(0.9 * SR), 0.25), bp(noise(0.1), 2000, 7000) * env_exp(int(0.1 * SR), 0.02)), 2.5), 0.35, 1.4)
    S["breaker"] = reverb(mix(whoosh(0.6, 200, 5000), partials([2600, 3900, 5200], [0.6, 0.4, 0.3], [0.4, 0.3, 0.2], 0.6), thump(90, 35, 0.4)), 0.35)
    S["ko"] = reverb(drive(mix(thump(55, 20, 1.6) * 1.6, lp(noise(1.4), 500) * env_exp(int(1.4 * SR), 0.5), metal(110, 2.0, 5) * 0.3), 2.2), 0.45, 1.8)
    gong_t = 3.5
    S["round_gong"] = reverb(mix(partials([98, 98 * 2.38, 98 * 3.1, 98 * 4.2, 98 * 5.7, 98 * 7.1], [1, 0.8, 0.6, 0.45, 0.3, 0.2], [3.0, 2.2, 1.6, 1.1, 0.8, 0.6], gong_t) * (1 + 0.15 * np.sin(2 * np.pi * 2.3 * t_axis(gong_t))), lp(noise(0.08), 900) * env_exp(int(0.08 * SR), 0.02)), 0.35, 1.5)
    chord = sum(lp(osc(f, 0.9, "saw", d), 2500) for f, d in ((146.83, 0), (174.61, 0.003), (220.0, -0.002), (293.66, 0.002)))
    S["fight"] = reverb(drive(mix(chord * env_ad(int(0.9 * SR), 0.01, 0.25) * 0.5, thump(80, 30, 0.6) * 1.2, lp(noise(0.3), 1500) * env_exp(int(0.3 * SR), 0.06) * 0.5), 1.6), 0.3, 1.2)
    S["countdown"] = reverb(mix(thump(70, 40, 0.6) * 1.2, lp(noise(0.1), 400) * env_exp(int(0.1 * SR), 0.03)), 0.3)
    drone = sum(osc(f, 3.0, "saw", d) for f, d in ((55, 0), (55, 0.004), (82.4, -0.003)))
    beats = np.zeros(int(3.0 * SR))
    for p in (0.3, 0.55, 1.3, 1.55, 2.3, 2.55):
        th = thump(60, 35, 0.2)
        beats[int(p * SR) : int(p * SR) + len(th)] += th
    S["finisher_ready"] = reverb(mix(lp(drone, 400) * env_ad(int(3.0 * SR), 1.0, 1.5) * 0.5, beats), 0.3, 1.4)
    sh = np.zeros(int(1.4 * SR))
    for i in range(60):
        p = int(RNG.uniform(0, 0.6) * SR)
        g = partials([RNG.uniform(2500, 9000)], [1], [RNG.uniform(0.05, 0.3)], 0.4) * RNG.uniform(0.2, 0.6)
        sh[p : p + len(g)] += g[: len(sh) - p]
    S["shatter"] = reverb(mix(sh, hp(noise(0.3), 2500) * env_exp(int(0.3 * SR), 0.08), thump(80, 30, 0.6)), 0.35, 1.2)
    # UI
    # comedic "oof" (our own synthesis)
    oof = formant_voice(150, 0.34, [(480, 950, 2450)], 1.0, 0.16, pitch_drop=0.5) * env_ad(int(0.34 * SR), 0.012, 0.1)
    S["oof"] = reverb(drive(oof, 2.4), 0.12, 0.5)
    # locomotion / body layers
    S["footstep"] = mix(thump(140, 70, 0.07) * 0.7, bp(noise(0.06), 400, 2200) * env_exp(int(0.06 * SR), 0.012) * 0.5)
    S["body_fall"] = reverb(mix(thump(70, 30, 0.42) * 1.2, lp(noise(0.3), 500) * env_exp(int(0.3 * SR), 0.06) * 0.8, np.concatenate([np.zeros(int(0.11 * SR)), thump(110, 50, 0.16) * 0.6])), 0.12, 0.5)
    # sub-bass layer that sits under heavy / special / super impacts
    S["impact_sub"] = drive(mix(sine_sweep(0.45, 70, 26, 2.5) * env_exp(int(0.45 * SR), 0.14) * 1.4, lp(noise(0.12), 250) * env_exp(int(0.12 * SR), 0.03) * 0.6), 1.5)
    S["ui_move"] = mix(bp(noise(0.03), 1500, 4000) * env_exp(int(0.03 * SR), 0.006) * 0.6, partials([2200], [0.3], [0.03], 0.05))
    S["ui_select"] = S["ui_move"]
    S["ui_confirm"] = reverb(mix(metal(1900, 0.45, 4) * 0.4, thump(120, 60, 0.15) * 0.6, hp(noise(0.2), 4000) * env_ad(int(0.2 * SR), 0.03, 0.06) * 0.4), 0.25)
    S["ui_back"] = whoosh(0.18, 1600, 500) * 0.6
    S["ui_lock"] = reverb(mix(thump(80, 35, 0.5) * 1.1, metal(2400, 0.6, 4) * 0.4, hp(noise(0.25), 3500) * env_ad(int(0.25 * SR), 0.04, 0.08) * 0.5), 0.3, 1.0)
    S["ui_versus"] = reverb(drive(mix(thump(60, 24, 0.9) * 1.4, whoosh(0.5, 300, 3000), lp(noise(0.6), 600) * env_exp(int(0.6 * SR), 0.2)), 2), 0.35, 1.3)
    return S


def voices():
    V = {}
    vowel_a = [(800, 1200, 2500)]
    vowel_u = [(450, 900, 2400)]
    vowel_e = [(600, 1800, 2600)]
    specs = {
        "m": (128, 1.0, 0.25),
        "f": (235, 1.18, 0.3),
        "d": (88, 0.9, 0.3),
        "h": (74, 0.85, 0.45),
    }
    for key, (f0, shift, breath) in specs.items():
        atk = formant_voice(f0, 0.24, vowel_a, shift, breath, pitch_drop=0.15) * env_ad(int(0.24 * SR), 0.015, 0.07)
        atk = drive(atk, 2.0)
        hurt = formant_voice(f0 * 1.15, 0.32, vowel_u + vowel_e, shift, breath + 0.1, pitch_drop=0.35) * env_ad(int(0.32 * SR), 0.01, 0.1)
        hurt = drive(hurt, 2.2)
        if key == "h":
            ring = np.sin(2 * np.pi * 37 * t_axis(0.24))
            atk = reverb(atk * (0.6 + 0.4 * ring), 0.45, 1.3)
            hurt = reverb(hurt * (0.6 + 0.4 * np.sin(2 * np.pi * 37 * t_axis(0.32))), 0.45, 1.3)
        elif key == "d":
            atk = reverb(atk, 0.15)
            hurt = reverb(hurt, 0.15)
        V[f"voice_{key}_attack"] = atk
        V[f"voice_{key}_hurt"] = hurt
    return V


def ambiences():
    A = {}
    dur = 24.0
    n = int(dur * SR)
    t = t_axis(dur)

    def loopable(x, xf=1.0):
        k = int(xf * SR)
        head = x[:k].copy()
        x = x[: len(x) - k]
        x[-k:] = x[-k:] * np.linspace(1, 0, k) + head * np.linspace(0, 1, k)
        return x

    wind = lp(noise(dur + 1), 500) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t_axis(dur + 1)))
    forest = wind * 0.4
    for i in range(30):
        p = int(RNG.uniform(0, dur) * SR)
        chirp = osc(RNG.uniform(3500, 5200), 0.08, "sine") * env_ad(int(0.08 * SR), 0.005, 0.02) * 0.15
        forest[p : p + len(chirp)] += chirp[: len(forest) - p]
    for i in range(14):
        p = int(RNG.uniform(0, dur) * SR)
        drip = sine_sweep(0.12, 1800, 900, 2) * env_exp(int(0.12 * SR), 0.03) * 0.2
        forest[p : p + len(drip)] += drip[: len(forest) - p]
    A["amb_forest"] = loopable(reverb(forest, 0.3, 1.2)[: int((dur + 1) * SR)])
    howl = sweep_filter(noise(dur + 1), 250, 900, 0.35, 96) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * t_axis(dur + 1)))
    A["amb_wind"] = loopable(howl + wind * 0.4)
    room = lp(noise(dur + 1), 200) * 0.4
    for i in range(22):
        p = int(RNG.uniform(0, dur) * SR)
        drip = sine_sweep(0.15, 2200, 1100, 2) * env_exp(int(0.15 * SR), 0.04) * 0.3
        room[p : p + len(drip)] += drip[: len(room) - p]
    choir = sum(osc(f, dur + 1, "sine", 0) for f in (220, 261.63, 329.63)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * t_axis(dur + 1))) * 0.05
    A["amb_cathedral"] = loopable(reverb(room + choir, 0.5, 1.6)[: int((dur + 1) * SR)])
    rumble = lp(noise(dur + 1), 120) * 1.2
    for i in range(40):
        p = int(RNG.uniform(0, dur) * SR)
        pop = lp(noise(0.05), 600) * env_exp(int(0.05 * SR), 0.01) * 0.4
        rumble[p : p + len(pop)] += pop[: len(rumble) - p]
    A["amb_lava"] = loopable(rumble)
    return A


# --------------------------------------------------------------------------- music
NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


class Track:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.len = bars * beats_per_bar * self.beat
        self.n = int(self.len * SR) + SR * 2
        self.L = np.zeros(self.n)
        self.R = np.zeros(self.n)

    def add(self, x, at_beat, pan=0.0, gain=1.0):
        p = int(at_beat * self.beat * SR)
        if p >= self.n:
            return
        x = x[: self.n - p] * gain
        lg = np.cos((pan + 1) * np.pi / 4)
        rg = np.sin((pan + 1) * np.pi / 4)
        self.L[p : p + len(x)] += x * lg
        self.R[p : p + len(x)] += x * rg

    def render(self, loop=True, verb=0.2, size=1.0):
        L = reverb(self.L, verb, size)[: self.n]
        R = reverb(self.R, verb, size * 1.07)[: self.n]
        end = int(self.len * SR)
        if loop:
            # fold the tail back onto the head so the loop seam is seamless
            tailL, tailR = L[end:], R[end:]
            L, R = L[:end], R[:end]
            k = min(len(tailL), end)
            L[:k] += tailL[:k]
            R[:k] += tailR[:k]
        return L, R


def taiko(f=62, dur=0.6, hard=1.0):
    return drive(mix(thump(f * 1.6, f, dur, 5) * hard, lp(noise(0.05), 800) * env_exp(int(0.05 * SR), 0.01) * 0.4), 1.4)


def tom(f=110):
    return thump(f * 1.5, f, 0.3, 5) * 0.8


def snare():
    return mix(bp(noise(0.18), 1200, 6000) * env_exp(int(0.18 * SR), 0.04) * 0.7, thump(220, 150, 0.08) * 0.4)


def hat(open_=False):
    d = 0.18 if open_ else 0.04
    return hp(noise(d), 7000) * env_exp(int(d * SR), d / 3) * 0.3


def bass_note(f, dur):
    x = lp(osc(f, dur, "saw") + 0.5 * osc(f / 2, dur, "sine"), 380)
    return x * env_ad(int(dur * SR), 0.005, dur * 0.6)


def pad_chord(freqs, dur, bright=1400):
    x = np.zeros(int(dur * SR))
    for f in freqs:
        for d in (-0.004, 0.0, 0.005):
            x += osc(f, dur, "saw", d)
    x = lp(x, bright)
    a = int(min(0.6, dur / 3) * SR)
    e = np.ones(len(x))
    e[:a] = np.linspace(0, 1, a)
    r = int(min(0.6, dur / 3) * SR)
    e[-r:] *= np.linspace(1, 0, r)
    return x * e / (len(freqs) * 3)


def choir_chord(freqs, dur):
    x = np.zeros(int(dur * SR))
    for f in freqs:
        x += formant_voice(f, dur, [(700, 1150, 2600)], 1.0, 0.15, vib=0.006)
    a = int(min(0.4, dur / 3) * SR)
    e = np.ones(len(x))
    e[:a] = np.linspace(0, 1, a)
    e[-a:] *= np.linspace(1, 0, a)
    return x * e / len(freqs)


def pluck(f, dur=0.9):
    return karplus_fast(f, dur, 0.995) * env_exp(int(dur * SR), dur / 2.5)


def flute(f, dur):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 5 * t)) + 0.15 * bp(noise(dur), f * 0.8, f * 1.6)
    return x * env_ad(int(dur * SR), 0.06, dur * 0.8)


def brass(freqs, dur):
    x = np.zeros(int(dur * SR))
    for f in freqs:
        x += osc(f, dur, "saw", 0.002) + osc(f, dur, "saw", -0.003)
    # filter envelope: bright attack
    n = len(x)
    out = np.zeros(n)
    edges = np.linspace(0, n, 12).astype(int)
    for i in range(11):
        a, b = edges[i], edges[i + 1]
        fc = 3200 * np.exp(-i / 4) + 500
        seg = lp(x[max(0, a - 256):b], fc)
        out[a:b] = seg[-(b - a):]
    return out * env_ad(n, 0.02, dur * 0.7) / (len(freqs) * 2)


def scale_minor(root_midi):
    steps = [0, 2, 3, 5, 7, 8, 10]
    return [root_midi + s for s in steps]


def chord_freqs(root, kind="m"):
    third = 3 if kind == "m" else 4
    return [midi(root), midi(root + third), midi(root + 7)]


def music_menu():
    tr = Track(72, 16)
    prog = [50, 46, 41, 48]  # Dm, Bb, F, C
    kinds = ["m", "M", "M", "M"]
    for bar in range(16):
        r = prog[bar % 4]
        k = kinds[bar % 4]
        tr.add(pad_chord(chord_freqs(r, k), tr.beat * 4.2, 1100), bar * 4, -0.3, 0.9)
        tr.add(choir_chord(chord_freqs(r + 12, k), tr.beat * 4.1), bar * 4, 0.3, 0.35)
        tr.add(bass_note(midi(r - 12), tr.beat * 3.8), bar * 4, 0, 0.6)
        tr.add(taiko(55, 1.0, 1.2), bar * 4, 0, 0.7)
        if bar % 2 == 1:
            tr.add(taiko(70, 0.6), bar * 4 + 2.5, 0.2, 0.4)
    mel = [62, 65, 69, 67, 65, 62, 60, 62, 65, 64, 62, 57]
    for i, m in enumerate(mel):
        tr.add(pluck(midi(m + 12), 1.4), 16 + i * 2 + (i % 3) * 0.5, 0.4, 0.45)
        tr.add(pluck(midi(m + 12), 1.4), 40 + i * 2, -0.4, 0.35)
    return tr.render(True, 0.35, 1.4)


def music_select():
    tr = Track(100, 16)
    prog = [52, 52, 48, 50]  # Em Em C D
    for bar in range(16):
        r = prog[bar % 4]
        for b in range(8):
            tr.add(bass_note(midi(r - 12 + (7 if b % 4 == 3 else 0)), tr.beat * 0.45), bar * 4 + b * 0.5, 0, 0.55)
        tr.add(taiko(60, 0.5), bar * 4, 0, 0.8)
        tr.add(taiko(60, 0.5), bar * 4 + 1.5, 0, 0.5)
        tr.add(tom(140), bar * 4 + 2, 0.3, 0.5)
        tr.add(snare(), bar * 4 + 3, -0.2, 0.35)
        for h in range(8):
            tr.add(hat(), bar * 4 + h * 0.5, 0.5, 0.5)
        if bar % 2 == 0:
            tr.add(pad_chord(chord_freqs(r, "m" if r == 52 else "M"), tr.beat * 8, 1600), bar * 4, -0.4, 0.5)
    for i, m in enumerate([64, 67, 71, 69, 67, 64, 62, 64]):
        tr.add(pluck(midi(m + 12), 0.8), 32 + i * 1.5, 0.3, 0.4)
    return tr.render(True, 0.22)


def battle(bpm, root, bars, prog, kinds, lead="pluck", choir=False, seed_mel=None, intensity=1.0):
    tr = Track(bpm, bars)
    sc = scale_minor(root + 12)
    pent = [sc[0], sc[2], sc[3], sc[4], sc[6]]
    rng = np.random.default_rng(seed_mel or 1)
    for bar in range(bars):
        r = prog[bar % len(prog)]
        k = kinds[bar % len(kinds)]
        # drums
        pat = [0, 0.75, 1.5, 2, 2.75, 3.5]
        for p in pat:
            tr.add(taiko(58, 0.45, 1.0 * intensity), bar * 4 + p, 0, 0.75 if p in (0, 2) else 0.45)
        tr.add(snare(), bar * 4 + 1, -0.2, 0.45 * intensity)
        tr.add(snare(), bar * 4 + 3, -0.2, 0.5 * intensity)
        if bar % 4 == 3:
            for i in range(4):
                tr.add(tom(180 - i * 25), bar * 4 + 3 + i * 0.25, 0.3 - i * 0.2, 0.5)
        for h in range(8):
            tr.add(hat(h == 7), bar * 4 + h * 0.5, 0.45, 0.45)
        # bass ostinato
        for b in range(8):
            n = r - 12 + ([0, 0, 7, 0, 10, 0, 7, 3][b])
            tr.add(bass_note(midi(n), tr.beat * 0.45), bar * 4 + b * 0.5, 0, 0.6)
        # harmony
        if bar % 2 == 0:
            tr.add(pad_chord(chord_freqs(r, k), tr.beat * 8, 1800), bar * 4, -0.35, 0.45)
            if choir:
                tr.add(choir_chord(chord_freqs(r + 12, k), tr.beat * 8), bar * 4, 0.35, 0.35)
        if bar % 4 == 0:
            tr.add(brass(chord_freqs(r, k), tr.beat * 1.2), bar * 4, 0.1, 0.5)
            tr.add(brass(chord_freqs(r, k), tr.beat * 0.6), bar * 4 + 2.5, 0.1, 0.35)
        # lead in the second half of each 8-bar phrase
        if (bar // 4) % 2 == 1:
            for b in range(8):
                if rng.random() < 0.7:
                    m = pent[int(rng.integers(0, len(pent)))] + (12 if rng.random() < 0.3 else 0)
                    if lead == "pluck":
                        tr.add(pluck(midi(m), 0.5), bar * 4 + b * 0.5, 0.35, 0.35)
                    else:
                        tr.add(flute(midi(m), tr.beat * 0.48), bar * 4 + b * 0.5, 0.35, 0.3)
    return tr.render(True, 0.2)


def music_story():
    tr = Track(64, 12)
    prog = [45, 41, 48, 43]  # Am F C G
    kinds = ["m", "M", "M", "M"]
    for bar in range(12):
        r = prog[bar % 4]
        tr.add(pad_chord(chord_freqs(r, kinds[bar % 4]), tr.beat * 4.2, 900), bar * 4, -0.3, 0.8)
        tr.add(bass_note(midi(r - 12), tr.beat * 4), bar * 4, 0, 0.4)
        if bar >= 4:
            tr.add(choir_chord(chord_freqs(r + 12, kinds[bar % 4]), tr.beat * 4), bar * 4, 0.3, 0.25)
    mel = [69, 72, 71, 67, 69, 65, 64, 62, 64, 67, 69, 72]
    for i, m in enumerate(mel):
        tr.add(pluck(midi(m), 1.8), 16 + i * 2.5, 0.3, 0.4)
    for b in range(0, 48, 8):
        tr.add(taiko(50, 1.2, 0.8), b, 0, 0.35)
    return tr.render(True, 0.4, 1.5)


def music_victory():
    tr = Track(110, 6)
    seq = [(50, "m", 0), (46, "M", 2), (48, "M", 4), (50, "M", 6), (50, "M", 8)]
    for r, k, b in seq:
        tr.add(brass(chord_freqs(r, k), tr.beat * (2 if b < 8 else 8)), b, 0, 0.8)
        tr.add(taiko(60, 0.6, 1.2), b, 0, 0.8)
        tr.add(pad_chord(chord_freqs(r, k), tr.beat * 2.2, 2000), b, -0.3, 0.4)
    for i in range(4):
        tr.add(tom(160 - i * 20), 7 + i * 0.25, 0.2, 0.6)
    tr.add(choir_chord(chord_freqs(62, "M"), tr.beat * 10), 8, 0.2, 0.4)
    return tr.render(False, 0.35, 1.3)


def main():
    only = set(sys.argv[1:])
    if only:
        allfx = {**sfx(), **voices()}
        for name in only:
            write(name, fade(np.asarray(allfx[name], dtype=float), 0.001, 0.01))
        print("wrote", ", ".join(sorted(only)))
        return
    made = []
    for name, x in sfx().items():
        made.append(write(name, fade(np.asarray(x, dtype=float), 0.001, 0.01)))
    for name, x in voices().items():
        made.append(write(name, fade(np.asarray(x, dtype=float), 0.002, 0.02)))
    for name, x in ambiences().items():
        made.append(write(name, x, peak=0.6))
    music = {
        "music_menu": music_menu(),
        "music_select": music_select(),
        "music_battle_a": battle(140, 52, 32, [52, 48, 50, 47], ["m", "M", "M", "m"], "pluck", False, 3, 1.0),
        "music_battle_b": battle(124, 50, 32, [50, 46, 45, 48], ["m", "M", "m", "M"], "flute", True, 5, 0.9),
        "music_boss": battle(150, 50, 32, [50, 51, 50, 48], ["m", "M", "m", "M"], "pluck", True, 9, 1.2),
        "music_story": music_story(),
        "music_victory": music_victory(),
    }
    for name, (L, R) in music.items():
        made.append(write(name, L, R, peak=0.85))
    print(f"wrote {len(made)} files to {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
