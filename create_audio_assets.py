#!/usr/bin/env python3
"""Generate minimal valid silent MP3 placeholder files for the Instructor app."""
import os

def _pack_bits(bit_list):
    result = []
    buf = 0
    buf_len = 0
    for value, width in bit_list:
        for i in range(width - 1, -1, -1):
            buf = (buf << 1) | ((value >> i) & 1)
            buf_len += 1
            if buf_len == 8:
                result.append(buf & 0xFF)
                buf = 0
                buf_len = 0
    if buf_len:
        result.append((buf << (8 - buf_len)) & 0xFF)
    return bytes(result)

def _build_side_info():
    bits = [(0, 9), (0, 3), (0, 4), (0, 4)]
    for _ in range(4):
        bits += [
            (0, 12), (0, 9), (0, 8), (0, 4), (0, 1),
            (0, 5), (0, 5), (0, 5), (0, 4), (0, 3),
            (0, 1), (0, 1), (1, 1),
        ]
    result = _pack_bits(bits)
    assert len(result) == 32
    return result

SIDE_INFO = _build_side_info()
FRAME_HEADER = bytes([0xFF, 0xFB, 0x90, 0x64])
FRAME_SIZE = 417
MAIN_DATA_SIZE = FRAME_SIZE - len(FRAME_HEADER) - len(SIDE_INFO)
SILENT_FRAME = FRAME_HEADER + SIDE_INFO + bytes(MAIN_DATA_SIZE)

BASE_DIR = os.path.join(os.path.dirname(__file__), "app")

ASSETS = {
    "assets/audio/ambient/rain.mp3": 192,
    "assets/audio/ambient/forest.mp3": 192,
    "assets/audio/ambient/ocean.mp3": 192,
    "assets/audio/ambient/white_noise.mp3": 192,
    "assets/audio/ambient/tibetan_bowls.mp3": 192,
    "assets/audio/effects/bell.mp3": 38,
    "assets/audio/effects/chime.mp3": 38,
    "assets/audio/effects/gong.mp3": 38,
    "assets/audio/silence/silence.mp3": 38,
}

for rel_path, num_frames in ASSETS.items():
    full_path = os.path.join(BASE_DIR, rel_path)
    if os.path.exists(full_path) and os.path.getsize(full_path) > 0:
        print("SKIP (exists): {}".format(rel_path))
        continue
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    data = SILENT_FRAME * num_frames
    with open(full_path, "wb") as f:
        f.write(data)
    print("Created {}  ({:,} bytes, {} frames)".format(rel_path, len(data), num_frames))

print("\nDone.")
