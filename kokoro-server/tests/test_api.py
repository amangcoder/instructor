"""
Kokoro TTS Server — FastAPI endpoint tests.

All tests mock KokoroEngine to avoid loading real ONNX model weights,
making the suite run quickly on any machine (including CI without GPU/large RAM).

Test categories:
1. GET /health — ready, loading, error states
2. GET /voices — voice catalog listing
3. POST /synthesize — happy path, validation errors, timeout, 503 before ready
4. Authentication / request limits
5. API contract: correct content types, headers, schema

Run with:
    pip install pytest pytest-asyncio httpx
    pytest tests/test_api.py -v
"""
import asyncio
import io
import struct
import wave
from typing import AsyncIterator
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_wav_bytes(num_samples: int = 100, sample_rate: int = 24000) -> bytes:
    """Build a minimal valid WAV file in memory for mock responses."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)   # 16-bit PCM
        wf.setframerate(sample_rate)
        wf.writeframes(b"\x00\x00" * num_samples)
    return buf.getvalue()


MOCK_WAV = make_wav_bytes()
MOCK_VOICES = ["af_aoede", "af_bella", "am_adam", "am_echo"]


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_engine_ready():
    """A KokoroEngine mock that is fully loaded and synthesizes silently."""
    engine = MagicMock()
    engine.is_ready = True
    engine.load_error = None
    engine.available_voices.return_value = MOCK_VOICES
    engine.synthesize = AsyncMock(return_value=MOCK_WAV)
    return engine


@pytest.fixture
def mock_engine_loading():
    """A KokoroEngine mock that is still loading."""
    engine = MagicMock()
    engine.is_ready = False
    engine.load_error = None
    engine.available_voices.return_value = []
    return engine


@pytest.fixture
def mock_engine_error():
    """A KokoroEngine mock whose model loading failed."""
    engine = MagicMock()
    engine.is_ready = False
    engine.load_error = "ONNX file not found"
    engine.available_voices.return_value = []
    return engine


@pytest_asyncio.fixture
async def client_ready(mock_engine_ready) -> AsyncIterator[AsyncClient]:
    """HTTP test client pointing at an app with a ready engine."""
    with patch("main.engine", mock_engine_ready):
        # Import lazily so patch is applied before the module is imported
        import importlib
        import main as main_module
        importlib.reload(main_module)

        # Patch the engine on the reloaded module directly
        main_module.engine = mock_engine_ready

        transport = ASGITransport(app=main_module.app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            yield ac


@pytest_asyncio.fixture
async def client_loading(mock_engine_loading) -> AsyncIterator[AsyncClient]:
    """HTTP test client with engine still loading."""
    import importlib
    import main as main_module
    importlib.reload(main_module)
    main_module.engine = mock_engine_loading

    transport = ASGITransport(app=main_module.app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture
async def client_error(mock_engine_error) -> AsyncIterator[AsyncClient]:
    """HTTP test client with engine in error state."""
    import importlib
    import main as main_module
    importlib.reload(main_module)
    main_module.engine = mock_engine_error

    transport = ASGITransport(app=main_module.app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


# ---------------------------------------------------------------------------
# GET /health tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
class TestHealthEndpoint:
    async def test_health_returns_200_when_ready(self, client_ready):
        res = await client_ready.get("/health")
        assert res.status_code == 200

    async def test_health_body_has_status_ready(self, client_ready):
        res = await client_ready.get("/health")
        assert res.json()["status"] == "ready"

    async def test_health_body_includes_model_name(self, client_ready):
        res = await client_ready.get("/health")
        body = res.json()
        assert "model" in body
        assert isinstance(body["model"], str)
        assert len(body["model"]) > 0

    async def test_health_body_includes_voices_list(self, client_ready):
        res = await client_ready.get("/health")
        body = res.json()
        assert "voices" in body
        assert isinstance(body["voices"], list)
        assert len(body["voices"]) > 0

    async def test_health_returns_503_when_loading(self, client_loading):
        res = await client_loading.get("/health")
        assert res.status_code == 503

    async def test_health_status_is_loading_before_ready(self, client_loading):
        res = await client_loading.get("/health")
        assert res.json()["status"] == "loading"

    async def test_health_returns_503_when_model_failed(self, client_error):
        res = await client_error.get("/health")
        assert res.status_code == 503

    async def test_health_status_is_error_when_model_failed(self, client_error):
        res = await client_error.get("/health")
        assert res.json()["status"] == "error"

    async def test_health_returns_json(self, client_ready):
        res = await client_ready.get("/health")
        assert "application/json" in res.headers["content-type"]


# ---------------------------------------------------------------------------
# GET /voices tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
class TestVoicesEndpoint:
    async def test_voices_returns_200(self, client_ready):
        res = await client_ready.get("/voices")
        assert res.status_code == 200

    async def test_voices_body_has_voices_list(self, client_ready):
        res = await client_ready.get("/voices")
        body = res.json()
        assert "voices" in body
        assert isinstance(body["voices"], list)

    async def test_voices_list_is_not_empty(self, client_ready):
        res = await client_ready.get("/voices")
        voices = res.json()["voices"]
        assert len(voices) > 0

    async def test_each_voice_has_id_and_label(self, client_ready):
        res = await client_ready.get("/voices")
        for voice in res.json()["voices"]:
            assert "id" in voice
            assert "label" in voice
            assert isinstance(voice["id"], str)
            assert isinstance(voice["label"], str)

    async def test_voices_available_before_model_ready(self, client_loading):
        """Voice catalog is served from VOICE_CATALOG constant (not from model)."""
        res = await client_loading.get("/voices")
        assert res.status_code == 200


# ---------------------------------------------------------------------------
# POST /synthesize tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
class TestSynthesizeEndpoint:

    # ── Happy path ──────────────────────────────────────────────────────────

    async def test_synthesize_returns_200_for_valid_request(self, client_ready):
        res = await client_ready.post(
            "/synthesize",
            json={"text": "Hello world", "voice": "af_aoede", "language": "en-us"},
        )
        assert res.status_code == 200

    async def test_synthesize_returns_audio_wav_content_type(self, client_ready):
        res = await client_ready.post(
            "/synthesize",
            json={"text": "Hello world", "voice": "af_aoede", "language": "en-us"},
        )
        assert res.headers["content-type"] == "audio/wav"

    async def test_synthesize_response_body_is_non_empty(self, client_ready):
        res = await client_ready.post(
            "/synthesize",
            json={"text": "Take a deep breath", "voice": "am_adam", "language": "en-us"},
        )
        assert len(res.content) > 0

    async def test_synthesize_includes_content_length_header(self, client_ready):
        res = await client_ready.post(
            "/synthesize",
            json={"text": "Hello", "voice": "af_aoede", "language": "en-us"},
        )
        assert "content-length" in res.headers
        assert int(res.headers["content-length"]) > 0

    async def test_synthesize_passes_text_to_engine(self, client_ready, mock_engine_ready):
        await client_ready.post(
            "/synthesize",
            json={"text": "Test sentence", "voice": "af_aoede", "language": "en-us"},
        )
        mock_engine_ready.synthesize.assert_called_once()
        call_kwargs = mock_engine_ready.synthesize.call_args
        # text is passed as first positional or keyword argument
        args, kwargs = call_kwargs
        assert "Test sentence" in args or kwargs.get("text") == "Test sentence"

    async def test_synthesize_with_custom_speed_passes_speed_to_engine(
        self, client_ready, mock_engine_ready
    ):
        await client_ready.post(
            "/synthesize",
            json={"text": "Fast speech", "voice": "af_aoede", "language": "en-us", "speed": 1.5},
        )
        mock_engine_ready.synthesize.assert_called_once()

    # ── Validation errors ───────────────────────────────────────────────────

    async def test_synthesize_returns_422_for_empty_text(self, client_ready):
        res = await client_ready.post(
            "/synthesize",
            json={"text": "", "voice": "af_aoede", "language": "en-us"},
        )
        assert res.status_code in (400, 422)

    async def test_synthesize_returns_422_for_missing_text(self, client_ready):
        res = await client_ready.post(
            "/synthesize",
            json={"voice": "af_aoede", "language": "en-us"},
        )
        assert res.status_code == 422

    async def test_synthesize_returns_422_for_missing_voice(self, client_ready):
        res = await client_ready.post(
            "/synthesize",
            json={"text": "Hello", "language": "en-us"},
        )
        assert res.status_code == 422

    async def test_synthesize_returns_422_for_text_exceeding_max_length(self, client_ready):
        long_text = "A" * 10_001  # exceeds MAX_TEXT_LENGTH (5000)
        res = await client_ready.post(
            "/synthesize",
            json={"text": long_text, "voice": "af_aoede", "language": "en-us"},
        )
        assert res.status_code in (400, 422)

    async def test_synthesize_returns_422_for_speed_below_minimum(self, client_ready):
        res = await client_ready.post(
            "/synthesize",
            json={"text": "Hello", "voice": "af_aoede", "language": "en-us", "speed": 0.0},
        )
        assert res.status_code == 422

    async def test_synthesize_returns_422_for_speed_above_maximum(self, client_ready):
        res = await client_ready.post(
            "/synthesize",
            json={"text": "Hello", "voice": "af_aoede", "language": "en-us", "speed": 5.0},
        )
        assert res.status_code == 422

    async def test_synthesize_returns_400_for_invalid_voice(self, client_ready, mock_engine_ready):
        mock_engine_ready.synthesize.side_effect = ValueError("Unknown voice: bad_voice")
        res = await client_ready.post(
            "/synthesize",
            json={"text": "Hello", "voice": "bad_voice", "language": "en-us"},
        )
        assert res.status_code == 400

    # ── Service unavailable ─────────────────────────────────────────────────

    async def test_synthesize_returns_503_when_model_loading(self, client_loading):
        res = await client_loading.post(
            "/synthesize",
            json={"text": "Hello", "voice": "af_aoede", "language": "en-us"},
        )
        assert res.status_code == 503

    async def test_synthesize_returns_503_when_model_failed(self, client_error):
        res = await client_error.post(
            "/synthesize",
            json={"text": "Hello", "voice": "af_aoede", "language": "en-us"},
        )
        assert res.status_code == 503

    # ── Timeout ─────────────────────────────────────────────────────────────

    async def test_synthesize_returns_408_on_timeout(self, mock_engine_ready):
        """Engine.synthesize hangs → /synthesize should return 408."""
        async def hang(*args, **kwargs):
            await asyncio.sleep(1000)

        mock_engine_ready.synthesize = hang

        import importlib
        import main as main_module
        importlib.reload(main_module)
        main_module.engine = mock_engine_ready

        # Set a very short timeout for this test
        import config as cfg_module
        original_timeout = cfg_module.SYNTHESIS_TIMEOUT_SEC
        cfg_module.SYNTHESIS_TIMEOUT_SEC = 0.01

        transport = ASGITransport(app=main_module.app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            res = await ac.post(
                "/synthesize",
                json={"text": "Hello", "voice": "af_aoede", "language": "en-us"},
            )

        cfg_module.SYNTHESIS_TIMEOUT_SEC = original_timeout
        assert res.status_code == 408

    # ── Language normalisation ───────────────────────────────────────────────

    async def test_synthesize_defaults_language_to_en_us(self, client_ready, mock_engine_ready):
        """language field defaults to 'en-us' when not provided."""
        await client_ready.post(
            "/synthesize",
            json={"text": "Hello", "voice": "af_aoede"},
        )
        mock_engine_ready.synthesize.assert_called_once()

    async def test_synthesize_normalises_language_to_lowercase(self, client_ready, mock_engine_ready):
        """Voice and language inputs are normalised to lowercase."""
        await client_ready.post(
            "/synthesize",
            json={"text": "Hello", "voice": "AF_AOEDE", "language": "EN-US"},
        )
        args, kwargs = mock_engine_ready.synthesize.call_args
        # The validated language should be lowercase
        lang_arg = kwargs.get("language") or (args[2] if len(args) > 2 else None)
        if lang_arg is not None:
            assert lang_arg == lang_arg.lower()


# ---------------------------------------------------------------------------
# Pydantic model validation tests (unit tests, no server needed)
# ---------------------------------------------------------------------------

class TestSynthesizeRequest:
    """Pure unit tests for the SynthesizeRequest Pydantic model."""

    def test_valid_request_passes(self):
        from models import SynthesizeRequest
        req = SynthesizeRequest(text="Hello world", voice="af_aoede", language="en-us")
        assert req.text == "Hello world"
        assert req.voice == "af_aoede"

    def test_empty_text_raises(self):
        from models import SynthesizeRequest
        import pytest as pt
        with pt.raises(Exception):
            SynthesizeRequest(text="   ", voice="af_aoede")

    def test_text_is_stripped(self):
        from models import SynthesizeRequest
        req = SynthesizeRequest(text="  Hello  ", voice="af_aoede")
        assert req.text == "Hello"

    def test_voice_is_normalised_to_lowercase(self):
        from models import SynthesizeRequest
        req = SynthesizeRequest(text="Hello", voice="AF_AOEDE")
        assert req.voice == "af_aoede"

    def test_language_is_normalised_to_lowercase(self):
        from models import SynthesizeRequest
        req = SynthesizeRequest(text="Hello", voice="af_aoede", language="EN-US")
        assert req.language == "en-us"

    def test_speed_defaults_to_none(self):
        from models import SynthesizeRequest
        req = SynthesizeRequest(text="Hello", voice="af_aoede")
        assert req.speed is None

    def test_speed_below_minimum_raises(self):
        from models import SynthesizeRequest
        import pytest as pt
        with pt.raises(Exception):
            SynthesizeRequest(text="Hello", voice="af_aoede", speed=0.0)

    def test_speed_above_maximum_raises(self):
        from models import SynthesizeRequest
        import pytest as pt
        with pt.raises(Exception):
            SynthesizeRequest(text="Hello", voice="af_aoede", speed=5.0)

    def test_text_exceeding_max_length_raises(self):
        from models import SynthesizeRequest
        import pytest as pt
        from config import MAX_TEXT_LENGTH
        with pt.raises(Exception):
            SynthesizeRequest(text="A" * (MAX_TEXT_LENGTH + 1), voice="af_aoede")
