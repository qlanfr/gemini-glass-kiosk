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


# 시스템 프롬프트 - Visual Grounding & 환각 방지
SYSTEM_PROMPT = """당신은 키오스크 사용을 도와주는 AI 어시스턴트입니다.

## 핵심 규칙
1. **Visual Grounding**: 이미지에서 실제로 보이는 정보만 응답하세요. 추측하거나 없는 정보를 만들어내지 마세요.
2. **다국어 지원**: 사용자의 언어를 감지하고 해당 언어로 응답하세요.
3. **좌표 제공**: 메뉴나 버튼을 가리킬 때 정확한 bounding box 좌표를 제공하세요.
4. **확인 요청**: 불확실할 경우 반드시 사용자에게 확인을 요청하세요.

## 응답 형식 (JSON)
{
  "detected_language": "ko-KR",  // 감지된 언어 코드
  "target_item": "메뉴명",        // 인식된 항목 (없으면 null)
  "confirmation_msg": "확인 메시지",  // 사용자 확인용
  "coordinates": {"x": 0, "y": 0, "width": 100, "height": 50},  // 좌표 (없으면 null)
  "audio_response": "음성 안내 텍스트",  // TTS로 읽을 내용
  "status": "success"  // success, error, need_clarification
}

## 언어별 에러 메시지
- 인식 실패 시: "더 가까이 비춰주세요" / "Please move closer" / "もっと近づけてください"
- 불명확할 때: "어떤 메뉴를 말씀하시는 건가요?" / "Which menu are you referring to?"

반드시 위 JSON 형식으로만 응답하세요.
"""


class GeminiService:
    """Gemini API 서비스 클래스"""

    def __init__(self):
        self.client = genai.Client(api_key=settings.google_api_key)
        self.model = settings.gemini_model

    async def process_kiosk_image(
        self,
        image_base64: str,
        user_query: Optional[str] = None,
        language_hint: Optional[str] = None,
    ) -> KioskResponse:
        """
        키오스크 이미지 분석 및 응답 생성

        Args:
            image_base64: Base64 인코딩된 이미지
            user_query: 사용자 질문/요청
            language_hint: 언어 힌트

        Returns:
            KioskResponse: 분석 결과
        """
        # 이미지 디코딩
        image_bytes = base64.b64decode(image_base64)

        # 프롬프트 구성
        user_message = user_query or "이 키오스크 화면을 분석해주세요."
        if language_hint:
            user_message += f" (언어: {language_hint})"

        # Gemini API 호출
        response = self.client.models.generate_content(
            model=self.model,
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
                system_instruction=SYSTEM_PROMPT,
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
