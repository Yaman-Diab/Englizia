"""Englizia's sound effects, synthesized: one family (marimba, soft bells,
xylophone for kids), one key (C major pentatonic), WAV 44.1 kHz mono 16-bit,
silence trimmed, peaks at -3 dBFS.

    python -I tool/sounds/synth.py assets/sounds

Deterministic (fixed seed), so the same files come out every time. Needs
numpy. These are placeholders (assets/sounds/LICENSES.md): a recorded or
licensed file replaces one by its name, and its line in the catalog
(lib/core/audio/sound_catalog.dart) stays.
"""
import io
import sys
import wave
from pathlib import Path

import numpy as np

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
SR = 44100
RNG = np.random.default_rng(20261109)
NOTES = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
         "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}


def hz(name):
    """'C6' -> 1046.5"""
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTES[pitch] + 12 * (octave - 4)) / 12)


def t(seconds):
    return np.arange(int(seconds * SR)) / SR


def attack(n_samples, ms):
    a = min(n_samples, max(1, int(ms * SR / 1000)))
    env = np.ones(n_samples)
    env[:a] = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    return env


def lowpass(x, cutoff):
    """One-pole lowpass."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def mallet(length, vel, cutoff=3200, level=0.05):
    """The soft knock of the mallet on the bar: a few ms of filtered noise."""
    n = int(0.012 * SR)
    noise = RNG.standard_normal(n) * np.exp(-np.arange(n) / (0.0022 * SR))
    knock = lowpass(noise, cutoff) * level * vel
    out = np.zeros(length)
    out[:n] = knock[:length]
    return out


def modal(f, dur, ratios, amps, taus, vel=1.0, attack_ms=1.6,
          knock=0.05, knock_cut=3200):
    """A struck bar: partials at f*ratios, each decaying with its own tau."""
    tt = t(dur)
    y = np.zeros_like(tt)
    for r, a, tau in zip(ratios, amps, taus):
        fr = f * r
        if fr >= SR / 2 * 0.95:
            continue
        y += a * np.sin(2 * np.pi * fr * tt + RNG.uniform(0, 0.3)) * np.exp(-tt / tau)
    y *= attack(len(tt), attack_ms)
    y += mallet(len(tt), vel, knock_cut, knock)
    return y * vel


def marimba(note, dur=1.2, vel=1.0, bright=0.8, damp=1.0):
    f = hz(note) if isinstance(note, str) else note
    t1 = 0.62 * (440 / f) ** 0.55 * damp
    return modal(f, dur,
                 ratios=[1.0, 3.93, 9.54],
                 amps=[1.0, 0.34 * bright, 0.09 * bright],
                 taus=[t1, t1 * 0.20, t1 * 0.06],
                 vel=vel, knock=0.045 * bright)


def xylophone(note, dur=0.9, vel=1.0, bright=1.0):
    f = hz(note) if isinstance(note, str) else note
    t1 = 0.30 * (440 / f) ** 0.40
    return modal(f, dur,
                 ratios=[1.0, 3.0, 6.2],
                 amps=[1.0, 0.42 * bright, 0.14 * bright],
                 taus=[t1, t1 * 0.30, t1 * 0.10],
                 vel=vel, attack_ms=0.8, knock=0.09 * bright, knock_cut=5200)


def celesta(note, dur=1.6, vel=1.0):
    """A soft bell: near-harmonic partials, long ring."""
    f = hz(note) if isinstance(note, str) else note
    t1 = 1.1 * (880 / f) ** 0.5
    return modal(f, dur,
                 ratios=[1.0, 2.0, 3.01, 4.17],
                 amps=[1.0, 0.28, 0.10, 0.05],
                 taus=[t1, t1 * 0.45, t1 * 0.25, t1 * 0.15],
                 vel=vel, attack_ms=2.5, knock=0.02)


def glass(note, dur=1.4, vel=1.0):
    """A glassy, colder bell: inharmonic partials."""
    f = hz(note) if isinstance(note, str) else note
    t1 = 0.75 * (1500 / f) ** 0.4
    return modal(f, dur,
                 ratios=[1.0, 2.32, 4.25, 6.63],
                 amps=[1.0, 0.45, 0.22, 0.10],
                 taus=[t1, t1 * 0.6, t1 * 0.35, t1 * 0.2],
                 vel=vel, attack_ms=1.2, knock=0.015, knock_cut=7000)


def woodblock(f, vel=1.0):
    return modal(f, 0.09, ratios=[1.0, 2.07, 3.4], amps=[1.0, 0.35, 0.12],
                 taus=[0.018, 0.009, 0.005], vel=vel, attack_ms=0.4,
                 knock=0.10, knock_cut=6000)


def glide(f0, f1, dur, shape=0.6, harmonics=(1.0, 0.18, 0.05), vel=1.0,
          release=0.04, vibrato_hz=0.0, vibrato_depth=0.0, vibrato_decay=0.2):
    """A tone sliding from f0 to f1 (exponentially), with a soft envelope."""
    tt = t(dur)
    k = (tt / dur) ** shape
    f = f0 * (f1 / f0) ** k
    if vibrato_hz:
        f = f * (1 + vibrato_depth * np.exp(-tt / vibrato_decay)
                 * np.sin(2 * np.pi * vibrato_hz * tt))
    phase = 2 * np.pi * np.cumsum(f) / SR
    y = sum(a * np.sin((i + 1) * phase) for i, a in enumerate(harmonics))
    env = attack(len(tt), 5)
    rel = int(release * SR)
    env[-rel:] *= np.linspace(1, 0, rel) ** 1.5
    env *= np.exp(-tt / (dur * 0.9))
    return y * env * vel


def shimmer(dur, lo, hi, rise=0.0, count=70, attack_s=0.2, decay_s=0.6, vel=1.0):
    """An airy, noise-like band of many quiet sines, optionally drifting up."""
    tt = t(dur)
    y = np.zeros_like(tt)
    for _ in range(count):
        f0 = RNG.uniform(lo, hi)
        f = f0 * (1 + rise * (tt / dur))
        phase = 2 * np.pi * np.cumsum(f) / SR + RNG.uniform(0, 2 * np.pi)
        y += np.sin(phase) * RNG.uniform(0.4, 1.0)
    y /= count ** 0.5
    env = np.minimum(1, tt / max(attack_s, 1e-3)) * np.exp(
        -np.maximum(0, tt - attack_s) / decay_s)
    return y * env * vel


def noise_burst(dur, lo, hi, vel=1.0, shape=None):
    """Band-limited noise through an envelope [(time, level), ...]."""
    tt = t(dur)
    spec = np.fft.rfft(RNG.standard_normal(len(tt)))
    freqs = np.fft.rfftfreq(len(tt), 1 / SR)
    spec[(freqs < lo) | (freqs > hi)] = 0
    x = np.fft.irfft(spec, len(tt))
    x /= np.max(np.abs(x)) + 1e-9
    if shape:
        times, levels = zip(*shape)
        x *= np.interp(tt, times, levels)
    return x * vel


def mix(parts, extra=0.6):
    """parts: [(offset_seconds, signal)] -> one signal with room for its tail."""
    end = max(off + len(sig) / SR for off, sig in parts)
    out = np.zeros(int((end + extra) * SR))
    for off, sig in parts:
        i = int(off * SR)
        out[i:i + len(sig)] += sig
    return out


def reverb(x, wet=0.12, room=0.74):
    """A small Schroeder room, for warmth, not for space."""
    combs = [1557, 1617, 1491, 1422]
    allpasses = [556, 441]
    y = np.zeros(len(x))
    for d in combs:
        buf = np.zeros(len(x))
        for i in range(len(x)):
            buf[i] = x[i] + (room * buf[i - d] if i >= d else 0.0)
        y += buf
    y /= len(combs)
    for d in allpasses:
        out = np.zeros(len(y))
        for i in range(len(y)):
            delayed = y[i - d] if i >= d else 0.0
            prev = out[i - d] if i >= d else 0.0
            out[i] = -0.5 * y[i] + delayed + 0.5 * prev
        y = out
    return (1 - wet) * x + wet * y


def finish(x, max_s=None, tail_db=-60.0, peak_db=-3.0):
    """DC out, silence trimmed both ends (with a short fade), at most [max_s]
    long (its last quarter fading as a ring would), peak normalized."""
    x = x - np.mean(x)
    peak = np.max(np.abs(x)) + 1e-12
    gate = peak * 10 ** (-50 / 20)
    idx = np.nonzero(np.abs(x) > gate)[0]
    start = max(0, idx[0] - int(0.002 * SR))
    x = x[start:]
    floor = peak * 10 ** (tail_db / 20)
    env = np.abs(x)
    above = np.nonzero(env > floor)[0]
    end = min(len(x), above[-1] + int(0.01 * SR))
    x = x[:end]
    if max_s is not None and len(x) > max_s * SR:
        x = x[: int(max_s * SR)]
        ring = len(x) // 4
        x[-ring:] *= np.exp(-np.linspace(0, 6, ring))
    fade = min(len(x) // 4, int(0.015 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    x *= 10 ** (peak_db / 20) / (np.max(np.abs(x)) + 1e-12)
    return x


def loudness(x):
    """The loudest 100 ms, as RMS dBFS: close to how loud it feels."""
    w = int(0.1 * SR)
    if len(x) <= w:
        rms = np.sqrt(np.mean(x ** 2))
    else:
        c = np.cumsum(np.concatenate([[0], x ** 2]))
        rms = np.sqrt(np.max(c[w:] - c[:-w]) / w)
    return 20 * np.log10(rms + 1e-12)


def write(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    dither = (RNG.random(len(x)) - RNG.random(len(x))) / 32768
    pcm = np.clip((x + dither) * 32767, -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# ---- The sounds -----------------------------------------------------------

def correct():
    # Two warm notes a fourth apart, up: G5 then C6. Low enough to hear 50
    # times in a row without it going sharp.
    return reverb(mix([(0.0, marimba("G5", 0.7, 0.85, 0.75)),
                       (0.085, marimba("C6", 0.8, 1.0, 0.75))], 0.3), 0.10)


def incorrect():
    # Two soft notes down, rounder and shorter: E5 then B4. No buzz.
    return reverb(mix([(0.0, marimba("E5", 0.45, 0.8, 0.45, damp=0.55)),
                       (0.105, marimba("B4", 0.5, 0.75, 0.40, damp=0.55))], 0.2), 0.08)


def tap():
    return woodblock(1450, 0.9)


def lesson_complete():
    run = [(0.0, "C5"), (0.085, "E5"), (0.17, "G5")]
    parts = [(o, marimba(n, 0.9, 0.75 + 0.05 * i, 0.8)) for i, (o, n) in enumerate(run)]
    parts += [(0.27, marimba("C6", 1.4, 1.0, 0.85)),
              (0.27, marimba("E6", 1.3, 0.7, 0.7)),
              (0.27, marimba("G5", 1.3, 0.55, 0.6)),
              (0.27, celesta("C7", 1.3, 0.22))]
    return reverb(mix(parts, 0.5), 0.14)


def achievement():
    run = ["C5", "E5", "G5", "C6", "E6", "G6"]
    parts = [(0.07 * i, marimba(n, 0.9, 0.65 + 0.06 * i, 0.8)) for i, n in enumerate(run)]
    chord = 0.47
    parts += [(chord, marimba("C6", 2.0, 1.0, 0.9)),
              (chord, marimba("E6", 1.9, 0.75, 0.8)),
              (chord, marimba("G6", 1.8, 0.65, 0.8)),
              (chord, marimba("C5", 2.0, 0.55, 0.6)),
              (chord + 0.02, celesta("C7", 2.0, 0.30)),
              (chord + 0.06, celesta("E7", 1.8, 0.22)),
              (chord + 0.10, celesta("G7", 1.6, 0.16)),
              (chord, shimmer(1.6, 5000, 9000, 0.0, attack_s=0.05, decay_s=0.5, vel=0.05))]
    return reverb(mix(parts, 0.6), 0.18)


def island_unlock():
    # Airy and rising, glass instead of wood: heard right after achievement,
    # it must not sound like a second fanfare.
    parts = [(0.0, shimmer(1.35, 1200, 2600, rise=0.9, attack_s=0.45, decay_s=0.55, vel=0.16))]
    for i, n in enumerate(["E6", "G6", "A6", "C7", "E7"]):
        parts.append((0.30 + 0.085 * i, glass(n, 1.0, 0.42 - 0.04 * i)))
    return reverb(mix(parts, 0.4), 0.16)


def daily_goal():
    # A warm "fwoom" that catches, then a glint: the flame lighting up.
    parts = [(0.0, noise_burst(0.75, 180, 1500, 0.26,
                               [(0, 0), (0.22, 1), (0.42, 0.35), (0.75, 0)])),
             (0.0, shimmer(0.7, 300, 900, rise=1.2, attack_s=0.25, decay_s=0.25, vel=0.12)),
             (0.26, celesta("A5", 1.0, 0.75)),
             (0.36, celesta("E6", 0.9, 0.6))]
    return reverb(mix(parts, 0.4), 0.12)


def mic_on():
    return glide(hz("E5"), hz("B5"), 0.15, shape=0.5, vel=0.9, release=0.035)


def mic_off():
    return glide(hz("B5"), hz("E5"), 0.15, shape=0.5, vel=0.9, release=0.035)


def save_word():
    # A soft pop: a quick bubble rising, then gone.
    pop = glide(380, 1150, 0.11, shape=0.35, harmonics=(1.0, 0.1), vel=0.9, release=0.05)
    return mix([(0.0, pop), (0.0, woodblock(2200, 0.12))], 0.05)


def freeze():
    parts = [(0.0, noise_burst(0.05, 4000, 11000, 0.10,
                               [(0, 1), (0.012, 0.5), (0.05, 0)]))]
    for i, n in enumerate(["B6", "E7", "G#7", "B7"]):
        parts.append((0.03 + 0.07 * i, glass(n, 1.0, 0.55 - 0.06 * i)))
    parts.append((0.02, shimmer(1.0, 6500, 9500, rise=-0.08, attack_s=0.12, decay_s=0.45, vel=0.08)))
    return reverb(mix(parts, 0.3), 0.14)


def notification():
    # The app's signature: up a sixth, then settling on the fifth.
    parts = [(0.0, marimba("E5", 1.0, 0.85, 0.75)),
             (0.14, marimba("C6", 1.1, 1.0, 0.8)),
             (0.14, celesta("C7", 0.9, 0.18)),
             (0.30, marimba("G5", 1.2, 0.85, 0.75))]
    return reverb(mix(parts, 0.4), 0.14)


def xp_tick():
    return woodblock(2600, 0.7)[: int(0.04 * SR)]


def card_flip():
    return mix([(0.0, noise_burst(0.13, 1800, 7000, 0.6,
                                  [(0, 0), (0.025, 1), (0.05, 0.25), (0.08, 0.7), (0.13, 0)]))],
               0.02)


# Kids: the same key, a toy's colours.

def kids_correct():
    parts = [(0.06 * i, xylophone(n, 0.7, 0.8 + 0.1 * i)) for i, n in enumerate(["C6", "E6", "G6"])]
    return reverb(mix(parts, 0.2), 0.08)


def kids_incorrect():
    # A soft, funny boing: a spring wobbling down. Never a "you failed".
    boing = glide(330, 175, 0.42, shape=0.7, harmonics=(1.0, 0.22, 0.06), vel=0.9,
                  release=0.08, vibrato_hz=15, vibrato_depth=0.07, vibrato_decay=0.25)
    return mix([(0.0, boing)], 0.05)


def kids_lesson_complete():
    run = ["C6", "D6", "E6", "G6", "A6", "C7"]
    parts = [(0.045 * i, xylophone(n, 0.6, 0.7 + 0.05 * i)) for i, n in enumerate(run)]
    parts.append((0.30, glide(650, 1500, 0.34, shape=0.8, harmonics=(1.0, 0.08), vel=0.34,
                              release=0.06, vibrato_hz=7, vibrato_depth=0.012, vibrato_decay=1.0)))
    chord = 0.70
    parts += [(chord, xylophone("C7", 1.0, 1.0)),
              (chord, xylophone("E6", 1.0, 0.8)),
              (chord, xylophone("G6", 1.0, 0.7)),
              (chord + 0.04, celesta("E7", 1.0, 0.25))]
    return reverb(mix(parts, 0.4), 0.12)


def kids_star():
    parts = [(0.03 * i, celesta(n, 0.7, 0.6 - 0.07 * i)) for i, n in enumerate(["G6", "B6", "D7", "G7"])]
    parts.append((0.0, shimmer(0.5, 7000, 10500, attack_s=0.04, decay_s=0.2, vel=0.07)))
    return reverb(mix(parts, 0.2), 0.10)


def bulbul():
    def chirp(f0, f1, dur, vel):
        tt = t(dur)
        y = glide(f0, f1, dur, shape=0.45, harmonics=(1.0, 0.06), vel=vel, release=0.02)
        return y * (0.75 + 0.25 * np.sin(2 * np.pi * 32 * tt))
    return mix([(0.0, chirp(2600, 4100, 0.075, 0.8)),
                (0.13, chirp(2900, 4500, 0.085, 0.9))], 0.03)


# The longest each may last (the brief's durations).
MAX = {
    "correct.wav": 0.48, "incorrect.wav": 0.32, "island_unlock.wav": 1.45,
    "daily_goal.wav": 1.1, "freeze.wav": 1.05, "notification.wav": 1.4,
    "lesson_complete.wav": 1.9, "achievement.wav": 2.8,
    "kids/correct.wav": 0.6, "kids/star.wav": 0.7, "kids/lesson_complete.wav": 1.9,
}

# Peaks below -3 dBFS, to sound as loud as the same event's other file.
PEAK = {"kids/incorrect.wav": -5.6}

SOUNDS = {
    "correct.wav": (correct, "Two warm marimba notes up, G5 to C6"),
    "incorrect.wav": (incorrect, "Two soft, damped marimba notes down, E5 to B4"),
    "tap.wav": (tap, "A light woodblock knock"),
    "lesson_complete.wav": (lesson_complete, "Marimba C-E-G up to a C major chord, a bell on top"),
    "achievement.wav": (achievement, "Marimba arpeggio over two octaves to a full chord with bells and sparkle"),
    "island_unlock.wav": (island_unlock, "A rising airy shimmer with five glass bells"),
    "daily_goal.wav": (daily_goal, "A warm swell catching, then two bell glints"),
    "mic_on.wav": (mic_on, "A rounded blip gliding up E5 to B5"),
    "mic_off.wav": (mic_off, "A rounded blip gliding down B5 to E5"),
    "save_word.wav": (save_word, "A soft bubble pop"),
    "freeze.wav": (freeze, "A tiny crackle, then four cold glass bells and a frosty shimmer"),
    "notification.wav": (notification, "Marimba E5, C6, G5: the app's three-note signature"),
    "xp_tick.wav": (xp_tick, "A very short, high woodblock tick"),
    "card_flip.wav": (card_flip, "A light paper flick"),
    "kids/correct.wav": (kids_correct, "Xylophone C6-E6-G6, quick and bright"),
    "kids/incorrect.wav": (kids_incorrect, "A soft spring boing, wobbling down"),
    "kids/lesson_complete.wav": (kids_lesson_complete, "A xylophone run, a slide whistle up, a final chord"),
    "kids/star.wav": (kids_star, "Four quick bell notes up with a twinkle"),
    "kids/bulbul.wav": (bulbul, "Two little bird chirps"),
}

if __name__ == "__main__":
    out = Path(sys.argv[1])
    for name, (make, about) in SOUNDS.items():
        # A kids' file shares its event's volume: one louder than the
        # grown-ups' file is brought down to it.
        x = finish(make(), MAX.get(name), peak_db=PEAK.get(name, -3.0))
        write(out / name, x)
        size = (out / name).stat().st_size
        print(f"{name:28} {len(x) / SR:6.3f}s  loud {loudness(x):6.1f} dB  {size / 1024:6.1f} KB")
