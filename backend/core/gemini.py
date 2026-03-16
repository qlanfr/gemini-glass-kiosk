"""
GlassKiosk Copilot - Gemini Service
Google Gemini API 연동 및 멀티모달 처리
"""

import base64
import json
from typing import Optional

from google import genai
from google.genai import types

from .config import settings
from .schemas import KioskResponse, Coordinates
from .prompts import get_instruction, DEFAULT_PROMPT_ID


# 기본 시스템 프롬프트 (JSON 출력 형식 포함)
SYSTEM_PROMPT_SUFFIX = """

## 응답 형식 (반드시 JSON)
{
  "detected_language": "ko-KR",
  "target_item": "메뉴명 또는 null",
  "confirmation_msg": "사용자 확인용 메시지",
  "coordinates": {"x": 0, "y": 0, "width": 100, "height": 50},
  "audio_response": "TTS용 친근한 응답 텍스트",
  "status": "success | error | need_clarification"
}

반드시 JSON 형식으로만 응답하세요.
"""


# 레거시 호환용 기본 프롬프트
SYSTEM_PROMPT = """# 당신은 "키오(Kio)" - 친절한 키오스크 도우미입니다!

## 캐릭터
- 이름: 키오 (Kio)
- 성격: 따뜻하고 인내심 있는 친구 같은 도우미
- 말투: 친근하고 격려하는 톤 ("네~ 도와드릴게요!", "잘 하고 계세요!")

## 핵심 규칙
1. **Visual Grounding**: 이미지에 보이는 정보만! 없는 메뉴 만들기 ❌
2. **다국어**: 사용자 언어 감지 → 그 언어로 응답
3. **좌표 제공**: 메뉴/버튼의 bounding box 좌표 포함
4. **확인 요청**: 불확실하면 친절하게 되물어보기

## 응답 형식 (반드시 JSON)
{
  "detected_language": "ko-KR",
  "target_item": "메뉴명 또는 null",
  "confirmation_msg": "사용자 확인용 메시지",
  "coordinates": {"x": 0, "y": 0, "width": 100, "height": 50},
  "audio_response": "키오 캐릭터로 친근하게 말할 TTS 텍스트",
  "status": "success | error | need_clarification"
}

## audio_response 예시 (키오 말투)
- 메뉴 찾음: "아~ [메뉴명]요! 화면 오른쪽 위에 있어요, 보이시죠?"
- 확인 필요: "[메뉴명] 말씀하시는 거 맞으시죠? 맛있는 선택이에요~"
- 안 보임: "음... 조금만 더 가까이 보여주시겠어요?"
- 없는 메뉴: "아쉽지만 그 메뉴는 화면에서 안 보여요. 다른 거 찾아드릴까요?"

## 언어별 audio_response 톤
- 한국어: 친근한 반말/존댓말 혼합 ("~요", "~드릴게요")
- English: Friendly casual ("Sure thing!", "You got it!")
- 日本語: 丁寧でフレンドリー ("〜ですね！", "お手伝いします！")
- 中文: 热情友好 ("好的！", "没问题！")

반드시 JSON 형식으로만 응답하세요.
"""


class GeminiService:
    """Gemini API 서비스 클래스"""

    def __init__(self):
        self.client = genai.Client(api_key=settings.google_api_key)
        # 용도별 모델
        self.model_vision = settings.gemini_model_vision  # 이미지 분석
        self.model_audio = settings.gemini_model_audio    # 음성 입력 처리
        self.model_tts = settings.gemini_model_tts        # 음성 응답 생성

    async def process_kiosk_image(
        self,
        image_base64: str,
        user_query: Optional[str] = None,
        language_hint: Optional[str] = None,
        prompt_id: Optional[str] = None,
    ) -> KioskResponse:
        """
        키오스크 이미지 분석 및 응답 생성

        Args:
            image_base64: Base64 인코딩된 이미지
            user_query: 사용자 질문/요청
            language_hint: 언어 힌트
            prompt_id: 시스템 프롬프트 ID

        Returns:
            KioskResponse: 분석 결과
        """
        # 이미지 디코딩
        image_bytes = base64.b64decode(image_base64)

        # 프롬프트 구성
        user_message = user_query or "이 키오스크 화면을 분석해주세요."
        if language_hint:
            user_message += f" (언어: {language_hint})"

        # 시스템 프롬프트 선택 (prompt_id에 따라)
        base_instruction = get_instruction(prompt_id or DEFAULT_PROMPT_ID)
        system_instruction = base_instruction + SYSTEM_PROMPT_SUFFIX

        # Gemini API 호출 (이미지 분석용 모델 사용)
        response = self.client.models.generate_content(
            model=self.model_vision,
            contents=[
                types.Content(
                    role="user",
                    parts=[
                        types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                        types.Part.from_text(text=user_message),
                    ],
                )
            ],
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.3,  # 낮은 temperature로 일관성 확보
                response_mime_type="application/json",
            ),
        )

        # 응답 파싱
        return self._parse_response(response.text)

    def _parse_response(self, response_text: str) -> KioskResponse:
        """Gemini 응답을 KioskResponse로 파싱"""
        try:
            data = json.loads(response_text)

            # 좌표 파싱
            coordinates = None
            if data.get("coordinates"):
                coordinates = Coordinates(**data["coordinates"])

            return KioskResponse(
                detected_language=data.get("detected_language", "en-US"),
                target_item=data.get("target_item"),
                confirmation_msg=data.get("confirmation_msg"),
                coordinates=coordinates,
                audio_response=data.get("audio_response", ""),
                status=data.get("status", "success"),
            )
        except (json.JSONDecodeError, KeyError) as e:
            # 파싱 실패 시 기본 응답
            return KioskResponse(
                detected_language="en-US",
                target_item=None,
                confirmation_msg=None,
                coordinates=None,
                audio_response="I couldn't process the image. Please try again.",
                status="error",
            )


# 싱글톤 인스턴스
_gemini_service: Optional[GeminiService] = None


def get_gemini_service() -> GeminiService:
    """Gemini 서비스 인스턴스 반환"""
    global _gemini_service
    if _gemini_service is None:
        _gemini_service = GeminiService()
    return _gemini_service
