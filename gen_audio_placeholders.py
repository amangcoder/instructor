#!/usr/bin/env python3
"""Generate minimal valid silent MP3 placeholder files for the Instructor app.

Each file is a sequence of valid MPEG1 Layer3 silent frames:
  - 128 kbps, 44 100 Hz, Joint Stereo
  - Frame size = floor(144 * 128 000 / 44 100) = 417 bytes
  - part2_3_length = 0  =>  no main data, all quantised samples are zero (silence)
"""
import os


def _pack_bits(bit_list):
    """Serialise a list of (value, bit_width) pairs into a big-endian byte array."""
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
    """Build the 32-byte MPEG1 stereo side-information block for a silent frame."""
    bits = [
        (0, 9),  # main_data_begin = 0  (no back pointer)
        (0, 3),  # private_bits
        (0, 4),  # scfsi[ch0]
        (0, 4),  # scfsi[ch1]
    ]
    # 2 granules x 2 channels = 4 granule/channel descriptors
    for _ in range(4):
        bits += [
            (0,  12),  # part2_3_length = 0  <- no main data for this granule
            (0,   9),  # big_values = 0
            (0,   8),  # global_gain = 0 (muted)
            (0,   4),  # scalefac_compress = 0
            (0,   1),  # window_switching_flag = 0
            # window_switching_flag == 0 => three-region long block:
            (0,   5),  # table_select[0]
            (0,   5),  # table_select[1]
            (0,   5),  # table_select[2]
            (0,   4),  # region0_count
            (0,   3),  # region1_count
            (0,   1),  # preflag
            (0,   1),  # scalefac_scale
            (1,   1),  # count1table_select = 1
        ]
    result = _pack_bits(bits)
    assert len(result) == 32, "Side info must be 32 bytes, got {}".format(len(result))
    return result


# Pre-compute constants
_SIDE_INFO = _build_side_info()

# MPEG1, Layer3, no-CRC, 128 kbps, 44 100 Hz, no padding, private=0,
# Joint-Stereo, mode_ext=01 (subbands 4-31), no copyright, original, no emphasis
_FRAME_HEADER = bytes([0xFF, 0xFB, 0x90, 0x64])

# Frame length = floor(144 * bitrate / sample_rate) + padding
#              = floor(144 * 128 000 / 44 100) + 0 = 417 bytes
_FRAME_SIZE = 417
_MAIN_DATA_SIZE = _FRAME_SIZE - len(_FRAME_HEADER) - len(_SIDE_INFO)  # 381 bytes
_SILENT_FRAME = _FRAME_HEADER + _SIDE_INFO + bytes(_MAIN_DATA_SIZE)

assert len(_SILENT_FRAME) == _FRAME_SIZE, \
    "Frame must be {} bytes, got {}".format(_FRAME_SIZE, len(_SILENT_FRAME))


def create_silent_mp3(num_frames):
    """Return num_frames silent MP3 frames concatenated."""
    return _SILENT_FRAME * num_frames


# Asset manifest: path relative to app/  =>  number of frames to generate
# MPEG1/Layer3/44.1 kHz: 1152 samples/frame => 44100/1152 ~= 38.3 frames/s
# Ambient tracks: ~5 s  => 192 frames
# Effect sounds:  ~1 s  =>  38 frames
# Silence loop:   ~1 s  =>  38 frames
ASSETS = {
    "assets/audio/ambient/rain.mp3":          192,
    "assets/audio/ambient/forest.mp3":        192,
    "assets/audio/ambient/ocean.mp3":         192,
    "assets/audio/ambient/white_noise.mp3":   192,
    "assets/audio/ambient/tibetan_bowls.mp3": 192,
    "assets/audio/effects/bell.mp3":           38,
    "assets/audio/effects/chime.mp3":          38,
    "assets/audio/effects/gong.mp3":           38,
    "assets/audio/silence/silence.mp3":        38,
}

BASE_DIR = "/Users/amangupta/Projects/instructor/app"

for rel_path, num_frames in ASSETS.items():
    full_path = os.path.join(BASE_DIR, rel_path)
    if os.path.exists(full_path) and os.path.getsize(full_path) > 0:
        print("SKIP (exists, {} B): {}".format(os.path.getsize(full_path), rel_path))
        continue
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    data = create_silent_mp3(num_frames)
    with open(full_path, "wb") as f:
        f.write(data)
    print("Created {}  ({:,} bytes, {} frames)".format(rel_path, len(data), num_frames))

print("\nDone -- all placeholder MP3 assets written.")
