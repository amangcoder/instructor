"""
Pydantic request/response models for the VibeVoice TTS FastAPI server.
"""
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator

from config import MAX_TEXT_LENGTH


class SynthesizeRequest(BaseModel):
    """POST /synthesize — request body."""

    text: str = Field(
        ...,
        description=(
            "Text to synthesize. For multi-speaker dialogue use 'Speaker 1: …\\n"
            "Speaker 2: …' lines (up to 4 speakers). Single-speaker callers can "
            "send plain text — the server will wrap it as 'Speaker 1: <text>'."
        ),
    )
    voice: str = Field(
        ...,
        description=(
            "Voice preset id from /voices. For multi-speaker prompts pass a "
            "comma-separated list (e.g. 'alice,frank') matching speaker order."
        ),
    )
    language: str = Field("en-us", description="Locale hint, mostly informational.")
    cfg_scale: Optional[float] = Field(
        None, ge=1.0, le=3.0,
        description="Classifier-free guidance scale (default from config).",
    )
    ddpm_steps: Optional[int] = Field(
        None, ge=3, le=50,
        description="DDPM denoising steps (default from config).",
    )

    @field_validator("text")
    @classmethod
    def text_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("text must not be empty")
        if len(v) > MAX_TEXT_LENGTH:
            raise ValueError(f"text exceeds maximum length of {MAX_TEXT_LENGTH} characters")
        return v

    @field_validator("voice")
    @classmethod
    def voice_not_empty(cls, v: str) -> str:
        v = v.strip().lower()
        if not v:
            raise ValueError("voice must not be empty")
        return v

    @field_validator("language")
    @classmethod
    def language_normalize(cls, v: str) -> str:
        return v.strip().lower()


class VoiceInfo(BaseModel):
    """Voice metadata returned by GET /voices."""

    id: str
    label: str


class VoicesResponse(BaseModel):
    """GET /voices — response body."""

    voices: List[VoiceInfo]


class HealthResponse(BaseModel):
    """GET /health — response body."""

    status: str  # 'ready' | 'loading' | 'error'
    model: str
    voices: List[str]
    device: Optional[str] = None
