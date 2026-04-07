# ── Build stage ───────────────────────────────────────────────────────────────
# Use a slim Python image.  Target CPU-only inference (~2 GB RAM, no GPU needed).
FROM python:3.12-slim AS base

# Install system-level audio/compression libs required by kokoro-onnx.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libsndfile1 \
        libgomp1 \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Python dependencies ───────────────────────────────────────────────────────

COPY requirements.txt .

# Install CPU-only ONNX runtime first (avoids pulling in GPU variant).
RUN pip install --no-cache-dir onnxruntime && \
    pip install --no-cache-dir -r requirements.txt

# ── Pre-bake model weights ────────────────────────────────────────────────────
# Download the Kokoro v1.0 ONNX weights at build time so the container starts
# without any network access.  The download is ~330 MB.
#
# The kokoro-onnx library stores weights in $XDG_CACHE_HOME (default /root/.cache).
# We pre-populate it here so runtime `Kokoro(model_name)` finds them immediately.

ENV KOKORO_MODEL_DIR=/app/models

RUN python -c "\
import os, urllib.request; \
os.makedirs('/app/models', exist_ok=True); \
base = 'https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/'; \
files = ['kokoro-v1.0.int8.onnx', 'voices-v1.0.bin']; \
[urllib.request.urlretrieve(base + f, f'/app/models/{f}') for f in files]; \
print('Model weights downloaded successfully') \
"

# ── Application code ─────────────────────────────────────────────────────────

COPY . .

# ── Runtime configuration ─────────────────────────────────────────────────────

# Bind to all interfaces inside the container (mapped to host 127.0.0.1 by
# docker-compose / -p flag).
ENV KOKORO_HOST=0.0.0.0
ENV KOKORO_PORT=3070
ENV KOKORO_MODEL_DIR=/app/models

# Number of ONNX inference threads.
ENV OMP_NUM_THREADS=2

EXPOSE 3070

# Run as a non-root user to limit the blast radius of any container compromise.
RUN useradd --create-home --shell /bin/bash kokoro && \
    chown -R kokoro:kokoro /app
USER kokoro

# Health check — waits up to 60s for the model to finish loading.
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=6 \
    CMD python -c "import urllib.request, sys; \
r = urllib.request.urlopen('http://localhost:3070/health', timeout=5); \
import json; d = json.loads(r.read()); \
sys.exit(0 if d.get('status') == 'ready' else 1)"

CMD ["uvicorn", "main:app", \
     "--host", "0.0.0.0", \
     "--port", "3070", \
     "--workers", "1", \
     "--log-level", "info"]
