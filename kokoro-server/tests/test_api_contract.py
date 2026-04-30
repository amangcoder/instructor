"""
Kokoro TTS Server — API contract tests.

These tests verify that the API surface (URLs, HTTP methods, response schemas)
matches the contract defined in TASK-004 acceptance criteria.  They run
without a real model by mocking the KokoroEngine.

Run with:
    pytest tests/test_api_contract.py -v
"""
import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, MagicMock
from httpx import ASGITransport, AsyncClient


# ---------------------------------------------------------------------------
# Shared mock engine fixture
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def mock_engine():
    """Replace the real KokoroEngine with a stub for all tests in this file."""
    import importlib
    import main as main_module
    importlib.reload(main_module)

    engine = MagicMock()
    engine.is_ready = True
    engine.load_error = None
    engine.available_voices.return_value = ["af_aoede", "af_bella", "am_adam", "am_echo"]
    engine.synthesize = AsyncMock(return_value=b"\x52\x49\x46\x46" + b"\x00" * 100)

    main_module.engine = engine
    yield engine


@pytest_asyncio.fixture
async def client():
    import main as main_module
    transport = ASGITransport(app=main_module.app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


# ---------------------------------------------------------------------------
# Contract: correct HTTP methods
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_health_accepts_get_method(client):
    """AC: GET /health → should return a response (not 405 Method Not Allowed)."""
    res = await client.get("/health")
    assert res.status_code != 405


@pytest.mark.asyncio
async def test_health_rejects_post_method(client):
    """POST /health is not a defined route."""
    res = await client.post("/health", json={})
    assert res.status_code == 405


@pytest.mark.asyncio
async def test_voices_accepts_get_method(client):
    """AC: GET /voices → should return a response."""
    res = await client.get("/voices")
    assert res.status_code != 405


@pytest.mark.asyncio
async def test_synthesize_accepts_post_method(client):
    """AC: POST /synthesize → should return a response."""
    res = await client.post(
        "/synthesize",
        json={"text": "Hello", "voice": "af_aoede", "language": "en-us"},
    )
    assert res.status_code != 405


@pytest.mark.asyncio
async def test_synthesize_rejects_get_method(client):
    """GET /synthesize is not defined — should return 405."""
    res = await client.get("/synthesize")
    assert res.status_code == 405


# ---------------------------------------------------------------------------
# Contract: health response schema
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_health_schema_has_status(client):
    res = await client.get("/health")
    assert "status" in res.json()


@pytest.mark.asyncio
async def test_health_schema_has_model(client):
    res = await client.get("/health")
    assert "model" in res.json()


@pytest.mark.asyncio
async def test_health_schema_has_voices_array(client):
    res = await client.get("/health")
    body = res.json()
    assert "voices" in body
    assert isinstance(body["voices"], list)


@pytest.mark.asyncio
async def test_health_status_value_is_one_of_known_states(client):
    """Status must be 'ready', 'loading', or 'error'."""
    res = await client.get("/health")
    assert res.json()["status"] in ("ready", "loading", "error")


# ---------------------------------------------------------------------------
# Contract: voices response schema
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_voices_schema_has_voices_array(client):
    res = await client.get("/voices")
    body = res.json()
    assert "voices" in body
    assert isinstance(body["voices"], list)


@pytest.mark.asyncio
async def test_voices_each_item_has_id_and_label(client):
    res = await client.get("/voices")
    for voice in res.json()["voices"]:
        assert "id" in voice, f"Voice missing 'id': {voice}"
        assert "label" in voice, f"Voice missing 'label': {voice}"


# ---------------------------------------------------------------------------
# Contract: synthesize returns audio/wav
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_synthesize_content_type_is_audio_wav(client):
    """AC: POST /synthesize returns audio/wav bytes."""
    res = await client.post(
        "/synthesize",
        json={"text": "Test", "voice": "af_aoede", "language": "en-us"},
    )
    assert res.status_code == 200
    assert res.headers["content-type"] == "audio/wav"


@pytest.mark.asyncio
async def test_synthesize_response_is_bytes(client):
    """Response body must be binary (not JSON)."""
    res = await client.post(
        "/synthesize",
        json={"text": "Test", "voice": "af_aoede", "language": "en-us"},
    )
    assert isinstance(res.content, bytes)
    assert len(res.content) > 0


# ---------------------------------------------------------------------------
# Contract: 503 before model is ready (TASK-004 AC)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_health_returns_503_while_loading():
    """AC: GET /health returns 503 {status: 'loading'} while model is initialising."""
    import importlib
    import main as main_module
    importlib.reload(main_module)

    loading_engine = MagicMock()
    loading_engine.is_ready = False
    loading_engine.load_error = None
    main_module.engine = loading_engine

    transport = ASGITransport(app=main_module.app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.get("/health")

    assert res.status_code == 503
    assert res.json()["status"] == "loading"


# ---------------------------------------------------------------------------
# Contract: invalid voice returns 400 (not 500)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_synthesize_invalid_voice_returns_400(client, mock_engine):
    """AC: POST /synthesize with invalid voice returns 400 with descriptive error."""
    mock_engine.synthesize = AsyncMock(
        side_effect=ValueError("Unknown voice: nonexistent_voice")
    )
    res = await client.post(
        "/synthesize",
        json={"text": "Hello", "voice": "nonexistent_voice", "language": "en-us"},
    )
    assert res.status_code == 400
    # Error message should be descriptive
    body = res.json()
    assert "detail" in body


# ---------------------------------------------------------------------------
# Contract: server binds to 127.0.0.1 by default (config check)
# ---------------------------------------------------------------------------

def test_default_host_is_localhost():
    """AC: server binds to 127.0.0.1 by default (not 0.0.0.0)."""
    import config
    assert config.HOST == "127.0.0.1"


def test_default_port_is_3070():
    """AC: default port is 3070."""
    import config
    assert config.PORT == 3070


def test_synthesis_timeout_is_30_seconds():
    """AC: synthesis times out after 30 seconds."""
    import config
    assert config.SYNTHESIS_TIMEOUT_SEC == 30.0


# ---------------------------------------------------------------------------
# Contract: Bearer token authentication (TASK-016)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_synthesize_returns_401_without_auth_when_key_configured():
    """POST /synthesize without Authorization header returns 401 when KOKORO_API_KEY is set."""
    import importlib
    import config as cfg

    original = cfg.KOKORO_API_KEY
    cfg.KOKORO_API_KEY = "test-secret"

    import main as main_module
    importlib.reload(main_module)

    engine = MagicMock()
    engine.is_ready = True
    engine.load_error = None
    engine.synthesize = AsyncMock(return_value=b"\x00" * 44)
    main_module.engine = engine

    transport = ASGITransport(app=main_module.app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.post(
            "/synthesize",
            json={"text": "Hello", "voice": "af_aoede", "language": "en-us"},
        )

    cfg.KOKORO_API_KEY = original
    assert res.status_code == 401
    assert "Authorization header required" in res.json()["detail"]


@pytest.mark.asyncio
async def test_synthesize_returns_200_with_valid_bearer_token():
    """POST /synthesize with correct Bearer token returns 200."""
    import importlib
    import config as cfg

    original = cfg.KOKORO_API_KEY
    cfg.KOKORO_API_KEY = "test-secret"

    import main as main_module
    importlib.reload(main_module)

    engine = MagicMock()
    engine.is_ready = True
    engine.load_error = None
    engine.synthesize = AsyncMock(return_value=b"\x52\x49\x46\x46" + b"\x00" * 100)
    main_module.engine = engine

    transport = ASGITransport(app=main_module.app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.post(
            "/synthesize",
            json={"text": "Hello", "voice": "af_aoede", "language": "en-us"},
            headers={"Authorization": "Bearer test-secret"},
        )

    cfg.KOKORO_API_KEY = original
    assert res.status_code == 200


@pytest.mark.asyncio
async def test_synthesize_returns_401_with_invalid_token():
    """POST /synthesize with wrong Bearer token returns 401."""
    import importlib
    import config as cfg

    original = cfg.KOKORO_API_KEY
    cfg.KOKORO_API_KEY = "test-secret"

    import main as main_module
    importlib.reload(main_module)

    engine = MagicMock()
    engine.is_ready = True
    engine.load_error = None
    main_module.engine = engine

    transport = ASGITransport(app=main_module.app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.post(
            "/synthesize",
            json={"text": "Hello", "voice": "af_aoede", "language": "en-us"},
            headers={"Authorization": "Bearer wrong-token"},
        )

    cfg.KOKORO_API_KEY = original
    assert res.status_code == 401
    assert "Invalid authorization token" in res.json()["detail"]


@pytest.mark.asyncio
async def test_health_works_without_auth_when_key_configured():
    """GET /health returns 200 without any auth header (liveness probe)."""
    import importlib
    import config as cfg

    original = cfg.KOKORO_API_KEY
    cfg.KOKORO_API_KEY = "test-secret"

    import main as main_module
    importlib.reload(main_module)

    engine = MagicMock()
    engine.is_ready = True
    engine.load_error = None
    engine.available_voices.return_value = ["af_aoede"]
    main_module.engine = engine

    transport = ASGITransport(app=main_module.app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.get("/health")

    cfg.KOKORO_API_KEY = original
    assert res.status_code == 200
