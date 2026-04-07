"""
Modal deployment for the Kokoro TTS FastAPI server.

FIRST-TIME SETUP
----------------
1. Install and authenticate Modal:
       pip install modal
       python3 -m modal setup

2. Download model weights into the persistent volume (run once):
       modal run kokoro-server/modal_app.py::download_models

3. Deploy (or serve locally for testing):
       modal deploy kokoro-server/modal_app.py   # production
       modal serve  kokoro-server/modal_app.py   # local dev tunnel

After deploy, Modal prints a URL like:
    https://<your-workspace>--kokoro-tts-kokoro-server-serve.modal.run

Set that as KOKORO_SERVER_URL in your NestJS backend .env:
    KOKORO_SERVER_URL=https://<your-workspace>--kokoro-tts-kokoro-server-serve.modal.run
"""

import os
from pathlib import Path

import modal

# ── App ────────────────────────────────────────────────────────────────────────

app = modal.App("kokoro-tts")

# ── Model volume ───────────────────────────────────────────────────────────────
# Persists the ~330 MB ONNX weights + voice pack across deployments so they are
# not re-downloaded on every cold start.

model_volume = modal.Volume.from_name("kokoro-models", create_if_missing=True)
MODEL_DIR = "/models"
_MODEL_BASE_URL = (
    "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/"
)
_MODEL_FILES = ["kokoro-v1.0.int8.onnx", "voices-v1.0.bin"]

# ── Container image ────────────────────────────────────────────────────────────
# Mirrors the Dockerfile: slim Python 3.12 + system libs + Python deps.
# onnxruntime installed first to guarantee the CPU-only variant is used.
#
# add_local_dir (copy=False) ships source files into each container at startup
# without baking them into the image layer — so `modal deploy` picks up code
# changes immediately without a full image rebuild.

_SOURCE_DIR = Path(__file__).parent

image = (
    modal.Image.debian_slim(python_version="3.12")
    .apt_install("libsndfile1", "libgomp1")
    .pip_install("onnxruntime")  # explicit: ensures CPU-only variant before kokoro-onnx resolves it
    .pip_install(
        "kokoro-onnx>=0.4.0",   # brings numpy + onnxruntime transitively
        "fastapi>=0.115.0",     # brings pydantic v2 transitively
        "uvicorn>=0.30.0",      # no [standard] extras needed
    )
    .add_local_dir(
        str(_SOURCE_DIR),
        remote_path="/kokoro_server",
        copy=False,
        ignore=["__pycache__", "*.pyc", "models/", "tests/", "modal_app.py"],
    )
)

# ── Model download helper ──────────────────────────────────────────────────────


@app.function(
    image=image,
    volumes={MODEL_DIR: model_volume},
    timeout=600,
)
def download_models():
    """Download Kokoro model weights into the persistent volume.

    Run once before the first deploy (or whenever you want to refresh weights):
        modal run kokoro-server/modal_app.py::download_models
    """
    import urllib.request

    os.makedirs(MODEL_DIR, exist_ok=True)
    for filename in _MODEL_FILES:
        dest = os.path.join(MODEL_DIR, filename)
        if os.path.exists(dest):
            size_mb = os.path.getsize(dest) / 1_048_576
            print(f"  {filename} already cached ({size_mb:.1f} MB) — skipping")
            continue
        url = _MODEL_BASE_URL + filename
        print(f"  Downloading {filename} …")
        urllib.request.urlretrieve(url, dest)
        size_mb = os.path.getsize(dest) / 1_048_576
        print(f"  {filename} downloaded ({size_mb:.1f} MB)")

    model_volume.commit()
    print("Done — model weights committed to volume 'kokoro-models'.")


# ── FastAPI server ─────────────────────────────────────────────────────────────


@app.cls(
    image=image,
    volumes={MODEL_DIR: model_volume},
    cpu=2.0,
    memory=4096,
    # Keep one warm container so users never hit a cold-start mid-workout.
    min_containers=1,
    # Scale out for concurrent plan pre-renders; each container handles up to
    # MAX_CONCURRENT (4) synthesis threads simultaneously.
    max_containers=5,
    timeout=120,
)
class KokoroServer:
    @modal.enter()
    def startup(self):
        """Configure environment before the FastAPI app and model loader start."""
        import sys

        # Point the config module at the volume-backed model directory.
        os.environ["KOKORO_MODEL_DIR"] = MODEL_DIR
        os.environ["OMP_NUM_THREADS"] = "2"

        # Make the kokoro-server package importable.
        sys.path.insert(0, "/kokoro_server")

    @modal.asgi_app(label="serve")
    def serve(self):
        """Return the existing FastAPI application as the ASGI entrypoint.

        Modal routes all HTTP traffic for this deployment to this app, so the
        endpoint URLs are identical to the local server:
            GET  /health
            GET  /voices
            POST /synthesize
        """
        from main import app as fastapi_app  # noqa: PLC0415

        return fastapi_app
