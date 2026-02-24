"""
GlassKiosk Copilot - Pydantic Schemas
API 요청/응답 모델 정의
"""

from typing import Optional
from pydantic import BaseModel, Field


class Coordinates(BaseModel):
    """UI 요소 좌표"""
    x: int = Field(..., description="X 좌표")
    y: int = Field(..., description="Y 좌표")
    width: int = Field(..., description="너비")
    height: int = Field(..., description="높이")


class KioskRequest(BaseModel):
    """키오스크 처리 요청"""
    image_base64: str = Field(..., description="Base64 인코딩된 이미지")
    user_query: Optional[str] = Field(None, description="사용자 음성/텍스트 입력")
    language_hint: Optional[str] = Field(None, description="언어 힌트 (예: ko-KR)")


class KioskResponse(BaseModel):
    """키오스크 처리 응답"""
    detected_language: str = Field(..., description="감지된 언어 코드", examples=["ko-KR", "en-US", "ja-JP"])
    target_item: Optional[str] = Field(None, description="인식된 메뉴/항목명")
    confirmation_msg: Optional[str] = Field(None, description="확인 메시지")
    coordinates: Optional[Coordinates] = Field(None, description="하이라이트 좌표")
    audio_response: str = Field(..., description="음성 안내 텍스트")
    status: str = Field(..., description="처리 상태", examples=["success", "error", "need_clarification"])


class ErrorResponse(BaseModel):
    """에러 응답"""
    status: str = Field(default="error")
    message: str = Field(..., description="에러 메시지")
    detected_language: str = Field(default="en-US")
    audio_response: str = Field(..., description="음성 안내용 에러 메시지")


class HealthResponse(BaseModel):
    """헬스체크 응답"""
    status: str = Field(default="healthy")
    service: str = Field(default="glasskiosk-copilot")
    version: str = Field(default="1.0.0")
