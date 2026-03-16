"""
GlassKiosk Copilot - Gemini Live API Client

References:
- https://github.com/GoogleCloudPlatform/generative-ai/tree/main/gemini/multimodal-live-api
- https://github.com/ZackAkil/immersive-language-learning-with-live-api

Features:
- Full-duplex WebSocket audio streaming
- Separate input queues (audio, video, text)
- Callback-based output handling
- Session lifecycle management
"""

import asyncio
from dataclasses import dataclass
from enum import Enum
from typing import AsyncGenerator, Callable, Optional, Any

from google import genai
from google.genai import types

from .config import settings
from .prompts import get_instruction, DEFAULT_PROMPT_ID


class EventType(Enum):
    """이벤트 타입"""
    AUDIO = "audio"
    TEXT = "text"
    TRANSCRIPTION = "transcription"
    TURN_COMPLETE = "turn_complete"
    INTERRUPTED = "interrupted"
    TOOL_CALL = "tool_call"
    ERROR = "error"


@dataclass
class LiveEvent:
    """Live API 이벤트"""
    type: EventType
    data: Any = None
    mime_type: Optional[str] = None


class GeminiLiveClient:
    """
    Gemini Live API 클라이언트
    GCP 공식 데모 패턴 기반 구현
    """

    def __init__(
        self,
        model: Optional[str] = None,
        sample_rate: int = 16000,
        system_instruction: Optional[str] = None,
        prompt_id: Optional[str] = None,
    ):
        self.client = genai.Client(api_key=settings.google_api_key)
        self.model = model or settings.gemini_model_audio
        self.sample_rate = sample_rate
        self.prompt_id = prompt_id or DEFAULT_PROMPT_ID
        # system_instruction 직접 제공 > prompt_id로 가져오기 > 기본값
        self.system_instruction = system_instruction or get_instruction(self.prompt_id)

        # 입력 큐 (오디오, 비디오, 텍스트 분리)
        self.audio_queue: asyncio.Queue = asyncio.Queue()
        self.video_queue: asyncio.Queue = asyncio.Queue()
        self.text_queue: asyncio.Queue = asyncio.Queue()

        # 콜백
        self.on_audio: Optional[Callable[[bytes], None]] = None
        self.on_text: Optional[Callable[[str], None]] = None

        # 상태
        self._session = None
        self._running = False

    def _default_instruction(self) -> str:
        return """# 당신은 "키오(Kio)" - 친절한 키오스크 도우미입니다!

## 캐릭터 설정
- 이름: 키오 (Kio) - "Kiosk"에서 따온 이름
- 성격: 따뜻하고 인내심 있는 친구 같은 도우미
- 목표: 키오스크가 어려운 분들이 자신감을 갖도록 응원하기

## 말투 스타일
- 친근하고 따뜻하게: "네~ 제가 도와드릴게요!", "잘 하고 계세요!"
- 격려하며: "어렵지 않아요, 천천히 해봐요~", "거의 다 됐어요!"
- 명확하게: 위치는 "화면 왼쪽 위", "빨간 버튼" 등 구체적으로

## 언어별 인사
- 한국어: "안녕하세요! 키오예요~ 뭘 도와드릴까요?"
- English: "Hi there! I'm Kio, your kiosk buddy! How can I help?"
- 日本語: "こんにちは！キオです〜何をお手伝いしましょうか？"
- 中文: "你好！我是Kio，有什么可以帮您的？"

## 핵심 규칙
1. **Visual Grounding**: 화면에 보이는 것만 말해요. 추측은 NO!
2. **다국어**: 사용자 언어 감지 → 그 언어로 응답
3. **실시간**: 짧고 간결하게, 하지만 따뜻하게!

## 상황별 응답
- 메뉴 찾기: "아~ 그 메뉴요! 화면 오른쪽 위에 있어요, 보이시죠?"
- 주문 확인: "네, [메뉴명] 맞으시죠? 맛있는 선택이에요~"
- 결제 안내: "거의 다 됐어요! 카드를 아래 투입구에 넣어주세요~"
- 실수했을 때: "괜찮아요! 왼쪽 '취소' 버튼 누르면 돼요~"
- 안 보일 때: "조금만 더 가까이 보여주시겠어요? 제가 잘 볼 수 있게요~"

## 금지 사항
- 없는 메뉴 만들어내기 ❌
- 딱딱한 기계적 말투 ❌
- 너무 긴 설명 ❌"""

    def _is_native_audio(self) -> bool:
        """Native Audio 모델 여부"""
        return "native-audio" in self.model.lower()

    async def send_audio(self, audio_data: bytes):
        """오디오 데이터 전송"""
        await self.audio_queue.put(audio_data)

    async def send_video(self, image_data: bytes, mime_type: str = "image/jpeg"):
        """비디오/이미지 프레임 전송"""
        await self.video_queue.put((image_data, mime_type))

    async def send_text(self, text: str, end_of_turn: bool = True):
        """텍스트 메시지 전송"""
        await self.text_queue.put((text, end_of_turn))

    async def stop(self):
        """세션 종료"""
        self._running = False

    async def start_session(self) -> AsyncGenerator[LiveEvent, None]:
        """
        Live API 세션 시작 및 이벤트 스트리밍

        Yields:
            LiveEvent: 오디오, 텍스트, 전사, 턴 완료 등의 이벤트
        """
        # 설정 구성
        # Native Audio 모델: 음성 자동 언어 감지 (voice 미지정 시 자동)
        config = types.LiveConnectConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(
                        voice_name="Kore"  # 다국어 지원 음성 (자동 언어 전환)
                    )
                )
            ),
            system_instruction=types.Content(
                parts=[types.Part(text=self.system_instruction)]
            ),
            input_audio_transcription=types.AudioTranscriptionConfig(),
            output_audio_transcription=types.AudioTranscriptionConfig(),
        )

        self._running = True

        async with self.client.aio.live.connect(
            model=self.model,
            config=config,
        ) as session:
            self._session = session

            # 동시 실행 태스크
            tasks = [
                asyncio.create_task(self._send_audio_loop(session)),
                asyncio.create_task(self._send_video_loop(session)),
                asyncio.create_task(self._send_text_loop(session)),
            ]

            try:
                # 응답 수신 및 이벤트 생성
                async for response in session.receive():
                    if not self._running:
                        break

                    # 서버 컨텐츠 처리
                    if response.server_content:
                        content = response.server_content

                        # 모델 턴 내용
                        if content.model_turn:
                            for part in content.model_turn.parts:
                                # 오디오 응답
                                if part.inline_data:
                                    audio_data = part.inline_data.data
                                    if self.on_audio:
                                        self.on_audio(audio_data)
                                    yield LiveEvent(
                                        type=EventType.AUDIO,
                                        data=audio_data,
                                        mime_type=part.inline_data.mime_type,
                                    )

                                # 텍스트 응답
                                if part.text:
                                    if self.on_text:
                                        self.on_text(part.text)
                                    yield LiveEvent(
                                        type=EventType.TEXT,
                                        data=part.text,
                                    )

                        # 출력 전사
                        if content.output_transcription:
                            yield LiveEvent(
                                type=EventType.TRANSCRIPTION,
                                data={
                                    "type": "output",
                                    "text": content.output_transcription.text,
                                },
                            )

                        # 입력 전사
                        if content.input_transcription:
                            yield LiveEvent(
                                type=EventType.TRANSCRIPTION,
                                data={
                                    "type": "input",
                                    "text": content.input_transcription.text,
                                },
                            )

                        # 턴 완료
                        if content.turn_complete:
                            yield LiveEvent(type=EventType.TURN_COMPLETE)

                        # 중단됨
                        if content.interrupted:
                            yield LiveEvent(type=EventType.INTERRUPTED)

                    # 툴 호출 (향후 확장)
                    if response.tool_call:
                        yield LiveEvent(
                            type=EventType.TOOL_CALL,
                            data=response.tool_call,
                        )

            except Exception as e:
                yield LiveEvent(
                    type=EventType.ERROR,
                    data=str(e),
                )
            finally:
                # 태스크 정리
                for task in tasks:
                    task.cancel()
                    try:
                        await task
                    except asyncio.CancelledError:
                        pass

    async def _send_audio_loop(self, session):
        """오디오 전송 루프"""
        while self._running:
            try:
                audio_data = await asyncio.wait_for(
                    self.audio_queue.get(),
                    timeout=0.1
                )
                await session.send(
                    input=types.LiveClientRealtimeInput(
                        media_chunks=[
                            types.Blob(
                                data=audio_data,
                                mime_type=f"audio/pcm;rate={self.sample_rate}",
                            )
                        ]
                    )
                )
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                break

    async def _send_video_loop(self, session):
        """비디오 전송 루프"""
        while self._running:
            try:
                image_data, mime_type = await asyncio.wait_for(
                    self.video_queue.get(),
                    timeout=0.1
                )
                await session.send(
                    input=types.LiveClientRealtimeInput(
                        media_chunks=[
                            types.Blob(
                                data=image_data,
                                mime_type=mime_type,
                            )
                        ]
                    )
                )
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                break

    async def _send_text_loop(self, session):
        """텍스트 전송 루프"""
        while self._running:
            try:
                text, end_of_turn = await asyncio.wait_for(
                    self.text_queue.get(),
                    timeout=0.1
                )
                await session.send(
                    input=types.LiveClientContent(
                        turns=[
                            types.Content(
                                role="user",
                                parts=[types.Part(text=text)],
                            )
                        ],
                        turn_complete=end_of_turn,
                    )
                )
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                break


class SessionState(Enum):
    """세션 상태 (Immergo 패턴)"""
    IDLE = "idle"
    CONNECTING = "connecting"
    ACTIVE = "active"
    LISTENING = "listening"
    SPEAKING = "speaking"
    INTERRUPTED = "interrupted"
    DISCONNECTED = "disconnected"
    ERROR = "error"


class GeminiLiveSession:
    """
    Gemini Live 세션 매니저 (Immergo 패턴)

    전이중(Full-duplex) 오디오 스트리밍을 위한 세션 관리
    - 클라이언트 ↔ 백엔드 ↔ Gemini 메시지 프록시
    - 세션 라이프사이클 관리
    - 상태 추적 및 이벤트 발행
    """

    def __init__(
        self,
        session_id: str,
        model: Optional[str] = None,
        system_instruction: Optional[str] = None,
        prompt_id: Optional[str] = None,
        on_state_change: Optional[Callable[[SessionState], None]] = None,
    ):
        self.session_id = session_id
        self.prompt_id = prompt_id
        self.client = GeminiLiveClient(
            model=model,
            system_instruction=system_instruction,
            prompt_id=prompt_id,
        )
        self.state = SessionState.IDLE
        self.on_state_change = on_state_change

        # 메트릭
        self.created_at = asyncio.get_event_loop().time()
        self.audio_chunks_sent = 0
        self.audio_chunks_received = 0

    def _set_state(self, new_state: SessionState):
        """상태 변경 및 콜백 호출"""
        if self.state != new_state:
            self.state = new_state
            if self.on_state_change:
                self.on_state_change(new_state)

    async def connect(self) -> AsyncGenerator[LiveEvent, None]:
        """세션 연결 및 이벤트 스트리밍"""
        self._set_state(SessionState.CONNECTING)

        try:
            async for event in self.client.start_session():
                # 상태 업데이트
                if event.type == EventType.AUDIO:
                    self._set_state(SessionState.SPEAKING)
                    self.audio_chunks_received += 1
                elif event.type == EventType.TURN_COMPLETE:
                    self._set_state(SessionState.LISTENING)
                elif event.type == EventType.INTERRUPTED:
                    self._set_state(SessionState.INTERRUPTED)
                elif event.type == EventType.ERROR:
                    self._set_state(SessionState.ERROR)

                yield event

        except Exception as e:
            self._set_state(SessionState.ERROR)
            yield LiveEvent(type=EventType.ERROR, data=str(e))
        finally:
            self._set_state(SessionState.DISCONNECTED)

    async def send_audio(self, audio_data: bytes):
        """오디오 전송"""
        self._set_state(SessionState.ACTIVE)
        self.audio_chunks_sent += 1
        await self.client.send_audio(audio_data)

    async def send_video(self, image_data: bytes, mime_type: str = "image/jpeg"):
        """비디오 전송"""
        await self.client.send_video(image_data, mime_type)

    async def send_text(self, text: str, end_of_turn: bool = True):
        """텍스트 전송"""
        await self.client.send_text(text, end_of_turn)

    async def disconnect(self):
        """세션 종료"""
        await self.client.stop()
        self._set_state(SessionState.DISCONNECTED)

    def get_metrics(self) -> dict:
        """세션 메트릭 반환"""
        return {
            "session_id": self.session_id,
            "state": self.state.value,
            "audio_chunks_sent": self.audio_chunks_sent,
            "audio_chunks_received": self.audio_chunks_received,
            "duration": asyncio.get_event_loop().time() - self.created_at,
        }


def create_live_client(
    model: Optional[str] = None,
    system_instruction: Optional[str] = None,
    prompt_id: Optional[str] = None,
) -> GeminiLiveClient:
    """Live 클라이언트 팩토리"""
    return GeminiLiveClient(
        model=model,
        system_instruction=system_instruction,
        prompt_id=prompt_id,
    )


def create_live_session(
    session_id: str,
    model: Optional[str] = None,
    system_instruction: Optional[str] = None,
    prompt_id: Optional[str] = None,
    on_state_change: Optional[Callable[[SessionState], None]] = None,
) -> GeminiLiveSession:
    """Live 세션 팩토리 (Immergo 패턴)"""
    return GeminiLiveSession(
        session_id=session_id,
        model=model,
        system_instruction=system_instruction,
        prompt_id=prompt_id,
        on_state_change=on_state_change,
    )
