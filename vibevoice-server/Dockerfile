# ── Base image ────────────────────────────────────────────────────────────────
# CPU-only build. Override FROM at build time to use a CUDA base image when
# deploying on a GPU host.
FROM python:3.12-slim AS base

# ffmpeg + libsndfile are needed by the VibeVoice audio processor.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        libsndfile1 \
        libgomp1 \
        git \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Python dependencies ───────────────────────────────────────────────────────

COPY requirements.txt .

# Torch CPU wheels are large — install them first so subsequent rebuilds reuse
# the layer. Override TORCH_INDEX_URL to pull CUDA wheels (e.g. https://download.pytorch.org/whl/cu121).
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir --index-url ${TORCH_INDEX_URL} \
        torch torchaudio || \
    pip install --no-cache-dir torch torchaudio

RUN pip install --no-cache-dir -r requirements.txt

# ── Application code ──────────────────────────────────────────────────────────

COPY . .

# ── Runtime configuration ─────────────────────────────────────────────────────

ENV VIBEVOICE_HOST=0.0.0.0 \
    VIBEVOICE_PORT=3073 \
    VIBEVOICE_MODEL_DIR=/app/models \
    VIBEVOICE_VOICE_DIR=/app/voices \
    HF_HOME=/app/models \
    OMP_NUM_THREADS=2

EXPOSE 3073

# Run as a non-root user.
RUN useradd --create-home --shell /bin/bash vibevoice && \
    mkdir -p /app/models /app/voices && \
    chown -R vibevoice:vibevoice /app
USER vibevoice

# Health check — VibeVoice can take several minutes to warm up on first run.
HEALTHCHECK --interval=15s --timeout=5s --start-period=300s --retries=10 \
    CMD python -c "import urllib.request, sys, json; \
r = urllib.request.urlopen('http://localhost:3073/health', timeout=5); \
d = json.loads(r.read()); \
sys.exit(0 if d.get('status') == 'ready' else 1)"

CMD ["uvicorn", "main:app", \
     "--host", "0.0.0.0", \
     "--port", "3073", \
     "--workers", "1", \
     "--log-level", "info"]
