"""
GlassKiosk Copilot - Kiosk API Router
/process-kiosk 엔드포인트 및 관련 API
"""

from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from typing import Optional
import base64

from core.schemas import KioskRequest, KioskResponse, ErrorResponse, PromptsListResponse, PromptInfo
from core.gemini import get_gemini_service
from core.prompts import list_prompts, DEFAULT_PROMPT_ID


router = APIRouter()


@router.get(
    "/prompts",
    response_model=PromptsListResponse,
    summary="사용 가능한 프롬프트 목록",
    description="선택 가능한 시스템 프롬프트 목록을 반환합니다.",
)
async def get_prompts() -> PromptsListResponse:
    """사용 가능한 프롬프트 목록 조회"""
    prompts = [PromptInfo(**p) for p in list_prompts()]
    return PromptsListResponse(
        prompts=prompts,
        default_prompt_id=DEFAULT_PROMPT_ID,
    )


@router.post(
    "/process-kiosk",
    response_model=KioskResponse,
    responses={
        400: {"model": ErrorResponse, "description": "잘못된 요청"},
        500: {"model": ErrorResponse, "description": "서버 에러"},
    },
    summary="키오스크 이미지 분석",
    description="키오스크 화면 이미지를 분석하고 사용자 질문에 응답합니다.",
)
async def process_kiosk(request: KioskRequest) -> KioskResponse:
    """
    키오스크 이미지 처리 엔드포인트

    - **image_base64**: Base64 인코딩된 키오스크 화면 이미지
    - **user_query**: 사용자 질문 (예: "이거 뭐야?", "추천해줘")
    - **language_hint**: 선호 언어 힌트 (예: "ko-KR")
    """
    try:
        gemini = get_gemini_service()
        response = await gemini.process_kiosk_image(
            image_base64=request.image_base64,
            user_query=request.user_query,
            language_hint=request.language_hint,
            prompt_id=request.prompt_id,
        )
        return response

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={
                "status": "error",
                "message": str(e),
                "audio_response": "서버 오류가 발생했습니다. 다시 시도해주세요.",
            },
        )


@router.post(
    "/process-kiosk/upload",
    response_model=KioskResponse,
    summary="키오스크 이미지 업로드 분석",
    description="이미지 파일을 직접 업로드하여 분석합니다.",
)
async def process_kiosk_upload(
    image: UploadFile = File(..., description="키오스크 화면 이미지"),
    user_query: Optional[str] = Form(None, description="사용자 질문"),
    language_hint: Optional[str] = Form(None, description="언어 힌트"),
    prompt_id: Optional[str] = Form(None, description="시스템 프롬프트 ID"),
) -> KioskResponse:
    """
    이미지 파일 업로드를 통한 키오스크 분석
    multipart/form-data 형식으로 요청
    """
    try:
        # 이미지 읽기 및 Base64 인코딩
        image_bytes = await image.read()
        image_base64 = base64.b64encode(image_bytes).decode("utf-8")

        gemini = get_gemini_service()
        response = await gemini.process_kiosk_image(
            image_base64=image_base64,
            user_query=user_query,
            language_hint=language_hint,
            prompt_id=prompt_id,
        )
        return response

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={
                "status": "error",
                "message": str(e),
                "audio_response": "이미지 처리 중 오류가 발생했습니다.",
            },
        )
