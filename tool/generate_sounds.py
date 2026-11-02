#!/usr/bin/env python3
"""Generates the game sounds as small mono 16-bit WAV files.

Python 3 standard library only. The output is deterministic (fixed random
seeds), so running the script twice yields byte-identical files.

  reveal, flag, boom, win      44100 Hz  core effects
  level_up, new_best, daily    44100 Hz  retention moments (each < 0.45 s)
  music_loop                   16000 Hz  light, playful garden loop (~28 s)

The music runs at 16 kHz so the loop stays under 1 MB (its content is
low-passed well below 8 kHz anyway). It is rendered on a circular timeline:
note tails wrap around the end and every filter or echo runs over two tiled
periods with the second kept, so the last sample flows into the first
without a click.

Usage: python3 tool/generate_sounds.py
Writes assets/audio/<name>.wav relative to the repository root.
"""
import math
import os
import random
import struct
import wave

RATE = 44100
PEAK = 10 ** (-3 / 20)  # about -3 dBFS


def envelope(n, attack=0.006, release=0.03):
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    out = []
    for i in range(n):
        gain = 1.0
        if i < a:
            gain = i / a
        if i > n - r:
            gain = min(gain, (n - i) / r)
        out.append(gain)
    return out


def tone(freq, dur, end_freq=None, shape="sine", decay=4.0, harmonic=0.0):
    """One note with optional pitch glide, exponential decay and 2nd harmonic."""
    n = int(dur * RATE)
    env = envelope(n)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = freq if end_freq is None else freq + (end_freq - freq) * t
        phase += 2 * math.pi * f / RATE
        if shape == "triangle":
            v = (2 / math.pi) * math.asin(math.sin(phase))
        else:
            v = math.sin(phase)
        if harmonic:
            v += harmonic * math.sin(2 * phase)
        samples.append(v * env[i] * math.exp(-decay * t))
    return samples


def noise(dur, decay=6.0, seed=1, smooth=0.6):
    rng = random.Random(seed)
    n = int(dur * RATE)
    env = envelope(n, attack=0.004, release=0.04)
    out = []
    last = 0.0
    for i in range(n):
        last = smooth * last + (1 - smooth) * rng.uniform(-1, 1)
        out.append(last * env[i] * math.exp(-decay * i / n))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.extend(p)
        out.extend([0.0] * int(gap * RATE))
    return out


def write(path, samples, rate=RATE, peak_target=PEAK):
    peak = max(abs(v) for v in samples) or 1.0
    scale = peak_target / peak
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32767))
        for v in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(frames)


# ---------------------------------------------------------------------------
# Game specific sounds (SOUNDS_BEGIN)


def build():
    return {
        # A soft tick when a tile is revealed.
        "reveal": tone(480, 0.07, 540, shape="triangle", decay=5.0, harmonic=0.2),
        # A bright two-note pip when a flag is placed or removed.
        "flag": seq(
            tone(760, 0.05, decay=3.0, harmonic=0.2),
            tone(1010, 0.07, decay=4.0, harmonic=0.2),
        ),
        # A low thump with a puff of noise when a mine goes off.
        "boom": mix(
            tone(150, 0.38, 45, decay=4.5, harmonic=0.3),
            [0.5 * v for v in noise(0.3, decay=7.0, seed=7, smooth=0.8)],
        ),
        # A rising arpeggio when the field is cleared.
        "win": seq(
            tone(523.25, 0.08, decay=3.0, harmonic=0.2),
            tone(659.25, 0.08, decay=3.0, harmonic=0.2),
            tone(783.99, 0.08, decay=3.0, harmonic=0.2),
            tone(1046.5, 0.17, decay=4.0, harmonic=0.2),
        ),
        # Garden level up: a bouncy three-step climb with a sparkle on top.
        "level_up": seq(
            tone(587.33, 0.07, 660, shape="triangle", decay=3.0, harmonic=0.3),
            tone(783.99, 0.07, 880, shape="triangle", decay=3.0, harmonic=0.3),
            mix(
                tone(1174.66, 0.24, decay=5.0, harmonic=0.25),
                [0.4 * v for v in tone(2349.3, 0.24, decay=7.0)],
            ),
        ),
        # New best time: two bright bell dings.
        "new_best": seq(
            mix(tone(1318.5, 0.11, decay=5.0), [0.3 * v for v in tone(2637.0, 0.11, decay=8.0)]),
            mix(tone(1760.0, 0.26, decay=5.5), [0.3 * v for v in tone(3520.0, 0.26, decay=9.0)]),
        ),
        # Daily garden finished: a warm marimba roll.
        "daily": seq(
            tone(523.25, 0.06, decay=6.0, harmonic=0.5),
            tone(659.25, 0.06, decay=6.0, harmonic=0.5),
            tone(783.99, 0.06, decay=6.0, harmonic=0.5),
            mix(
                tone(1046.5, 0.22, decay=5.0, harmonic=0.5),
                [0.6 * v for v in tone(659.25, 0.22, decay=4.0)],
            ),
        ),
    }


# (SOUNDS_END)


# ---------------------------------------------------------------------------
# Music loop (MUSIC_BEGIN)

MUSIC_RATE = 16000
MUSIC_PEAK = 10 ** (-12 / 20)  # about -12 dBFS, sits under the effects
TAU = 2.0 * math.pi
BPM = 136
EIGHTH = 60.0 / BPM / 2.0


def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def lowpass(x, cutoff, rate):
    a = 1.0 - math.exp(-TAU * cutoff / rate)
    y = 0.0
    out = []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff, rate):
    return [v - l for v, l in zip(x, lowpass(x, cutoff, rate))]


def echo(x, delay, feedback, damp_hz, rate):
    """Feedback delay; returns only the wet signal."""
    a = 1.0 - math.exp(-TAU * damp_hz / rate)
    buf = [0.0] * len(x)
    wet = [0.0] * len(x)
    lp = 0.0
    for i in range(len(x)):
        if i >= delay:
            lp += a * (buf[i - delay] - lp)
            wet[i] = feedback * lp
        buf[i] = x[i] + wet[i]
    return wet


def circular(effect, x, *args):
    """Run a stateful effect over two tiled periods and keep the second."""
    n = len(x)
    return effect(x + x, *args)[n:]


def add(buf, sig, start, gain=1.0):
    n = len(buf)
    for i, v in enumerate(sig):
        buf[(start + i) % n] += gain * v


def marimba(freq, dur, rate, decay=9.0):
    """Woody mallet: fundamental plus a fast-dying 4th partial and a click."""
    m = int(dur * rate)
    w = TAU * freq / rate
    out = []
    for i in range(m):
        t = i / rate
        v = math.sin(w * i) * math.exp(-decay * t)
        v += 0.35 * math.sin(4.0 * w * i) * math.exp(-decay * 4.0 * t)
        v += 0.12 * math.sin(10.0 * w * i) * math.exp(-160.0 * t)
        out.append(v * min(1.0, i / (0.002 * rate)))
    return out


def pizz(freq, dur, rate):
    """Plucked bass: a few harmonics, higher ones fade faster."""
    m = int(dur * rate)
    w = TAU * freq / rate
    out = []
    for i in range(m):
        t = i / rate
        v = 0.0
        for k, amp in ((1, 1.0), (2, 0.45), (3, 0.2)):
            v += amp * math.sin(k * w * i) * math.exp(-(5.0 + 3.0 * k) * t)
        out.append(v * min(1.0, i / (0.003 * rate)))
    return out


def glock(freq, dur, rate):
    m = int(dur * rate)
    w = TAU * freq / rate
    return [
        (math.sin(w * i) + 0.25 * math.sin(2.76 * w * i) * math.exp(-12.0 * i / rate))
        * math.exp(-5.0 * i / rate)
        * min(1.0, i / (0.001 * rate))
        for i in range(m)
    ]


# F major. Chord: (marimba voicing, bass root).
CHORDS = {
    "F": ((65, 69, 72), 41),
    "Dm": ((62, 65, 69), 38),
    "Bb": ((62, 65, 70), 46),
    "C": ((64, 67, 72), 36),
    "Am": ((64, 69, 72), 45),
    "Gm": ((62, 67, 70), 43),
}
PROGRESSION = [
    "F", "Dm", "Bb", "C",
    "F", "Am", "Bb", "C",
    "Dm", "Bb", "F", "C",
    "Bb", "C", "Gm", "C",
]

# Melody per bar: (eighth offset, MIDI note, length in eighths). Bouncy,
# mostly stepwise with little hops; the last bar leads back to the top.
MELODY = [
    [(0, 72, 1), (1, 74, 1), (2, 77, 2), (4, 76, 1), (5, 74, 1), (6, 72, 2)],
    [(0, 74, 1), (1, 77, 1), (2, 81, 2), (4, 79, 1), (5, 77, 1), (6, 74, 2)],
    [(0, 74, 2), (2, 77, 1), (3, 79, 1), (4, 82, 2), (6, 81, 1), (7, 79, 1)],
    [(0, 79, 3), (3, 76, 1), (4, 72, 2), (6, 74, 1), (7, 76, 1)],
    [(0, 77, 1), (1, 81, 1), (2, 84, 2), (4, 81, 1), (5, 77, 1), (6, 81, 2)],
    [(0, 76, 1), (1, 77, 1), (2, 76, 1), (3, 72, 1), (4, 69, 2), (6, 72, 2)],
    [(0, 74, 1), (1, 77, 1), (2, 82, 1), (3, 81, 1), (4, 79, 2), (6, 77, 1), (7, 79, 1)],
    [(0, 76, 4), (5, 79, 1), (6, 81, 1), (7, 82, 1)],
    [(0, 81, 2), (2, 77, 1), (3, 74, 1), (4, 77, 2), (6, 81, 2)],
    [(0, 82, 1), (1, 81, 1), (2, 79, 1), (3, 77, 1), (4, 74, 2), (6, 77, 2)],
    [(0, 81, 1), (1, 84, 1), (2, 81, 1), (3, 77, 1), (4, 72, 2), (6, 77, 2)],
    [(0, 76, 2), (2, 79, 2), (4, 84, 3)],
    [(0, 82, 1), (1, 81, 1), (2, 82, 1), (3, 86, 1), (4, 84, 2), (6, 82, 2)],
    [(0, 81, 1), (1, 79, 1), (2, 76, 1), (3, 79, 1), (4, 84, 2), (6, 81, 2)],
    [(0, 79, 2), (2, 82, 1), (3, 79, 1), (4, 74, 2), (6, 79, 2)],
    [(0, 76, 1), (1, 77, 1), (2, 79, 2), (4, 72, 2), (6, 74, 1), (7, 70, 1)],
]


def music_loop():
    rate = MUSIC_RATE
    bar = EIGHTH * 8
    bars = len(PROGRESSION)
    n = int(round(bar * bars * rate))
    rng = random.Random(77)
    at = lambda b, e: int(round((b * bar + e * EIGHTH) * rate))

    chords = [0.0] * n
    bass = [0.0] * n
    lead = [0.0] * n
    perc = [0.0] * n

    cache = {}

    def voice(kind, note, dur):
        key = (kind, note, dur)
        if key not in cache:
            f = midi_hz(note)
            if kind == "marimba":
                cache[key] = marimba(f, dur, rate)
            elif kind == "pizz":
                cache[key] = pizz(f, dur, rate)
            else:
                cache[key] = glock(f, dur, rate)
        return cache[key]

    for b, name in enumerate(PROGRESSION):
        notes, root = CHORDS[name]
        # Off-beat marimba chords: "and" of each beat, the classic bounce.
        for e in (1, 3, 5, 7):
            for k, note in enumerate(notes):
                add(chords, voice("marimba", note, 0.35), at(b, e) + k * 24, 0.22)
        # Bass on beats 1 and 3, a walking pickup on the last eighth.
        add(bass, voice("pizz", root, 0.5), at(b, 0), 0.7)
        add(bass, voice("pizz", root + 7, 0.4), at(b, 4), 0.55)
        nxt_root = CHORDS[PROGRESSION[(b + 1) % bars]][1]
        step = 2 if nxt_root > root else -2
        add(bass, voice("pizz", nxt_root - step, 0.25), at(b, 7), 0.4)

    for b, phrase in enumerate(MELODY):
        for off, note, length in phrase:
            dur = min(1.2, 0.25 + 0.12 * length)
            add(lead, voice("marimba", note, dur), at(b, off), 0.42)
            # Glockenspiel doubles the first note of every second bar.
            if off == 0 and b % 2 == 1:
                add(lead, voice("glock", note + 12, 0.8), at(b, off), 0.12)

    # Percussion: soft woodblock on 2 and 4, shaker ticks on the eighths.
    block = [
        math.sin(TAU * 1250 * i / rate) * math.exp(-70.0 * i / rate)
        for i in range(int(0.08 * rate))
    ]
    for b in range(bars):
        for e in (2, 6):
            add(perc, block, at(b, e), 0.16)
        for e in range(8):
            vel = (0.5, 0.25, 0.4, 0.25, 0.5, 0.25, 0.4, 0.3)[e] * (0.85 + 0.3 * rng.random())
            tick = [rng.uniform(-1.0, 1.0) * math.exp(-90.0 * i / rate) for i in range(int(0.05 * rate))]
            add(perc, tick, at(b, e), 0.05 * vel)

    chords = circular(lowpass, chords, 2600, rate)
    bass = circular(lowpass, bass, 900, rate)
    lead = circular(lowpass, lead, 3400, rate)
    wet = circular(echo, lead, int(round(EIGHTH * 3 * rate)), 0.3, 2000, rate)
    perc = circular(highpass, perc, 1500, rate)
    mixed = [c + bs + l + 0.35 * w + p for c, bs, l, w, p in zip(chords, bass, lead, wet, perc)]
    return circular(highpass, mixed, 35, rate)


# (MUSIC_END)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    for name, samples in build().items():
        write(os.path.join(out_dir, name + ".wav"), samples)
    write(
        os.path.join(out_dir, "music_loop.wav"),
        music_loop(),
        rate=MUSIC_RATE,
        peak_target=MUSIC_PEAK,
    )


if __name__ == "__main__":
    main()
