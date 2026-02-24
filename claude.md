# 👓 Project: GlassKiosk Copilot - Technical Requirements (PRD)

## 1. 프로젝트 비전 & 목표
스마트폰 카메라와 Gemini 3.0의 멀티모달 추론 능력을 결합하여 실물 키오스크 조작을 돕는 범용 UI 네비게이션 에이전트를 구축합니다. 사용자의 모국어로 실시간 음성 및 AR 가이드가 제공되는 '글로벌 디지털 가이드'를 구현하는 것이 핵심입니다.

## 2. 핵심 기술 레퍼런스 (Github Resources)
코드 에이전트는 아래 최신 SDK 및 ADK 구현 사례를 반드시 참고하여 개발해야 합니다.
- **Live Interaction Core:** [Gemini Multimodal Live API Samples](https://github.com/GoogleCloudPlatform/generative-ai/tree/main/gemini/multimodal-live-api)
- **Audio & Interrupt Logic:** [Immersive Language Learning with Live API](https://github.com/ZackAkil/immersive-language-learning-with-live-api)
- **Vision & UI Reasoning:** [Generative AI Vision Samples](https://github.com/GoogleCloudPlatform/generative-ai/tree/main/vision)
- **Cloud Infrastructure:** [Vertex AI Creative Studio (MCP)](https://github.com/GoogleCloudPlatform/vertex-ai-creative-studio/tree/main/experiments/mcp-genmedia)

## 3. 핵심 기술 스택 (Compliance)
- **Core Model:** **Gemini 3.0 Flash** (환각 억제 및 실시간 추론 최적화)
- **Backend:** Python 3.10+, FastAPI
- **AI SDK:** `google-genai` (Latest Unified SDK / ADK 기반)
- **Cloud:** Google Cloud Run (Dockerized)
- **Frontend:** Flutter (Mobile)

## 4. 기능 요구사항 (Functional Specs)
### **4.1. 실시간 언어 적응형 음성 인터페이스 (Multilingual Voice)**
- **지침:** 에이전트는 사용자의 언어를 자동 감지하고, 해당 언어로 음성 응답을 생성해야 한다. Flutter 앱은 수신된 언어 코드(`detected_language`)에 맞춰 TTS 엔진 설정을 동적으로 변경해야 한다.
- **효과:** 한국인에게는 한국어, 외국인에게는 해당 모국어로 실시간 안내를 제공하여 디지털 격차를 해소한다.

### **4.2. 지시어 기반 제스처 인식 (Deictic Interaction)**
- **로직:** 이미지 내 손가락 끝(Fingertip) 좌표를 식별하고, 키오스크 메뉴 UI(이름, 가격, 버튼)와 매핑하여 "이거 맛있어?" 등의 지시어 질문에 대응한다.

### **4.3. 인터리브 출력 (Interleaved Output)**
- **구성:** 시각적 AR 하이라이트용 좌표(`coordinates`)와 다국어 음성 안내(`audio_response`)를 단일 JSON 스트림으로 결합하여 제공한다.

## 5. 백엔드 설계 명세: `/process-kiosk` (Live API 기반)
- **Input:** ADK 기반 실시간 비디오 스트림 + 유저 오디오 스트림.
- **Output Schema:**
```json
{
  "detected_language": "ko-KR", 
  "target_item": "Bacon Tomato Deluxe",
  "confirmation_msg": "베이컨 토마토 디럭스 메뉴를 말씀하시는 건가요?",
  "coordinates": {"x": 450, "y": 120, "width": 100, "height": 50}, 
  "audio_response": "네, 가리키신 메뉴는 베이컨 토마토 디럭스입니다. 현재 가장 인기 있어요!",
  "status": "success"
}
```

## 6. 신뢰성 및 환각 방지 (Reliability & Grounding)
- **Visual Grounding:** 이미지 내 실존하는 정보(메뉴명, 가격)만 대답하도록 시스템 프롬프트로 강력히 제한한다.
- **Verification Loop:** 의도가 모호하거나 좌표 매칭이 불확실할 경우 반드시 사용자에게 되물어 확인한다.
- **Error Handling:** 인식률 저하 시 "더 가까이 비춰주세요"라고 해당 언어로 실시간 음성 피드백을 제공한다.

## 7. 제출 및 배포 요구사항 (Compliance)
- **배포 자동화:** GitHub Actions를 통한 Cloud Run 자동 배포 파이프라인 구축 (보너스 0.2점).
- **데모 영상:** 4분 이내, 영어 자막 필수, 실제 작동 모습(다국어 대응 및 제스처 인식) 촬영.
- **필수 조건:** Gemini 모델 활용, 공식 SDK/ADK 사용, 최소 하나 이상의 GCP 서비스 사용 엄수.

## 8. 프로젝트 핵심 가치 (One-liner)
> **"디지털 소외계층과 외국인을 위해, AI가 실시간으로 키오스크 사용법을 모국어로 가이드하는 배리어 프리(Barrier-free) 네비게이션 앱"**