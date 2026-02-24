"""
GlassKiosk Copilot - Exception Handling
커스텀 예외 및 에러 핸들러
"""

from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from pydantic import ValidationError


class GlassKioskException(Exception):
    """기본 커스텀 예외"""

    def __init__(
        self,
        message: str,
        audio_response: str,
        detected_language: str = "en-US",
        status_code: int = 500,
    ):
        self.message = message
        self.audio_response = audio_response
        self.detected_language = detected_language
        self.status_code = status_code
        super().__init__(message)


class ImageProcessingError(GlassKioskException):
    """이미지 처리 오류"""

    def __init__(self, language: str = "ko-KR"):
        messages = {
            "ko-KR": ("이미지 처리 실패", "이미지를 처리할 수 없습니다. 더 가까이 비춰주세요."),
            "en-US": ("Image processing failed", "Unable to process image. Please move closer."),
            "ja-JP": ("画像処理失敗", "画像を処理できません。もっと近づけてください。"),
            "zh-CN": ("图像处理失败", "无法处理图像。请靠近一点。"),
        }
        msg, audio = messages.get(language, messages["en-US"])
        super().__init__(msg, audio, language, 400)


class APIKeyError(GlassKioskException):
    """API 키 오류"""

    def __init__(self):
        super().__init__(
            "Invalid or missing API key",
            "Service configuration error. Please contact support.",
            "en-US",
            500,
        )


class TimeoutError(GlassKioskException):
    """타임아웃 오류"""

    def __init__(self, language: str = "ko-KR"):
        messages = {
            "ko-KR": ("요청 시간 초과", "응답 시간이 초과되었습니다. 다시 시도해주세요."),
            "en-US": ("Request timeout", "Response timed out. Please try again."),
            "ja-JP": ("リクエストタイムアウト", "応答がタイムアウトしました。もう一度お試しください。"),
        }
        msg, audio = messages.get(language, messages["en-US"])
        super().__init__(msg, audio, language, 504)


class RateLimitError(GlassKioskException):
    """속도 제한 오류"""

    def __init__(self, language: str = "ko-KR"):
        messages = {
            "ko-KR": ("요청 한도 초과", "잠시 후 다시 시도해주세요."),
            "en-US": ("Rate limit exceeded", "Please wait a moment and try again."),
        }
        msg, audio = messages.get(language, messages["en-US"])
        super().__init__(msg, audio, language, 429)


# FastAPI 예외 핸들러
async def glasskiosk_exception_handler(request: Request, exc: GlassKioskException):
    """커스텀 예외 핸들러"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "status": "error",
            "message": exc.message,
            "detected_language": exc.detected_language,
            "audio_response": exc.audio_response,
        },
    )


async def validation_exception_handler(request: Request, exc: ValidationError):
    """Pydantic 검증 오류 핸들러"""
    return JSONResponse(
        status_code=422,
        content={
            "status": "error",
            "message": "Invalid request data",
            "detected_language": "en-US",
            "audio_response": "Invalid request. Please check your input.",
            "details": exc.errors(),
        },
    )


async def http_exception_handler(request: Request, exc: HTTPException):
    """HTTP 예외 핸들러"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "status": "error",
            "message": str(exc.detail),
            "detected_language": "en-US",
            "audio_response": "An error occurred. Please try again.",
        },
    )


async def general_exception_handler(request: Request, exc: Exception):
    """일반 예외 핸들러"""
    return JSONResponse(
        status_code=500,
        content={
            "status": "error",
            "message": "Internal server error",
            "detected_language": "en-US",
            "audio_response": "A server error occurred. Please try again later.",
        },
    )
