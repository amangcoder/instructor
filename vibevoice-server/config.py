"""
Configuration for the Microsoft VibeVoice TTS Python server.
All settings are read from environment variables with sensible defaults.
"""
import os

# ── Network ──────────────────────────────────────────────────────────────────

# Host to bind to. 127.0.0.1 by default (not internet-exposed).
HOST: str = os.getenv("VIBEVOICE_HOST", "127.0.0.1")

# Port to listen on. Sits alongside Kokoro (3070), backend (3071), frontend (3072).
PORT: int = int(os.getenv("VIBEVOICE_PORT", "3073"))

# ── Model ─────────────────────────────────────────────────────────────────────

# HuggingFace repo to load. The 1.5B checkpoint is the small public release;
# Microsoft pulled the original microsoft/* repos but several community mirrors
# remain. Override at deploy time if you point at a private mirror.
MODEL_NAME: str = os.getenv("VIBEVOICE_MODEL_NAME", "microsoft/VibeVoice-1.5B")

# Local cache for downloaded model weights (mounted as a Docker volume).
MODEL_DIR: str = os.getenv(
    "VIBEVOICE_MODEL_DIR",
    os.path.join(os.path.dirname(__file__), "models"),
)

# Directory holding pre-recorded voice prompt WAVs (one per speaker preset).
# Each file becomes a selectable voice in /voices.
VOICE_DIR: str = os.getenv(
    "VIBEVOICE_VOICE_DIR",
    os.path.join(os.path.dirname(__file__), "voices"),
)

# Inference dtype. bfloat16 on CUDA; float32 on CPU/MPS for stability.
DTYPE: str = os.getenv("VIBEVOICE_DTYPE", "auto")

# Device override: "cuda", "mps", "cpu", or "auto" to pick the best available.
DEVICE: str = os.getenv("VIBEVOICE_DEVICE", "auto")

# Number of DDPM denoising steps used at inference. Higher = better quality, slower.
DDPM_STEPS: int = int(os.getenv("VIBEVOICE_DDPM_STEPS", "10"))

# Classifier-free guidance scale.
CFG_SCALE: float = float(os.getenv("VIBEVOICE_CFG_SCALE", "1.3"))

# ── Limits ────────────────────────────────────────────────────────────────────

# Maximum characters of text accepted per synthesis request. VibeVoice is built
# for long-form so we allow a much larger body than Kokoro by default.
MAX_TEXT_LENGTH: int = int(os.getenv("VIBEVOICE_MAX_TEXT_LENGTH", "20000"))

# How long a single synthesis may run before it is aborted (seconds).
SYNTHESIS_TIMEOUT_SEC: float = float(os.getenv("VIBEVOICE_SYNTHESIS_TIMEOUT_SEC", "300"))

# Maximum concurrent synthesis workers. Diffusion inference is GPU-bound so 1
# is the safe default — bump only when running on a beefy multi-GPU host.
MAX_CONCURRENT: int = int(os.getenv("VIBEVOICE_MAX_CONCURRENT", "1"))

# ── Audio output ─────────────────────────────────────────────────────────────

# Sample rate produced by VibeVoice's acoustic tokenizer (24 kHz).
SAMPLE_RATE: int = 24000

# ── API Key Authentication ────────────────────────────────────────────────────

# API key required to access /synthesize and /voices endpoints.
# If not set, all requests are allowed (development mode).
VIBEVOICE_API_KEY: str = os.getenv("VIBEVOICE_API_KEY", "")
