"""
GlassKiosk Copilot - FastAPI Application
메인 엔트리포인트 및 앱 초기화
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import ValidationError

from core.config import settings
from core.schemas import HealthResponse
from core.exceptions import (
    GlassKioskException,
    glasskiosk_exception_handler,
    validation_exception_handler,
    http_exception_handler,
    general_exception_handler,
)
from api.kiosk import router as kiosk_router
from api.websocket import router as websocket_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """앱 시작/종료 시 실행되는 라이프사이클 관리"""
    # Startup
    print("🚀 GlassKiosk Copilot 서버 시작")
    print("📍 Models:")
    print(f"   - Vision: {settings.gemini_model_vision}")
    print(f"   - Audio:  {settings.gemini_model_audio}")
    print(f"   - TTS:    {settings.gemini_model_tts}")
    print(f"🔧 Debug: {settings.debug}")
    print("📡 WebSocket Endpoints:")
    print("   - /ws/live    (ADK 패턴)")
    print("   - /ws/native  (GCP 데모 패턴)")
    print("   - /ws/session (Immergo 패턴 - Full-duplex)")
    print("   - /ws/simple  (텍스트 전용)")
    yield
    # Shutdown
    print("👋 서버 종료")


app = FastAPI(
    title="GlassKiosk Copilot API",
    description="AI 키오스크 네비게이션 도우미 - Gemini 3.0 기반",
    version="1.0.0",
    lifespan=lifespan,
)

# 예외 핸들러 등록
app.add_exception_handler(GlassKioskException, glasskiosk_exception_handler)
app.add_exception_handler(ValidationError, validation_exception_handler)
app.add_exception_handler(HTTPException, http_exception_handler)
app.add_exception_handler(Exception, general_exception_handler)

# CORS 미들웨어 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(kiosk_router, prefix="/api", tags=["Kiosk"])
app.include_router(websocket_router, tags=["WebSocket"])


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """서버 상태 확인"""
    return HealthResponse()


@app.get("/", tags=["Root"])
async def root():
    """루트 엔드포인트"""
    return {
        "service": "GlassKiosk Copilot",
        "status": "running",
        "docs": "/docs",
        "websocket": {
            "adk": "/ws/live",
            "native": "/ws/native",
            "session": "/ws/session",
            "simple": "/ws/simple",
        },
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
