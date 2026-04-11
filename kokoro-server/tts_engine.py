"""
Kokoro TTS Engine — wraps the kokoro-onnx library for CPU inference.

Model loading happens asynchronously at startup.  Call await engine.wait_ready()
before accepting requests (or poll engine.is_ready).

Usage:
    engine = KokoroEngine()
    asyncio.create_task(engine.load())
    ...
    audio_bytes = await engine.synthesize(text, voice, language, speed)
"""
import asyncio
import io
import logging
import struct
import time
from concurrent.futures import ThreadPoolExecutor
from threading import Event
from typing import Optional

import numpy as np

import config

logger = logging.getLogger(__name__)

# ── Voice catalog ─────────────────────────────────────────────────────────────
# Maps voice ID → human-readable label.  Ordered by locale and gender.
# These are the voices bundled in kokoro-onnx v0.

VOICE_CATALOG: dict[str, str] = {
    # American English — Female
    "af_heart":    "Heart (Female, US)",
    "af_sky":      "Sky (Female, US)",
    "af_bella":    "Bella (Female, US)",
    "af_sarah":    "Sarah (Female, US)",
    "af_nicole":   "Nicole (Female, US)",
    "af_nova":     "Nova (Female, US)",
    # American English — Male
    "am_adam":     "Adam (Male, US)",
    "am_michael":  "Michael (Male, US)",
    "am_echo":     "Echo (Male, US)",
    "am_eric":     "Eric (Male, US)",
    "am_liam":     "Liam (Male, US)",
    "am_onyx":     "Onyx (Male, US)",
    # British English — Female
    "bf_emma":     "Emma (Female, UK)",
    "bf_isabella": "Isabella (Female, UK)",
    "bf_alice":    "Alice (Female, UK)",
    "bf_lily":     "Lily (Female, UK)",
    # British English — Male
    "bm_george":   "George (Male, UK)",
    "bm_lewis":    "Lewis (Male, UK)",
    "bm_daniel":   "Daniel (Male, UK)",
    "bm_fable":    "Fable (Male, UK)",
    # Hindi — Female
    "hf_alpha":    "Alpha (Female, Hindi)",
    "hf_beta":     "Beta (Female, Hindi)",
    # Hindi — Male
    "hm_omega":    "Omega (Male, Hindi)",
    "hm_psi":      "Psi (Male, Hindi)",
}

# Supported language codes (Kokoro uses ISO 639-1 style).
SUPPORTED_LANGUAGES = frozenset({"en-us", "en-gb", "hi"})


def _pcm_to_wav(samples: np.ndarray, sample_rate: int) -> bytes:
    """Convert float32 PCM samples → 16-bit WAV bytes."""
    # Clip to [-1, 1] and convert to int16.
    clipped = np.clip(samples, -1.0, 1.0)
    pcm16 = (clipped * 32767).astype(np.int16)
    pcm_bytes = pcm16.tobytes()

    data_size = len(pcm_bytes)
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + data_size,       # ChunkSize
        b"WAVE",
        b"fmt ",
        16,                   # Subchunk1Size (PCM)
        1,                    # AudioFormat (PCM = 1)
        1,                    # NumChannels (mono)
        sample_rate,          # SampleRate
        sample_rate * 2,      # ByteRate (SampleRate * NumChannels * BitsPerSample/8)
        2,                    # BlockAlign
        16,                   # BitsPerSample
        b"data",
        data_size,            # Subchunk2Size
    )
    return header + pcm_bytes


class KokoroEngine:
    """
    Thread-safe wrapper around the Kokoro ONNX TTS pipeline.

    The model is loaded in a background thread so the FastAPI startup hook
    returns immediately.  The /health endpoint returns 503 until is_ready.
    """

    def __init__(self) -> None:
        self._kokoro: Optional[object] = None
        self._ready = Event()
        self._error: Optional[str] = None
        self._executor = ThreadPoolExecutor(
            max_workers=config.MAX_CONCURRENT,
            thread_name_prefix="kokoro-synth",
        )

    @property
    def is_ready(self) -> bool:
        return self._ready.is_set() and self._error is None

    @property
    def load_error(self) -> Optional[str]:
        return self._error

    def available_voices(self) -> list[str]:
        return list(VOICE_CATALOG.keys())

    # ── Model loading ─────────────────────────────────────────────────────────

    async def load(self) -> None:
        """Load the Kokoro ONNX model in a background thread."""
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, self._load_blocking)

    def _load_blocking(self) -> None:
        t0 = time.perf_counter()
        try:
            logger.info("Loading Kokoro ONNX model — this may take 5-30s on first run…")
            # kokoro-onnx lazy-downloads weights on first use (or reads from cache).
            from kokoro_onnx import Kokoro  # type: ignore[import]

            import os
            model_dir = config.MODEL_DIR or os.path.join(os.path.dirname(__file__), "models")
            model_path = os.path.join(model_dir, config.MODEL_NAME + ".onnx")
            voices_path = os.path.join(model_dir, "voices-v1.0.bin")
            self._kokoro = Kokoro(model_path, voices_path)
            elapsed = time.perf_counter() - t0
            logger.info("Kokoro model loaded in %.1fs", elapsed)
            self._ready.set()
        except Exception as exc:
            elapsed = time.perf_counter() - t0
            self._error = str(exc)
            logger.exception("Failed to load Kokoro model after %.1fs: %s", elapsed, exc)
            # Set ready so health can report the error rather than hanging forever.
            self._ready.set()

    async def wait_ready(self, timeout: float = 120.0) -> bool:
        """Wait until the model is loaded (or timeout exceeded)."""
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            None, lambda: self._ready.wait(timeout=timeout)
        )

    # ── Synthesis ─────────────────────────────────────────────────────────────

    async def synthesize(
        self,
        text: str,
        voice: str,
        language: str = "en-us",
        speed: float = 1.0,
    ) -> bytes:
        """
        Synthesize text to WAV audio bytes.

        Raises:
            RuntimeError if the model is not loaded.
            ValueError if the voice or language is invalid.
        """
        if not self.is_ready:
            if self._error:
                raise RuntimeError(f"Kokoro engine failed to load: {self._error}")
            raise RuntimeError("Kokoro engine is not ready yet")

        # Validate voice.
        if voice not in VOICE_CATALOG:
            raise ValueError(
                f"Unknown voice '{voice}'. Available: {', '.join(sorted(VOICE_CATALOG.keys()))}"
            )

        # Validate language.
        if language not in SUPPORTED_LANGUAGES:
            raise ValueError(
                f"Unsupported language '{language}'. Supported: {', '.join(sorted(SUPPORTED_LANGUAGES))}"
            )

        # Reject Devanagari text with non-Hindi voice/language to prevent
        # ONNX runtime crashes from incompatible script+model combinations.
        import re
        has_devanagari = bool(re.search(r'[\u0900-\u097F]', text))
        if has_devanagari and language != 'hi':
            raise ValueError(
                f"Hindi (Devanagari) text requires language='h' and a Hindi voice, "
                f"but got language='{language}', voice='{voice}'"
            )

        speed = max(0.1, min(4.0, speed))

        loop = asyncio.get_running_loop()
        wav_bytes = await loop.run_in_executor(
            self._executor,
            lambda: self._synthesize_blocking(text, voice, language, speed),
        )
        return wav_bytes

    def _synthesize_blocking(
        self,
        text: str,
        voice: str,
        language: str,
        speed: float,
    ) -> bytes:
        """Blocking synthesis — runs inside the thread-pool executor."""
        t0 = time.perf_counter()
        assert self._kokoro is not None, "model not loaded"

        try:
            # kokoro-onnx API: create(text, voice, speed, lang) → (samples, sample_rate)
            samples, sample_rate = self._kokoro.create(
                text,
                voice,
                speed=speed,
                lang=language,
            )
        except Exception as exc:
            raise RuntimeError(f"Kokoro synthesis error: {exc}") from exc

        elapsed = time.perf_counter() - t0
        wav = _pcm_to_wav(samples, sample_rate)
        logger.info(
            "Synthesis OK — voice=%s, lang=%s, speed=%.1f, %.0f samples, %d bytes, %.2fs",
            voice, language, speed, len(samples), len(wav), elapsed,
        )
        return wav

    # ── Shutdown ──────────────────────────────────────────────────────────────

    def shutdown(self) -> None:
        self._executor.shutdown(wait=False)
