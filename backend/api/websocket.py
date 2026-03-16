"""
GlassKiosk Copilot - WebSocket Handler (ADK Live API)
ADK 기반 Gemini Live API 실시간 양방향 스트리밍
Reference: https://github.com/google/adk-samples/tree/main/python/agents/bidi-demo
"""

import asyncio
import base64
import json
import logging
import uuid
from typing import Optional

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

from core.config import settings
from core.agent import get_kiosk_agent

logger = logging.getLogger(__name__)
router = APIRouter()

# 세션 서비스 및 Runner (앱 전역)
session_service = InMemorySessionService()
runner = Runner(
    agent=get_kiosk_agent(),
    app_name="glasskiosk_copilot",
    session_service=session_service,
)


def is_native_audio_model(model_name: str) -> bool:
    """Native Audio 모델 여부 확인"""
    return "native-audio" in model_name.lower()


@router.websocket("/ws/live")
async def websocket_live_endpoint(websocket: WebSocket):
    """
    WebSocket 실시간 스트리밍 엔드포인트 (ADK Live API)

    클라이언트 메시지 형식:
    - Binary: 오디오 데이터 (16kHz PCM)
    - JSON: {"type": "text", "data": "사용자 질문"}
    - JSON: {"type": "image", "data": "<base64>", "mime_type": "image/jpeg"}
    - JSON: {"type": "end"}

    서버 응답 형식:
    - {"type": "connected", "session_id": "..."}
    - {"type": "audio", "data": "<base64>"}
    - {"type": "text", "data": "..."}
    - {"type": "turn_complete"}
    - {"type": "error", "message": "..."}
    """
    await websocket.accept()

    # 세션 생성
    user_id = f"user_{uuid.uuid4().hex[:8]}"
    session_id = f"session_{uuid.uuid4().hex[:8]}"

    try:
        # 연결 확인 메시지
        await websocket.send_json({
            "type": "connected",
            "message": "GlassKiosk Live API 연결됨",
            "session_id": session_id,
            "user_id": user_id,
        })

        # 세션 생성
        session = await session_service.create_session(
            app_name="glasskiosk_copilot",
            user_id=user_id,
            session_id=session_id,
        )

        # 모델 타입에 따른 설정
        model_name = settings.gemini_model_audio
        if is_native_audio_model(model_name):
            # Native Audio 모델: AUDIO 응답
            run_config = types.RunConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name="Aoede"  # 한국어 지원 음성
                        )
                    )
                ),
                input_audio_transcription=types.AudioTranscriptionConfig(),
                output_audio_transcription=types.AudioTranscriptionConfig(),
            )
        else:
            # Half-cascade 모델: TEXT 응답
            run_config = types.RunConfig(
                response_modalities=["TEXT"],
            )

        # Live Request Queue 생성
        live_request_queue = runner.create_live_request_queue()

        # 양방향 스트리밍 태스크
        async def upstream_task():
            """클라이언트 → Gemini (업스트림)"""
            try:
                while True:
                    message = await websocket.receive()

                    if message["type"] == "websocket.disconnect":
                        break

                    if "bytes" in message:
                        # 바이너리 오디오 데이터
                        audio_data = message["bytes"]
                        await live_request_queue.send_realtime(
                            types.Blob(data=audio_data, mime_type="audio/pcm")
                        )

                    elif "text" in message:
                        # JSON 메시지
                        data = json.loads(message["text"])
                        msg_type = data.get("type")

                        if msg_type == "text":
                            # 텍스트 메시지
                            await live_request_queue.send_content(
                                types.Content(
                                    role="user",
                                    parts=[types.Part(text=data["data"])]
                                )
                            )

                        elif msg_type == "image":
                            # 이미지 데이터
                            image_bytes = base64.b64decode(data["data"])
                            mime_type = data.get("mime_type", "image/jpeg")
                            await live_request_queue.send_content(
                                types.Content(
                                    role="user",
                                    parts=[
                                        types.Part.from_bytes(
                                            data=image_bytes,
                                            mime_type=mime_type
                                        )
                                    ]
                                )
                            )

                        elif msg_type == "audio":
                            # Base64 인코딩된 오디오
                            audio_bytes = base64.b64decode(data["data"])
                            await live_request_queue.send_realtime(
                                types.Blob(
                                    data=audio_bytes,
                                    mime_type=data.get("mime_type", "audio/pcm")
                                )
                            )

                        elif msg_type == "end":
                            break

            except WebSocketDisconnect:
                logger.info(f"WebSocket disconnected: {session_id}")
            except Exception as e:
                logger.error(f"Upstream error: {e}")

        async def downstream_task():
            """Gemini → 클라이언트 (다운스트림)"""
            try:
                async for event in runner.run_live(
                    session=session,
                    live_request_queue=live_request_queue,
                    run_config=run_config,
                ):
                    if event.content:
                        for part in event.content.parts:
                            if part.text:
                                # 텍스트 응답
                                await websocket.send_json({
                                    "type": "text",
                                    "data": part.text,
                                })
                            elif part.inline_data:
                                # 오디오 응답
                                audio_b64 = base64.b64encode(
                                    part.inline_data.data
                                ).decode("utf-8")
                                await websocket.send_json({
                                    "type": "audio",
                                    "data": audio_b64,
                                    "mime_type": part.inline_data.mime_type,
                                })

                    if event.turn_complete:
                        await websocket.send_json({
                            "type": "turn_complete",
                        })

            except WebSocketDisconnect:
                logger.info(f"WebSocket disconnected during downstream: {session_id}")
            except Exception as e:
                logger.error(f"Downstream error: {e}")
                await websocket.send_json({
                    "type": "error",
                    "message": str(e),
                })

        # 병렬 실행
        await asyncio.gather(
            upstream_task(),
            downstream_task(),
            return_exceptions=True,
        )

    except WebSocketDisconnect:
        logger.info(f"Client disconnected: {session_id}")
    except Exception as e:
        logger.error(f"Session error: {e}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": f"세션 오류: {str(e)}",
            })
        except Exception:
            pass
    finally:
        # 정리
        try:
            await live_request_queue.close()
        except Exception:
            pass
        try:
            await websocket.close()
        except Exception:
            pass
        logger.info(f"Session closed: {session_id}")


@router.websocket("/ws/simple")
async def websocket_simple_endpoint(websocket: WebSocket):
    """
    간단한 텍스트 전용 WebSocket 엔드포인트
    (오디오 없이 텍스트만 주고받기)
    """
    await websocket.accept()

    try:
        await websocket.send_json({
            "type": "connected",
            "message": "Simple WebSocket 연결됨",
        })

        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")

            if msg_type == "text":
                # 텍스트 질문 처리
                user_text = data.get("data", "")

                # 세션 생성 및 실행
                session_id = f"simple_{uuid.uuid4().hex[:8]}"
                await session_service.create_session(
                    app_name="glasskiosk_copilot",
                    user_id="simple_user",
                    session_id=session_id,
                )

                # 동기식 실행
                response_text = ""
                async for event in runner.run(
                    session_id=session_id,
                    user_id="simple_user",
                    new_message=types.Content(
                        role="user",
                        parts=[types.Part(text=user_text)]
                    ),
                ):
                    if event.content:
                        for part in event.content.parts:
                            if part.text:
                                response_text += part.text

                await websocket.send_json({
                    "type": "response",
                    "data": response_text,
                })

            elif msg_type == "end":
                break

    except WebSocketDisconnect:
        pass
    except Exception as e:
        await websocket.send_json({
            "type": "error",
            "message": str(e),
        })
    finally:
        await websocket.close()


# =============================================================================
# GCP 데모 패턴 기반 엔드포인트 (native audio)
# Reference: https://github.com/GoogleCloudPlatform/generative-ai/tree/main/gemini/multimodal-live-api
# =============================================================================

@router.websocket("/ws/native")
async def websocket_native_endpoint(websocket: WebSocket, prompt_id: Optional[str] = None):
    """
    GCP 공식 데모 패턴 기반 Native Audio WebSocket

    Features:
    - 별도 입력 큐 (오디오, 비디오, 텍스트)
    - 콜백 기반 출력 처리
    - 전사(transcription) 지원
    - 중단(interruption) 처리

    Query Parameters:
    - prompt_id: 시스템 프롬프트 ID (예: kio_friendly, kio_senior)

    클라이언트 메시지:
    - Binary: PCM 오디오 (16kHz)
    - JSON: {"type": "config", "prompt_id": "kio_senior"} (첫 메시지로 프롬프트 변경 가능)
    - JSON: {"type": "image", "data": "<base64>"}
    - JSON: {"type": "text", "data": "질문"}
    - JSON: {"type": "end"}
    """
    from core.gemini_live import create_live_client, EventType

    await websocket.accept()
    client = create_live_client(prompt_id=prompt_id)

    try:
        await websocket.send_json({
            "type": "connected",
            "message": "Native Audio Live API 연결됨",
            "model": client.model,
            "prompt_id": client.prompt_id,
        })

        async def receive_from_client():
            """클라이언트 메시지 수신"""
            try:
                while True:
                    message = await websocket.receive()

                    if message["type"] == "websocket.disconnect":
                        await client.stop()
                        break

                    # 바이너리 오디오
                    if "bytes" in message:
                        await client.send_audio(message["bytes"])

                    # JSON 메시지
                    elif "text" in message:
                        data = json.loads(message["text"])
                        msg_type = data.get("type")

                        if msg_type == "image":
                            image_bytes = base64.b64decode(data["data"])
                            mime_type = data.get("mime_type", "image/jpeg")
                            await client.send_video(image_bytes, mime_type)

                        elif msg_type == "text":
                            await client.send_text(data["data"])

                        elif msg_type == "end":
                            await client.stop()
                            break

            except WebSocketDisconnect:
                await client.stop()

        async def send_to_client():
            """Gemini 응답 전송"""
            try:
                async for event in client.start_session():
                    if event.type == EventType.AUDIO:
                        # 바이너리 오디오 전송
                        await websocket.send_bytes(event.data)

                    elif event.type == EventType.TEXT:
                        await websocket.send_json({
                            "type": "text",
                            "data": event.data,
                        })

                    elif event.type == EventType.TRANSCRIPTION:
                        await websocket.send_json({
                            "type": "transcription",
                            "data": event.data,
                        })

                    elif event.type == EventType.TURN_COMPLETE:
                        await websocket.send_json({
                            "type": "turn_complete",
                        })

                    elif event.type == EventType.INTERRUPTED:
                        await websocket.send_json({
                            "type": "interrupted",
                        })

                    elif event.type == EventType.ERROR:
                        await websocket.send_json({
                            "type": "error",
                            "message": event.data,
                        })

            except WebSocketDisconnect:
                pass

        # 병렬 실행
        await asyncio.gather(
            receive_from_client(),
            send_to_client(),
            return_exceptions=True,
        )

    except WebSocketDisconnect:
        logger.info("Native client disconnected")
    except Exception as e:
        logger.error(f"Native session error: {e}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": str(e),
            })
        except Exception:
            pass
    finally:
        await client.stop()
        try:
            await websocket.close()
        except Exception:
            pass


# =============================================================================
# Immergo 패턴 기반 세션 관리 엔드포인트
# Reference: https://github.com/ZackAkil/immersive-language-learning-with-live-api
# =============================================================================

@router.websocket("/ws/session")
async def websocket_session_endpoint(websocket: WebSocket, prompt_id: Optional[str] = None):
    """
    Immergo 패턴 기반 세션 관리 WebSocket

    Features:
    - 세션 라이프사이클 관리
    - 상태 추적 (idle, connecting, active, speaking, listening)
    - 메트릭 수집
    - 전이중(Full-duplex) 오디오 스트리밍

    Query Parameters:
    - prompt_id: 시스템 프롬프트 ID (예: kio_friendly, kio_senior)

    클라이언트 메시지:
    - Binary: PCM 오디오 (16kHz)
    - JSON: {"type": "config", "prompt_id": "kio_senior"} (첫 메시지로 프롬프트 변경 가능)
    - JSON: {"type": "image", "data": "<base64>"}
    - JSON: {"type": "text", "data": "질문"}
    - JSON: {"type": "metrics"} - 세션 메트릭 요청
    - JSON: {"type": "end"}

    서버 메시지:
    - Binary: PCM 오디오 응답
    - JSON: {"type": "state", "data": "speaking"}
    - JSON: {"type": "transcription", "data": {...}}
    - JSON: {"type": "metrics", "data": {...}}
    """
    from core.gemini_live import create_live_session, EventType, SessionState

    await websocket.accept()
    session_id = f"session_{uuid.uuid4().hex[:8]}"

    # 상태 변경 콜백
    async def on_state_change(state: SessionState):
        try:
            await websocket.send_json({
                "type": "state",
                "data": state.value,
            })
        except Exception:
            pass

    session = create_live_session(
        session_id=session_id,
        prompt_id=prompt_id,
        on_state_change=lambda s: asyncio.create_task(on_state_change(s)),
    )

    try:
        await websocket.send_json({
            "type": "connected",
            "message": "Session-managed Live API 연결됨",
            "session_id": session_id,
            "model": session.client.model,
            "prompt_id": session.prompt_id,
        })

        async def receive_from_client():
            """클라이언트 메시지 수신 (Immergo 패턴)"""
            try:
                while True:
                    message = await websocket.receive()

                    if message["type"] == "websocket.disconnect":
                        await session.disconnect()
                        break

                    # 바이너리 오디오 (Full-duplex)
                    if "bytes" in message:
                        await session.send_audio(message["bytes"])

                    # JSON 메시지
                    elif "text" in message:
                        data = json.loads(message["text"])
                        msg_type = data.get("type")

                        if msg_type == "image":
                            image_bytes = base64.b64decode(data["data"])
                            mime_type = data.get("mime_type", "image/jpeg")
                            await session.send_video(image_bytes, mime_type)

                        elif msg_type == "text":
                            await session.send_text(data["data"])

                        elif msg_type == "audio":
                            # JSON으로 전송된 Base64 오디오 처리
                            audio_bytes = base64.b64decode(data["data"])
                            await session.send_audio(audio_bytes)

                        elif msg_type == "metrics":
                            # 세션 메트릭 반환
                            await websocket.send_json({
                                "type": "metrics",
                                "data": session.get_metrics(),
                            })

                        elif msg_type == "end":
                            await session.disconnect()
                            break

            except WebSocketDisconnect:
                await session.disconnect()

        async def send_to_client():
            """Gemini 응답 전송 (Full-duplex)"""
            try:
                async for event in session.connect():
                    if event.type == EventType.AUDIO:
                        # 바이너리 오디오 직접 전송 (저지연)
                        await websocket.send_bytes(event.data)

                    elif event.type == EventType.TEXT:
                        # Flutter 앱 호환용 response 형식
                        await websocket.send_json({
                            "type": "response",
                            "data": {
                                "detected_language": "ko-KR",
                                "audio_response": event.data,
                                "status": "success",
                            },
                        })

                    elif event.type == EventType.TRANSCRIPTION:
                        await websocket.send_json({
                            "type": "transcription",
                            "data": event.data,
                        })

                    elif event.type == EventType.TURN_COMPLETE:
                        await websocket.send_json({
                            "type": "turn_complete",
                        })

                    elif event.type == EventType.INTERRUPTED:
                        await websocket.send_json({
                            "type": "interrupted",
                        })

                    elif event.type == EventType.ERROR:
                        await websocket.send_json({
                            "type": "error",
                            "message": event.data,
                        })

            except WebSocketDisconnect:
                pass

        # 전이중 병렬 실행
        await asyncio.gather(
            receive_from_client(),
            send_to_client(),
            return_exceptions=True,
        )

    except WebSocketDisconnect:
        logger.info(f"Session client disconnected: {session_id}")
    except Exception as e:
        logger.error(f"Session error: {e}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": str(e),
            })
        except Exception:
            pass
    finally:
        await session.disconnect()
        logger.info(f"Session metrics: {session.get_metrics()}")
        try:
            await websocket.close()
        except Exception:
            pass
