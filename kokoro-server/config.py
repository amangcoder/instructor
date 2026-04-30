"""
Configuration for the Kokoro TTS Python server.
All settings are read from environment variables with sensible defaults.
"""
import os

# ── Network ──────────────────────────────────────────────────────────────────

# Host to bind to.  127.0.0.1 by default (not internet-exposed).
HOST: str = os.getenv("KOKORO_HOST", "127.0.0.1")

# Port to listen on.
PORT: int = int(os.getenv("KOKORO_PORT", "3070"))

# ── Model ─────────────────────────────────────────────────────────────────────

# Directory where model weights are stored.  The ONNX model file and voice
# packs are placed here during the Docker build (or downloaded at runtime).
MODEL_DIR: str = os.getenv("KOKORO_MODEL_DIR", os.path.join(os.path.dirname(__file__), "models"))

# Model variant to load.  kokoro-v1.0.int8 is the current stable ONNX release.
MODEL_NAME: str = os.getenv("KOKORO_MODEL_NAME", "kokoro-v1.0.int8")

# ── Limits ────────────────────────────────────────────────────────────────────

# Maximum characters of text accepted per synthesis request.
MAX_TEXT_LENGTH: int = int(os.getenv("KOKORO_MAX_TEXT_LENGTH", "5000"))

# How long a single synthesis may run before it is aborted (seconds).
SYNTHESIS_TIMEOUT_SEC: float = float(os.getenv("KOKORO_SYNTHESIS_TIMEOUT_SEC", "30"))

# Maximum concurrent synthesis workers (limits CPU saturation).
MAX_CONCURRENT: int = int(os.getenv("KOKORO_MAX_CONCURRENT", "4"))

# ── Audio output ─────────────────────────────────────────────────────────────

# Default speech speed multiplier (1.0 = normal).
DEFAULT_SPEED: float = float(os.getenv("KOKORO_DEFAULT_SPEED", "1.0"))

# Sample rate produced by the Kokoro model (24 kHz).
SAMPLE_RATE: int = 24000

# ── API Key Authentication ────────────────────────────────────────────────────

# API key required to access /synthesize and /voices endpoints.
# If not set, all requests are allowed (development mode).
# If set, all requests to protected endpoints must include Authorization: Bearer <key> header.
# Generated per deployment and stored securely in environment variables.
KOKORO_API_KEY: str = os.getenv("KOKORO_API_KEY", "")

# ── Forced alignment ─────────────────────────────────────────────────────────

# HuggingFace model id for ctc-forced-aligner. Default: multilingual MMS-300M.
ALIGN_MODEL: str = os.getenv("ALIGN_MODEL", "MahmoudAshraf/mms-300m-1130-forced-aligner")

# Sample rate the alignment model expects (MMS = 16 kHz). Input audio is
# resampled to this rate before alignment.
ALIGN_SAMPLE_RATE: int = 16000

# "cpu", "cuda", or "auto" (cuda if available, else cpu).
ALIGN_DEVICE: str = os.getenv("ALIGN_DEVICE", "auto")

# Batch size used by the aligner's emission generator.
ALIGN_BATCH_SIZE: int = int(os.getenv("ALIGN_BATCH_SIZE", "4"))

# How long a single /align call may run before it is aborted.
ALIGN_TIMEOUT_SEC: float = float(os.getenv("ALIGN_TIMEOUT_SEC", "60"))
