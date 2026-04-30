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


class AlignRequest(BaseModel):
    """POST /align — request body.

    Caller sends raw 16-bit little-endian mono PCM (base64-encoded) plus the
    ordered list of texts that produced it. The server returns one
    {start_ms, end_ms} window per input text.
    """

    audio_b64: str = Field(..., description="Base64-encoded 16-bit LE mono PCM.")
    sample_rate: int = Field(..., gt=0, description="Sample rate of the supplied PCM.")
    texts: List[str] = Field(..., min_length=1, description="Ordered text chunks the audio was generated from.")
    language: str = Field("eng", description="ISO-639-3 language code (e.g. 'eng', 'hin', 'spa').")

    @field_validator("texts")
    @classmethod
    def texts_non_empty(cls, v: List[str]) -> List[str]:
        cleaned = [t.strip() for t in v]
        if any(not t for t in cleaned):
            raise ValueError("texts entries must not be empty")
        return cleaned

    @field_validator("language")
    @classmethod
    def language_normalize(cls, v: str) -> str:
        return v.strip().lower()


class AlignBoundary(BaseModel):
    """One {start_ms, end_ms} window in the source audio."""

    start_ms: int
    end_ms: int


class AlignResponse(BaseModel):
    """POST /align — response body."""

    boundaries: List[AlignBoundary]
    duration_ms: int
