"""
GlassKiosk Copilot - Configuration Management
환경변수 및 설정 중앙 관리
"""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """애플리케이션 설정 클래스"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Google AI API
    google_api_key: str

    # Gemini Model Settings (용도별 분리)
    gemini_model_vision: str = "gemini-2.5-flash-lite"  # 이미지 분석용
    gemini_model_audio: str = "gemini-2.0-flash-live-001"  # 실시간 음성+텍스트 (다국어 지원)
    gemini_model_tts: str = "gemini-2.5-flash-preview-tts"  # 음성 응답 생성

    # 하위 호환성
    gemini_model: str = "gemini-2.5-flash-lite"

    # Server Configuration
    host: str = "0.0.0.0"
    port: int = 8080  # Cloud Run default
    debug: bool = False

    # CORS Settings
    cors_origins: list[str] = ["*"]

    # API Settings
    api_timeout: int = 30  # seconds
    max_image_size: int = 10 * 1024 * 1024  # 10MB


@lru_cache
def get_settings() -> Settings:
    """
    설정 싱글톤 인스턴스 반환
    lru_cache로 한 번만 로딩하여 재사용
    """
    return Settings()


# 전역 설정 접근용
settings = get_settings()
