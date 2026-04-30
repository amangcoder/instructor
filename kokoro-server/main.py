"""
Kokoro TTS FastAPI server.

Endpoints:
  GET  /health      → JSON { status, model, voices }
  GET  /voices      → JSON { voices: [{ id, label }] }
  POST /synthesize  → audio/wav bytes

Run:
  uvicorn main:app --host 127.0.0.1 --port 3070

Or via Docker:
  docker run -p 3070:3070 kokoro-tts-server
"""
import asyncio
import base64
import logging
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse

import config
from alignment_engine import alignment_engine
from auth import verify_api_key
from models import (
    AlignBoundary,
    AlignRequest,
    AlignResponse,
    HealthResponse,
    SynthesizeRequest,
    VoiceInfo,
    VoicesResponse,
)
from tts_engine import KokoroEngine, VOICE_CATALOG

# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s [%(name)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("kokoro-server")

# ── Application lifespan ──────────────────────────────────────────────────────

engine = KokoroEngine()


@asynccontextmanager
async def lifespan(app: FastAPI):  # noqa: ANN001
    """Start model loading on server startup; clean up on shutdown."""
    logger.info(
        "Kokoro TTS server starting — host=%s port=%d",
        config.HOST,
        config.PORT,
    )

    # Log warning if API key is not configured
    if not config.KOKORO_API_KEY:
        logger.warning(
            "KOKORO_API_KEY is not set — all requests will be allowed without authentication. "
            "This is suitable for local development only. Set KOKORO_API_KEY in production."
        )
    else:
        logger.info("KOKORO_API_KEY is configured — protected endpoints require Bearer token")

    # Kick off model loading in the background — don't await here so the server
    # starts accepting requests (returning 503 from /health until ready).
    asyncio.create_task(engine.load())
    yield
    logger.info("Kokoro TTS server shutting down")
    engine.shutdown()


app = FastAPI(
    title="Kokoro TTS Server",
    description="Self-hosted Kokoro ONNX TTS inference server",
    version="1.0.0",
    lifespan=lifespan,
)

# ── Middleware: request latency logging ───────────────────────────────────────


@app.middleware("http")
async def log_requests(request: Request, call_next):  # noqa: ANN001
    t0 = time.perf_counter()
    response = await call_next(request)
    elapsed_ms = (time.perf_counter() - t0) * 1000
    logger.info(
        "%s %s → %d  (%.0f ms)",
        request.method,
        request.url.path,
        response.status_code,
        elapsed_ms,
    )
    return response


# ── Endpoints ─────────────────────────────────────────────────────────────────


@app.get(
    "/health",
    response_model=HealthResponse,
    summary="Server health and readiness check",
)
async def health() -> JSONResponse:
    """
    Returns 200 {status: 'ready'} when the model is fully loaded.
    Returns 503 {status: 'loading'} while model initialisation is in progress.
    Returns 503 {status: 'error', …} if model loading failed.
    """
    if engine.load_error:
        content = HealthResponse(
            status="error",
            model=config.MODEL_NAME,
            voices=[],
        ).model_dump()
        content["detail"] = engine.load_error
        return JSONResponse(status_code=503, content=content)

    if not engine.is_ready:
        return JSONResponse(
            status_code=503,
            content=HealthResponse(
                status="loading",
                model=config.MODEL_NAME,
                voices=[],
            ).model_dump(),
        )

    return JSONResponse(
        status_code=200,
        content=HealthResponse(
            status="ready",
            model=config.MODEL_NAME,
            voices=engine.available_voices(),
        ).model_dump(),
    )


@app.get(
    "/voices",
    response_model=VoicesResponse,
    summary="List all available voice IDs and labels",
    dependencies=[Depends(verify_api_key)],
)
async def list_voices() -> VoicesResponse:
    """Returns the full catalog of voice IDs and human-readable labels."""
    return VoicesResponse(
        voices=[
            VoiceInfo(id=vid, label=label)
            for vid, label in VOICE_CATALOG.items()
        ]
    )


@app.post(
    "/synthesize",
    summary="Synthesize text to WAV audio",
    responses={
        200: {
            "content": {"audio/wav": {}},
            "description": "WAV audio bytes",
        },
        400: {"description": "Invalid input (unknown voice, unsupported language, empty text)"},
        401: {"description": "Invalid or missing authorization token"},
        503: {"description": "Model not ready yet"},
        408: {"description": "Synthesis timed out"},
    },
    dependencies=[Depends(verify_api_key)],
)
async def synthesize(req: SynthesizeRequest) -> Response:
    """
    Synthesizes the given text with the specified voice and language.

    Returns `audio/wav` binary data on success.
    """
    if not engine.is_ready:
        if engine.load_error:
            raise HTTPException(
                status_code=503,
                detail=f"Model failed to load: {engine.load_error}",
            )
        raise HTTPException(
            status_code=503,
            detail="Model is still loading. Please retry after a few seconds.",
        )

    speed = req.speed if req.speed is not None else config.DEFAULT_SPEED

    logger.info(
        "POST /synthesize — voice=%s, lang=%s, speed=%.1f, text_len=%d",
        req.voice,
        req.language,
        speed,
        len(req.text),
    )

    try:
        wav_bytes = await asyncio.wait_for(
            engine.synthesize(req.text, req.voice, req.language, speed),
            timeout=config.SYNTHESIS_TIMEOUT_SEC,
        )
    except asyncio.TimeoutError:
        logger.error(
            "Synthesis timed out after %.0fs — voice=%s, text_len=%d",
            config.SYNTHESIS_TIMEOUT_SEC,
            req.voice,
            len(req.text),
        )
        raise HTTPException(
            status_code=408,
            detail=f"Synthesis timed out after {config.SYNTHESIS_TIMEOUT_SEC:.0f}s. Try a shorter text.",
        )
    except ValueError as exc:
        # Invalid voice or language.
        raise HTTPException(status_code=400, detail=str(exc))
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))

    return Response(
        content=wav_bytes,
        media_type="audio/wav",
        headers={
            "Content-Length": str(len(wav_bytes)),
            "X-Voice": req.voice,
            "X-Language": req.language,
        },
    )


@app.post(
    "/align",
    response_model=AlignResponse,
    summary="Forced-align ordered texts against a single concatenated audio",
    responses={
        200: {"description": "Per-text {start_ms, end_ms} windows in source order"},
        400: {"description": "Invalid PCM payload, sample rate, or text list"},
        401: {"description": "Invalid or missing authorization token"},
        408: {"description": "Alignment timed out"},
        500: {"description": "Alignment model failed"},
    },
    dependencies=[Depends(verify_api_key)],
)
async def align(req: AlignRequest) -> AlignResponse:
    """
    Returns one {start_ms, end_ms} window per input text. The caller slices
    the source PCM at those offsets to recover per-text audio.
    """
    try:
        pcm = base64.b64decode(req.audio_b64, validate=True)
    except (ValueError, base64.binascii.Error) as exc:
        raise HTTPException(status_code=400, detail=f"audio_b64 decode failed: {exc}")

    logger.info(
        "POST /align — texts=%d, sample_rate=%d, pcm_bytes=%d, language=%s",
        len(req.texts),
        req.sample_rate,
        len(pcm),
        req.language,
    )

    try:
        boundaries, duration_ms = await asyncio.wait_for(
            alignment_engine.align(pcm, req.sample_rate, req.texts, req.language),
            timeout=config.ALIGN_TIMEOUT_SEC,
        )
    except asyncio.TimeoutError:
        logger.error(
            "Alignment timed out after %.0fs — texts=%d, pcm_bytes=%d",
            config.ALIGN_TIMEOUT_SEC,
            len(req.texts),
            len(pcm),
        )
        raise HTTPException(
            status_code=408,
            detail=f"Alignment timed out after {config.ALIGN_TIMEOUT_SEC:.0f}s.",
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        logger.exception("Alignment failed")
        raise HTTPException(status_code=500, detail=f"alignment failed: {exc}")

    return AlignResponse(
        boundaries=[AlignBoundary(start_ms=b.start_ms, end_ms=b.end_ms) for b in boundaries],
        duration_ms=duration_ms,
    )
