"""Import the user-supplied sound pack from audio/user/ into the audio pipeline.

    python3 tools/import_user_sounds.py && python3 tools/build_atlas.py

SFX are trimmed, peak-normalised and faded, then written to audio/<name>.ogg so
build_atlas.py packs them into the SFX atlas. The announcer file is split on its
pauses into one clip per line (audio/ann_*.ogg), which build_atlas.py packs into a
separate atlas (veil_announcer.ogg) so it can be uploaded - or left out - on its own.

Analysis of the supplied files (tools/import_user_sounds.py --analyse):
    bass_hit.mp3   0.56 s  75% of energy below 120 Hz, 50 ms attack -> sub impact
    swell.mp3      5.0 s   tonal 120 Hz-2 kHz swell, 0.25 s attack  -> finisher / super sting
    crack.mp3      1.9 s   broadband, 3 ms attack, ~1 s tail        -> big-hit crack
    slam.mp3       2.1 s   sub + low boom, 26 ms attack             -> body slam / knockdown
    announcer_lines.mp3  13.8 s mono speech, six phrases (fish.audio voice): choose,
                   round one, fight, finish him, fatality, flawless victory
"""
import os
import subprocess
import sys
import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.normpath(os.path.join(HERE, "..", "audio"))
USER = os.path.join(AUDIO, "user")

SFX = {
    "bass_hit.mp3": "user_bass_hit",
    "swell.mp3": "user_swell",
    "crack.mp3": "user_crack",
    "slam.mp3": "user_slam",
}
ANNOUNCER = "announcer_lines.mp3"
# phrase order inside the announcer file (found by silence segmentation + phrase matching)
ANNOUNCER_LINES = ["ann_choose", "ann_round1", "ann_fight", "ann_finish_him", "ann_fatality", "ann_flawless"]


def decode(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).copy()


def encode(path, data):
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "6", path], input=pcm, check=True)


def envelope_db(x, win=0.02):
    mono = np.abs(x).max(axis=1)
    n = int(SR * win)
    k = len(mono) // n
    rms = np.sqrt(np.mean(mono[: k * n].reshape(k, n) ** 2, axis=1) + 1e-12)
    return 20 * np.log10(rms + 1e-9), n


def trim(x, thresh_db=-50, pad=0.02):
    db, n = envelope_db(x)
    on = np.where(db > thresh_db)[0]
    if len(on) == 0:
        return x
    a = max(0, on[0] * n - int(pad * SR))
    b = min(len(x), (on[-1] + 1) * n + int(pad * 4 * SR))
    return x[a:b]


def finish(x, peak=0.89, fade_in=0.003, fade_out=0.015):
    x = x.copy()
    m = np.max(np.abs(x))
    if m > 0:
        x *= peak / m
    fi, fo = int(fade_in * SR), int(fade_out * SR)
    if len(x) > fi + fo:
        x[:fi] *= np.linspace(0, 1, fi)[:, None]
        x[-fo:] *= np.linspace(1, 0, fo)[:, None]
    return x


def segments(x, thresh_db=-40, min_gap=0.18):
    db, n = envelope_db(x)
    active = db > thresh_db
    segs, start, gap = [], None, 0
    for i, a in enumerate(active):
        if a:
            if start is None:
                start = i
            gap = 0
        elif start is not None:
            gap += 1
            if gap * 0.02 >= min_gap:
                segs.append((start * n, (i - gap + 1) * n))
                start, gap = None, 0
    if start is not None:
        segs.append((start * n, len(active) * n))
    return segs


def main():
    made = []
    for src, name in SFX.items():
        p = os.path.join(USER, src)
        if not os.path.exists(p):
            continue
        out = os.path.join(AUDIO, name + ".ogg")
        encode(out, finish(trim(decode(p))))
        made.append(name)
    p = os.path.join(USER, ANNOUNCER)
    if os.path.exists(p):
        x = decode(p)
        segs = segments(x)
        if len(segs) != len(ANNOUNCER_LINES):
            print(f"warning: expected {len(ANNOUNCER_LINES)} phrases, found {len(segs)}; using the first ones")
        for (a, b), name in zip(segs, ANNOUNCER_LINES):
            a = max(0, a - int(0.06 * SR))
            b = min(len(x), b + int(0.12 * SR))
            encode(os.path.join(AUDIO, name + ".ogg"), finish(x[a:b], peak=0.92, fade_out=0.04))
            made.append(f"{name} ({(b - a) / SR:.2f}s)")
    print("imported:", ", ".join(made))


if __name__ == "__main__":
    if "--analyse" in sys.argv:
        print(__doc__)
    else:
        main()
