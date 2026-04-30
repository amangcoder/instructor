"""
Forced-alignment engine for batch-TTS chunk splitting.

Given a single concatenated audio (e.g. one Gemini batch synthesis output) and
the ordered list of source texts that produced it, returns one
{start_ms, end_ms} window per source text. The downstream caller slices the
PCM at those offsets to recover per-chunk audio.

The model used is MahmoudAshraf/mms-300m-1130-forced-aligner (a fine-tuned
MMS model wrapped by the ctc-forced-aligner library). It expects 16 kHz mono
audio; the engine resamples on the fly from whatever rate the caller sends.

The model is loaded lazily on the first call and reused for the lifetime of
the process. On Modal this means one cold load per warm container.
"""
from __future__ import annotations

import asyncio
import logging
import re
import threading
from dataclasses import dataclass
from typing import List, Tuple

import numpy as np
import torch
import torchaudio.functional as AF
from ctc_forced_aligner import (
    generate_emissions,
    get_alignments,
    get_spans,
    load_alignment_model,
    postprocess_results,
    preprocess_text,
)

import config

logger = logging.getLogger("kokoro-server.alignment")

# 16-bit signed PCM range.
_PCM_INT16_MAX = 32768.0

# Languages without whitespace word boundaries — count characters instead of
# whitespace-split tokens to estimate per-chunk weight.
_CJK_LANGUAGES = {"cmn", "zho", "yue", "jpn", "kor", "tha", "lao", "mya"}

# Strips whitespace and ASCII/CJK punctuation so two chunks with different
# punctuation density still get a fair character count.
_PUNCT_STRIP = re.compile(r"[\s\.,!?;:'\"()\[\]\-—–。、！？；：，「」『』《》（）]")


def _chunk_weight(text: str, language: str) -> int:
    """Per-chunk weight used to apportion aligned words between chunks.

    Whitespace-tokenize for languages with word boundaries; fall back to a
    character count for CJK and other scriptio-continua scripts. Returns at
    least 1 so an empty/punctuation-only chunk doesn't divide by zero.
    """
    if language.lower() in _CJK_LANGUAGES:
        return max(1, len(_PUNCT_STRIP.sub("", text)))
    return max(1, len(text.strip().split()))


@dataclass(frozen=True)
class Boundary:
    start_ms: int
    end_ms: int


def _resolve_device(name: str) -> str:
    name = name.lower().strip()
    if name == "auto":
        return "cuda" if torch.cuda.is_available() else "cpu"
    return name


class AlignmentEngine:
    """Lazy-loaded singleton wrapping ctc-forced-aligner."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._model = None
        self._tokenizer = None
        self._device: str | None = None
        self._dtype: torch.dtype | None = None

    # ── Loading ───────────────────────────────────────────────────────────────

    @property
    def is_loaded(self) -> bool:
        return self._model is not None

    def load(self) -> None:
        """Load the alignment model. Safe to call multiple times."""
        if self.is_loaded:
            return
        with self._lock:
            if self.is_loaded:
                return
            device = _resolve_device(config.ALIGN_DEVICE)
            # fp16 on GPU saves ~half the memory; CPU keeps fp32 for accuracy.
            dtype = torch.float16 if device == "cuda" else torch.float32
            logger.info(
                "Loading alignment model %s on %s (%s)",
                config.ALIGN_MODEL,
                device,
                dtype,
            )
            model, tokenizer = load_alignment_model(
                device,
                model_path=config.ALIGN_MODEL,
                dtype=dtype,
            )
            self._model = model
            self._tokenizer = tokenizer
            self._device = device
            self._dtype = dtype
            logger.info("Alignment model loaded")

    # ── Public API ────────────────────────────────────────────────────────────

    async def align(
        self,
        pcm_bytes: bytes,
        sample_rate: int,
        texts: List[str],
        language: str,
    ) -> Tuple[List[Boundary], int]:
        """Align ``texts`` against ``pcm_bytes`` and return one window per text.

        ``pcm_bytes`` must be 16-bit little-endian mono PCM at ``sample_rate``.
        Returns (boundaries, duration_ms) where boundaries cover the full audio
        with no gaps and ``duration_ms`` is the total clip length.
        """
        if not texts:
            raise ValueError("texts must not be empty")
        if sample_rate <= 0:
            raise ValueError("sample_rate must be positive")
        if len(pcm_bytes) < 2 or len(pcm_bytes) % 2 != 0:
            raise ValueError("pcm_bytes must be a non-empty even-length 16-bit LE buffer")

        self.load()

        # Heavy CPU/GPU work happens in a worker thread so the event loop keeps
        # serving other requests. The aligner is not async-aware.
        return await asyncio.to_thread(
            self._align_sync, pcm_bytes, sample_rate, texts, language
        )

    # ── Internals ─────────────────────────────────────────────────────────────

    def _align_sync(
        self,
        pcm_bytes: bytes,
        sample_rate: int,
        texts: List[str],
        language: str,
    ) -> Tuple[List[Boundary], int]:
        waveform = self._pcm_to_tensor(pcm_bytes, sample_rate)
        duration_ms = int(round(waveform.shape[-1] / config.ALIGN_SAMPLE_RATE * 1000))

        # Single-chunk fast path — no alignment needed, just span the whole clip.
        if len(texts) == 1:
            return [Boundary(0, duration_ms)], duration_ms

        word_counts = [_chunk_weight(t, language) for t in texts]
        joined = " ".join(texts)
        tokens, text_starred = preprocess_text(
            joined, romanize=True, language=language
        )

        emissions, stride = generate_emissions(
            self._model,
            waveform.to(self._device, dtype=self._dtype),
            batch_size=config.ALIGN_BATCH_SIZE,
        )
        segments, scores, blank_token = get_alignments(
            emissions, tokens, self._tokenizer
        )
        spans = get_spans(tokens, segments, blank_token)
        word_timestamps = postprocess_results(text_starred, spans, stride, scores)

        return self._words_to_boundaries(word_counts, word_timestamps, duration_ms), duration_ms

    def _pcm_to_tensor(self, pcm_bytes: bytes, sample_rate: int) -> torch.Tensor:
        """Decode 16-bit LE mono PCM, normalize to [-1, 1], resample to 16 kHz."""
        samples = np.frombuffer(pcm_bytes, dtype="<i2").astype(np.float32) / _PCM_INT16_MAX
        waveform = torch.from_numpy(samples).unsqueeze(0)  # (1, N)
        if sample_rate != config.ALIGN_SAMPLE_RATE:
            waveform = AF.resample(
                waveform, orig_freq=sample_rate, new_freq=config.ALIGN_SAMPLE_RATE
            )
        return waveform.squeeze(0)  # (N,)

    @staticmethod
    def _words_to_boundaries(
        word_counts: List[int],
        word_timestamps: List[dict],
        duration_ms: int,
    ) -> List[Boundary]:
        """Walk word_timestamps using cumulative word_counts to find cut points.

        Cut at the midpoint of the gap between the last word of chunk i and
        the first word of chunk i+1. Final chunk extends to end of audio.
        """
        # Defensive: aligner sometimes drops a token at the boundary. If counts
        # disagree with what was aligned, fall back to proportional splitting
        # over whatever words we got back rather than failing outright.
        total_aligned = len(word_timestamps)
        total_expected = sum(word_counts)
        if total_aligned == 0:
            raise ValueError("aligner returned no word timestamps")
        if total_expected == 0:
            raise ValueError("texts produced zero alignable words")

        if total_aligned != total_expected:
            logger.warning(
                "alignable-word count mismatch (expected=%d, aligned=%d); "
                "scaling proportionally",
                total_expected,
                total_aligned,
            )
            scale = total_aligned / total_expected
            word_counts = [max(1, int(round(c * scale))) for c in word_counts]
            # Re-balance so the sum equals total_aligned (rounding drift).
            drift = total_aligned - sum(word_counts)
            word_counts[-1] = max(1, word_counts[-1] + drift)

        boundaries: List[Boundary] = []
        cursor = 0
        prev_ms = 0
        for i, count in enumerate(word_counts):
            last_idx = min(cursor + count - 1, total_aligned - 1)
            is_last_chunk = i == len(word_counts) - 1
            if is_last_chunk:
                cut_ms = duration_ms
            else:
                next_idx = min(cursor + count, total_aligned - 1)
                end_s = float(word_timestamps[last_idx]["end"])
                next_start_s = float(word_timestamps[next_idx]["start"])
                cut_ms = int(round((end_s + next_start_s) / 2 * 1000))
                # Guard against degenerate ordering from the aligner.
                cut_ms = max(prev_ms + 1, min(cut_ms, duration_ms))
            boundaries.append(Boundary(prev_ms, cut_ms))
            prev_ms = cut_ms
            cursor += count
        return boundaries


# Module-level singleton — mirrors how `engine` is exposed in main.py.
alignment_engine = AlignmentEngine()
