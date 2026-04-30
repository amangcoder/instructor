"""
API key authentication for Kokoro TTS server.

Protects /synthesize and /voices endpoints with a Bearer token in the
Authorization header that must match the KOKORO_API_KEY environment variable.
"""

import hmac
import logging
from typing import Optional

from fastapi import Header, HTTPException

logger = logging.getLogger("kokoro-server")


async def verify_api_key(authorization: str = Header(default="")) -> None:
    """
    Verifies that the Authorization header contains a valid Bearer token
    matching the KOKORO_API_KEY environment variable.

    If KOKORO_API_KEY is not set, logs a WARNING and allows all requests (dev mode).
    If set and the header is missing or doesn't contain a valid Bearer token,
    raises HTTPException(401).

    Uses hmac.compare_digest for constant-time comparison to prevent timing attacks.

    Args:
        authorization: The Authorization header value (defaults to empty string if missing)

    Raises:
        HTTPException: 401 if token is required but missing or invalid
    """
    import config

    # If no API key is configured, allow all requests (local dev mode)
    if not config.KOKORO_API_KEY:
        logger.warning("KOKORO_API_KEY not set — all requests are accepted (dev mode only)")
        return

    # If Authorization header is missing or empty
    if not authorization:
        logger.warning("Request missing Authorization header when KOKORO_API_KEY is configured")
        raise HTTPException(
            status_code=401,
            detail="Authorization header required",
        )

    # Parse Bearer token
    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        logger.warning("Request with malformed Authorization header (expected 'Bearer <token>')")
        raise HTTPException(
            status_code=401,
            detail="Invalid authorization token",
        )

    token = parts[1]

    # Use constant-time comparison to prevent timing attacks
    if not hmac.compare_digest(token, config.KOKORO_API_KEY):
        logger.warning("Request with invalid Bearer token")
        raise HTTPException(
            status_code=401,
            detail="Invalid authorization token",
        )
