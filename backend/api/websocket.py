"""
GlassKiosk Copilot - WebSocket Handler
Gemini Live API 실시간 스트리밍
"""

import asyncio
import base64
import json
from typing import Optional

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from google import genai
from google.genai import types

from core.config import settings


router = APIRouter()

# Live API 시스템 프롬프트
LIVE_SYSTEM_PROMPT = """당신은 키오스크 사용을 실시간으로 도와주는 AI 어시스턴트입니다.

## 핵심 규칙
1. **Visual Grounding**: 화면에 보이는 정보만 응답. 추측 금지.
2. **다국어 지원**: 사용자 언어 감지 후 해당 언어로 응답.
3. **실시간 가이드**: 짧고 명확한 안내 제공.
4. **좌표 제공**: 가능하면 UI 요소의 위치 정보 포함.

## 응답 형식 (JSON)
{"detected_language": "ko-KR", "target_item": "메뉴명", "coordinates": {"x": 0, "y": 0, "width": 100, "height": 50}, "audio_response": "안내 텍스트", "status": "success"}

짧고 자연스럽게 응답하세요. 반드시 JSON 형식으로만 응답하세요.
"""


class LiveSession:
    """Gemini Live API 세션 관리"""

    def __init__(self, websocket: WebSocket):
        self.websocket = websocket
        self.client = genai.Client(api_key=settings.google_api_key)
        self.session: Optional[genai.live.AsyncSession] = None
        self.is_active = False

    async def start(self):
        """Live API 세션 시작"""
        config = types.LiveConnectConfig(
            response_modalities=["TEXT"],
            system_instruction=types.Content(
                parts=[types.Part(text=LIVE_SYSTEM_PROMPT)]
            ),
        )

        async with self.client.aio.live.connect(
            model=settings.gemini_model,
            config=config,
        ) as session:
            self.session = session
            self.is_active = True

            # 병렬로 송수신 처리
            await asyncio.gather(
                self._receive_from_client(),
                self._send_to_client(),
            )

    async def _receive_from_client(self):
        """클라이언트로부터 데이터 수신 및 Gemini로 전송"""
        try:
            while self.is_active:
                data = await self.websocket.receive_json()
                msg_type = data.get("type")

                if msg_type == "image":
                    # 이미지 프레임 전송
                    image_data = base64.b64decode(data["data"])
                    await self.session.send(
                        input=types.LiveClientContent(
                            turns=[
                                types.Content(
                                    role="user",
                                    parts=[
                                        types.Part.from_bytes(
                                            data=image_data,
                                            mime_type=data.get("mime_type", "image/jpeg"),
                                        )
                                    ],
                                )
                            ]
                        )
                    )

                elif msg_type == "text":
                    # 텍스트 메시지 전송
                    await self.session.send(
                        input=types.LiveClientContent(
                            turns=[
                                types.Content(
                                    role="user",
                                    parts=[types.Part(text=data["data"])],
                                )
                            ]
                        )
                    )

                elif msg_type == "audio":
                    # 오디오 데이터 전송
                    audio_data = base64.b64decode(data["data"])
                    await self.session.send(
                        input=types.LiveClientRealtimeInput(
                            media_chunks=[
                                types.Blob(
                                    data=audio_data,
                                    mime_type=data.get("mime_type", "audio/pcm"),
                                )
                            ]
                        )
                    )

                elif msg_type == "end":
                    # 세션 종료
                    self.is_active = False
                    break

        except WebSocketDisconnect:
            self.is_active = False

    async def _send_to_client(self):
        """Gemini 응답을 클라이언트로 전송"""
        try:
            while self.is_active:
                async for response in self.session.receive():
                    if response.text:
                        # 텍스트 응답 전송
                        try:
                            # JSON 파싱 시도
                            parsed = json.loads(response.text)
                            await self.websocket.send_json({
                                "type": "response",
                                "data": parsed,
                            })
                        except json.JSONDecodeError:
                            # 일반 텍스트로 전송
                            await self.websocket.send_json({
                                "type": "text",
                                "data": response.text,
                            })

                    if response.server_content and response.server_content.turn_complete:
                        await self.websocket.send_json({
                            "type": "turn_complete",
                        })

        except WebSocketDisconnect:
            self.is_active = False
        except Exception as e:
            await self.websocket.send_json({
                "type": "error",
                "message": str(e),
            })


@router.websocket("/ws/live")
async def websocket_live_endpoint(websocket: WebSocket):
    """
    WebSocket 실시간 스트리밍 엔드포인트

    클라이언트 메시지 형식:
    - {"type": "image", "data": "<base64>", "mime_type": "image/jpeg"}
    - {"type": "text", "data": "사용자 질문"}
    - {"type": "audio", "data": "<base64>", "mime_type": "audio/pcm"}
    - {"type": "end"}

    서버 응답 형식:
    - {"type": "response", "data": {...}}
    - {"type": "text", "data": "..."}
    - {"type": "turn_complete"}
    - {"type": "error", "message": "..."}
    """
    await websocket.accept()

    try:
        # 연결 확인 메시지
        await websocket.send_json({
            "type": "connected",
            "message": "GlassKiosk Live API 연결됨",
        })

        # Live 세션 시작
        session = LiveSession(websocket)
        await session.start()

    except WebSocketDisconnect:
        pass
    except Exception as e:
        await websocket.send_json({
            "type": "error",
            "message": f"세션 오류: {str(e)}",
        })
    finally:
        await websocket.close()
