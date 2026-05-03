"""
VibeVoice TTS FastAPI server.

Endpoints:
  GET  /health      → JSON { status, model, voices, device }
  GET  /voices      → JSON { voices: [{ id, label }] }
  POST /synthesize  → audio/wav bytes

Run:
  uvicorn main:app --host 127.0.0.1 --port 3073

Or via Docker:
  docker run -p 3073:3073 vibevoice-tts-server
"""
import asyncio
import logging
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse

import config
from auth import verify_api_key
from models import (
    HealthResponse,
    SynthesizeRequest,
    VoiceInfo,
    VoicesResponse,
)
from tts_engine import VibeVoiceEngine

# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s [%(name)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("vibevoice-server")

# ── Application lifespan ──────────────────────────────────────────────────────

engine = VibeVoiceEngine()


@asynccontextmanager
async def lifespan(app: FastAPI):  # noqa: ANN001
    logger.info(
        "VibeVoice TTS server starting — host=%s port=%d model=%s",
        config.HOST,
        config.PORT,
        config.MODEL_NAME,
    )

    if not config.VIBEVOICE_API_KEY:
        logger.warning(
            "VIBEVOICE_API_KEY is not set — all requests will be allowed without authentication. "
            "This is suitable for local development only. Set VIBEVOICE_API_KEY in production."
        )
    else:
        logger.info("VIBEVOICE_API_KEY is configured — protected endpoints require Bearer token")

    asyncio.create_task(engine.load())
    yield
    logger.info("VibeVoice TTS server shutting down")
    engine.shutdown()


app = FastAPI(
    title="VibeVoice TTS Server",
    description="Self-hosted Microsoft VibeVoice diffusion TTS inference server",
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
    if engine.load_error:
        content = HealthResponse(
            status="error",
            model=config.MODEL_NAME,
            voices=[],
            device=engine.device,
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
                device=engine.device,
            ).model_dump(),
        )

    return JSONResponse(
        status_code=200,
        content=HealthResponse(
            status="ready",
            model=config.MODEL_NAME,
            voices=engine.available_voices(),
            device=engine.device,
        ).model_dump(),
    )


@app.get(
    "/voices",
    response_model=VoicesResponse,
    summary="List all available voice presets",
    dependencies=[Depends(verify_api_key)],
)
async def list_voices() -> VoicesResponse:
    return VoicesResponse(
        voices=[VoiceInfo(id=vid, label=label) for vid, label in engine.voice_catalog()]
    )


@app.post(
    "/synthesize",
    summary="Synthesize text to WAV audio",
    responses={
        200: {
            "content": {"audio/wav": {}},
            "description": "WAV audio bytes",
        },
        400: {"description": "Invalid input (unknown voice, empty text)"},
        401: {"description": "Invalid or missing authorization token"},
        503: {"description": "Model not ready yet"},
        408: {"description": "Synthesis timed out"},
    },
    dependencies=[Depends(verify_api_key)],
)
async def synthesize(req: SynthesizeRequest) -> Response:
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

    logger.info(
        "POST /synthesize — voice=%s, lang=%s, text_len=%d",
        req.voice,
        req.language,
        len(req.text),
    )

    try:
        wav_bytes = await asyncio.wait_for(
            engine.synthesize(
                req.text,
                req.voice,
                req.language,
                cfg_scale=req.cfg_scale,
                ddpm_steps=req.ddpm_steps,
            ),
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
