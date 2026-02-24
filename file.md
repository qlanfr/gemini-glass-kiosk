# GlassKiosk Copilot - 프로젝트 구조

## 디렉토리 구조

```
google_pj/
├── README.md                    # 프로젝트 소개 (영문)
├── claude.md                    # PRD 문서
├── file.md                      # 파일 구조 설명 (현재 파일)
│
├── backend/                     # FastAPI 백엔드
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py              # FastAPI 엔트리포인트
│   │   ├── config.py            # 환경변수, API 키 설정
│   │   ├── routers/
│   │   │   ├── __init__.py
│   │   │   └── kiosk.py         # /process-kiosk 엔드포인트
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── gemini.py        # Gemini API 연동 로직
│   │   │   ├── vision.py        # 이미지 분석, 좌표 추출
│   │   │   └── language.py      # 언어 감지, TTS 처리
│   │   └── models/
│   │       ├── __init__.py
│   │       └── schemas.py       # Pydantic 스키마 정의
│   ├── requirements.txt         # Python 의존성
│   ├── Dockerfile               # Cloud Run 배포용
│   └── .env.example             # 환경변수 템플릿
│
├── frontend/                    # Flutter 모바일 앱
│   ├── lib/
│   │   ├── main.dart            # 앱 엔트리포인트
│   │   ├── screens/
│   │   │   ├── home_screen.dart      # 메인 화면
│   │   │   └── camera_screen.dart    # 카메라 + AR 오버레이
│   │   ├── services/
│   │   │   ├── api_service.dart      # 백엔드 API 통신
│   │   │   └── tts_service.dart      # 다국어 TTS 처리
│   │   ├── widgets/
│   │   │   └── ar_overlay.dart       # AR 하이라이트 위젯
│   │   └── models/
│   │       └── kiosk_response.dart   # API 응답 모델
│   └── pubspec.yaml             # Flutter 의존성
│
├── .github/
│   └── workflows/
│       └── deploy.yml           # Cloud Run 자동 배포 (보너스 0.2점)
│
└── docs/
    ├── demo_script.md           # 데모 영상 스크립트
    └── api_spec.md              # API 명세서
```

## 개발 순서 (권장)

| 단계 | 작업 | 예상 시간 |
|------|------|----------|
| 1 | 백엔드 기본 구조 세팅 (FastAPI + Gemini 연동) | 2시간 |
| 2 | `/process-kiosk` 엔드포인트 구현 | 3시간 |
| 3 | Flutter 앱 카메라 + API 연동 | 3시간 |
| 4 | AR 오버레이 + TTS 구현 | 2시간 |
| 5 | Docker + Cloud Run 배포 | 1시간 |
| 6 | GitHub Actions CI/CD | 1시간 |
| 7 | 테스트 및 데모 영상 촬영 | 2시간 |

## 핵심 파일 설명

### Backend
| 파일 | 역할 |
|------|------|
| `main.py` | FastAPI 앱 초기화, CORS 설정 |
| `kiosk.py` | 이미지+음성 수신 → Gemini 처리 → JSON 응답 |
| `gemini.py` | Gemini 3.0 Flash API 호출 (멀티모달) |
| `vision.py` | 손가락 좌표 추출, UI 요소 매핑 |

### Frontend
| 파일 | 역할 |
|------|------|
| `camera_screen.dart` | 실시간 카메라 스트림 + 서버 전송 |
| `ar_overlay.dart` | 좌표 기반 하이라이트 박스 렌더링 |
| `tts_service.dart` | `detected_language`에 맞춘 음성 출력 |

## 시작하기

```bash
# 1. 백엔드 세팅
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# 2. 환경변수 설정
cp .env.example .env
# .env에 GOOGLE_API_KEY 추가

# 3. 서버 실행
uvicorn app.main:app --reload

# 4. Flutter 앱 실행
cd ../frontend
flutter pub get
flutter run
```
