"""
VibeVoice TTS engine — wraps Microsoft's VibeVoice diffusion model for inference.

The model is loaded in a background thread so the FastAPI startup hook returns
immediately. The /health endpoint returns 503 until is_ready.

Voice presets are sourced from config.VOICE_DIR — every .wav/.flac file in that
directory becomes a selectable voice id (filename stem, lower-cased). For
multi-speaker dialogue the caller passes a comma-separated voice list.
"""
import asyncio
import io
import logging
import os
import struct
import time
from concurrent.futures import ThreadPoolExecutor
from threading import Event
from typing import Any, List, Optional

import numpy as np

import config

logger = logging.getLogger(__name__)

# Filename extensions we treat as voice prompts.
_VOICE_EXTENSIONS = (".wav", ".flac", ".mp3", ".ogg")

# Maximum number of speakers the model supports per request.
MAX_SPEAKERS = 4


def _humanize(stem: str) -> str:
    """Turn 'en_alice_calm' → 'Alice Calm (en)' for display."""
    parts = stem.replace("-", "_").split("_")
    if len(parts) >= 2 and len(parts[0]) <= 3:
        locale, *rest = parts
        name = " ".join(p.capitalize() for p in rest)
        return f"{name} ({locale})"
    return " ".join(p.capitalize() for p in parts)


def _scan_voices(voice_dir: str) -> dict[str, tuple[str, str]]:
    """Map voice id → (label, absolute path) by scanning the voice directory."""
    catalog: dict[str, tuple[str, str]] = {}
    if not os.path.isdir(voice_dir):
        return catalog
    for name in sorted(os.listdir(voice_dir)):
        path = os.path.join(voice_dir, name)
        if not os.path.isfile(path):
            continue
        stem, ext = os.path.splitext(name)
        if ext.lower() not in _VOICE_EXTENSIONS:
            continue
        vid = stem.strip().lower()
        catalog[vid] = (_humanize(stem), path)
    return catalog


def _pcm_to_wav(samples: np.ndarray, sample_rate: int) -> bytes:
    """Convert float32 PCM samples → 16-bit WAV bytes."""
    clipped = np.clip(samples, -1.0, 1.0)
    pcm16 = (clipped * 32767).astype(np.int16)
    pcm_bytes = pcm16.tobytes()

    data_size = len(pcm_bytes)
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + data_size,
        b"WAVE",
        b"fmt ",
        16,
        1,            # PCM
        1,            # mono
        sample_rate,
        sample_rate * 2,
        2,
        16,
        b"data",
        data_size,
    )
    return header + pcm_bytes


def _resolve_device(requested: str) -> str:
    """Pick a torch device respecting the operator's override."""
    import torch

    requested = (requested or "auto").lower()
    if requested == "cuda" or (requested == "auto" and torch.cuda.is_available()):
        return "cuda"
    if requested == "mps" or (
        requested == "auto"
        and getattr(torch.backends, "mps", None) is not None
        and torch.backends.mps.is_available()
    ):
        return "mps"
    return "cpu"


def _resolve_dtype(requested: str, device: str):
    """Pick a torch dtype that matches the chosen device."""
    import torch

    requested = (requested or "auto").lower()
    if requested in ("bf16", "bfloat16"):
        return torch.bfloat16
    if requested in ("fp16", "float16", "half"):
        return torch.float16
    if requested in ("fp32", "float32"):
        return torch.float32
    # auto: bfloat16 only on CUDA, float32 elsewhere for stability.
    return torch.bfloat16 if device == "cuda" else torch.float32


def _format_dialogue(text: str, num_speakers: int) -> str:
    """
    Ensure the text is in VibeVoice's 'Speaker N: …' format.

    If the caller passed plain text we wrap it as a single-speaker monologue.
    Otherwise we trust the caller's formatting.
    """
    if "speaker" in text.lower() and ":" in text:
        return text
    if num_speakers == 1:
        return f"Speaker 1: {text}"
    # Multi-voice request without speaker tags — treat as monologue from speaker 1.
    return f"Speaker 1: {text}"


class VibeVoiceEngine:
    """
    Thread-safe wrapper around the VibeVoice diffusion TTS pipeline.

    Loading happens lazily in a background thread; /health reports 503 until
    `is_ready`. Synthesis is funneled through a small thread pool so concurrent
    requests don't trample the GPU.
    """

    def __init__(self) -> None:
        self._model: Optional[Any] = None
        self._processor: Optional[Any] = None
        self._device: Optional[str] = None
        self._dtype: Optional[Any] = None
        self._voices: dict[str, tuple[str, str]] = {}
        self._ready = Event()
        self._error: Optional[str] = None
        self._executor = ThreadPoolExecutor(
            max_workers=config.MAX_CONCURRENT,
            thread_name_prefix="vibevoice-synth",
        )

    # ── State ─────────────────────────────────────────────────────────────────

    @property
    def is_ready(self) -> bool:
        return self._ready.is_set() and self._error is None

    @property
    def load_error(self) -> Optional[str]:
        return self._error

    @property
    def device(self) -> Optional[str]:
        return self._device

    def available_voices(self) -> List[str]:
        return list(self._voices.keys())

    def voice_catalog(self) -> List[tuple[str, str]]:
        return [(vid, label) for vid, (label, _) in self._voices.items()]

    # ── Loading ───────────────────────────────────────────────────────────────

    async def load(self) -> None:
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, self._load_blocking)

    def _load_blocking(self) -> None:
        t0 = time.perf_counter()
        try:
            self._voices = _scan_voices(config.VOICE_DIR)
            logger.info(
                "Voice catalog: %d preset(s) found in %s",
                len(self._voices),
                config.VOICE_DIR,
            )

            import torch
            from vibevoice.modular.modeling_vibevoice_inference import (
                VibeVoiceForConditionalGenerationInference,
            )
            from vibevoice.processor.vibevoice_processor import VibeVoiceProcessor

            self._device = _resolve_device(config.DEVICE)
            self._dtype = _resolve_dtype(config.DTYPE, self._device)
            logger.info(
                "Loading VibeVoice model %s on %s (%s) — first run can take several minutes…",
                config.MODEL_NAME,
                self._device,
                self._dtype,
            )

            self._processor = VibeVoiceProcessor.from_pretrained(
                config.MODEL_NAME,
                cache_dir=config.MODEL_DIR or None,
            )

            model = VibeVoiceForConditionalGenerationInference.from_pretrained(
                config.MODEL_NAME,
                torch_dtype=self._dtype,
                cache_dir=config.MODEL_DIR or None,
                device_map=self._device if self._device == "cuda" else None,
                low_cpu_mem_usage=True,
            )
            if self._device != "cuda":
                model = model.to(self._device)
            model.set_ddpm_inference_steps(num_steps=config.DDPM_STEPS)
            model.eval()
            self._model = model

            elapsed = time.perf_counter() - t0
            logger.info("VibeVoice model loaded in %.1fs", elapsed)
            self._ready.set()
        except Exception as exc:
            elapsed = time.perf_counter() - t0
            self._error = str(exc)
            logger.exception("Failed to load VibeVoice model after %.1fs: %s", elapsed, exc)
            # Surface the error via /health rather than hanging.
            self._ready.set()

    async def wait_ready(self, timeout: float = 600.0) -> bool:
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
        cfg_scale: Optional[float] = None,
        ddpm_steps: Optional[int] = None,
    ) -> bytes:
        if not self.is_ready:
            if self._error:
                raise RuntimeError(f"VibeVoice engine failed to load: {self._error}")
            raise RuntimeError("VibeVoice engine is not ready yet")

        voice_ids = [v.strip().lower() for v in voice.split(",") if v.strip()]
        if not voice_ids:
            raise ValueError("voice must not be empty")
        if len(voice_ids) > MAX_SPEAKERS:
            raise ValueError(f"VibeVoice supports at most {MAX_SPEAKERS} speakers per request")
        unknown = [v for v in voice_ids if v not in self._voices]
        if unknown:
            available = ", ".join(sorted(self._voices.keys())) or "(none configured — populate VIBEVOICE_VOICE_DIR)"
            raise ValueError(f"Unknown voice(s) {unknown}. Available: {available}")

        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            self._executor,
            lambda: self._synthesize_blocking(text, voice_ids, cfg_scale, ddpm_steps),
        )

    def _synthesize_blocking(
        self,
        text: str,
        voice_ids: List[str],
        cfg_scale: Optional[float],
        ddpm_steps: Optional[int],
    ) -> bytes:
        import torch

        assert self._model is not None and self._processor is not None, "model not loaded"

        # Override DDPM step count per-request if asked.
        if ddpm_steps is not None and ddpm_steps != config.DDPM_STEPS:
            self._model.set_ddpm_inference_steps(num_steps=ddpm_steps)

        formatted = _format_dialogue(text, len(voice_ids))
        voice_paths = [[self._voices[v][1]] for v in voice_ids]

        t0 = time.perf_counter()
        try:
            inputs = self._processor(
                text=[formatted],
                voice_samples=voice_paths,
                padding=True,
                return_tensors="pt",
                return_attention_mask=True,
            )
            inputs = {
                k: (v.to(self._device) if isinstance(v, torch.Tensor) else v)
                for k, v in inputs.items()
            }

            with torch.no_grad():
                outputs = self._model.generate(
                    **inputs,
                    max_new_tokens=None,
                    cfg_scale=cfg_scale if cfg_scale is not None else config.CFG_SCALE,
                    tokenizer=self._processor.tokenizer,
                    generation_config={"do_sample": False},
                    verbose=False,
                )
        except Exception as exc:
            raise RuntimeError(f"VibeVoice synthesis error: {exc}") from exc

        speech_outputs = getattr(outputs, "speech_outputs", None)
        if not speech_outputs:
            raise RuntimeError("VibeVoice produced no audio output")

        audio = speech_outputs[0]
        if hasattr(audio, "detach"):
            audio = audio.detach().to("cpu", dtype=torch.float32).numpy()
        samples = np.asarray(audio, dtype=np.float32).reshape(-1)

        elapsed = time.perf_counter() - t0
        wav = _pcm_to_wav(samples, config.SAMPLE_RATE)
        logger.info(
            "Synthesis OK — voices=%s, %.0f samples (%.2fs audio), %d bytes, %.2fs wall",
            voice_ids,
            len(samples),
            len(samples) / config.SAMPLE_RATE,
            len(wav),
            elapsed,
        )
        return wav

    # ── Shutdown ──────────────────────────────────────────────────────────────

    def shutdown(self) -> None:
        self._executor.shutdown(wait=False)
