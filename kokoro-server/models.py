"""
Pydantic request/response models for the Kokoro TTS FastAPI server.
"""
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator

from config import MAX_TEXT_LENGTH


class SynthesizeRequest(BaseModel):
    """POST /synthesize — request body."""

    text: str = Field(..., description="Text to synthesize into audio.")
    voice: str = Field(..., description="Voice ID (e.g. 'af_heart', 'am_adam').")
    language: str = Field("en-us", description="Language/locale code (e.g. 'en-us', 'en-gb').")
    speed: Optional[float] = Field(None, ge=0.1, le=4.0, description="Speed multiplier (default 1.0).")

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
