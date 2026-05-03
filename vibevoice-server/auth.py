"""
API key authentication for the VibeVoice TTS server.

Protects /synthesize and /voices endpoints with a Bearer token in the
Authorization header that must match the VIBEVOICE_API_KEY environment variable.
"""

import hmac
import logging

from fastapi import Header, HTTPException

logger = logging.getLogger("vibevoice-server")


async def verify_api_key(authorization: str = Header(default="")) -> None:
    """
    Verifies that the Authorization header contains a valid Bearer token
    matching the VIBEVOICE_API_KEY environment variable.

    If VIBEVOICE_API_KEY is not set, logs a WARNING and allows all requests.
    Uses hmac.compare_digest for constant-time comparison.
    """
    import config

    if not config.VIBEVOICE_API_KEY:
        logger.warning("VIBEVOICE_API_KEY not set — all requests are accepted (dev mode only)")
        return

    if not authorization:
        logger.warning("Request missing Authorization header when VIBEVOICE_API_KEY is configured")
        raise HTTPException(status_code=401, detail="Authorization header required")

    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        logger.warning("Request with malformed Authorization header (expected 'Bearer <token>')")
        raise HTTPException(status_code=401, detail="Invalid authorization token")

    if not hmac.compare_digest(parts[1], config.VIBEVOICE_API_KEY):
        logger.warning("Request with invalid Bearer token")
        raise HTTPException(status_code=401, detail="Invalid authorization token")
