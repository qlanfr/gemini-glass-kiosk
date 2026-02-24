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

    # Gemini Model Settings
    gemini_model: str = "gemini-2.0-flash"

    # Server Configuration
    host: str = "0.0.0.0"
    port: int = 8000
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
