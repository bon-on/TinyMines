#!/usr/bin/env python3
"""Generates the game sound effects as small mono 16-bit 44.1 kHz WAV files.

Python 3 standard library only. The output is deterministic (fixed random
seed), so running the script twice yields byte-identical files.

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


def write(path, samples):
    peak = max(abs(v) for v in samples) or 1.0
    scale = PEAK / peak
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32767))
        for v in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
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
    }


# (SOUNDS_END)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    for name, samples in build().items():
        write(os.path.join(out_dir, name + ".wav"), samples)


if __name__ == "__main__":
    main()
