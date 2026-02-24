# GlassKiosk Copilot

AI-powered kiosk navigation assistant using Gemini 3.0 Flash for real-time multilingual voice guidance and AR highlighting.

## Overview

GlassKiosk Copilot helps users navigate kiosk interfaces by:
- **Real-time image analysis** - Point your camera at any kiosk screen
- **Multilingual voice guidance** - Automatic language detection with TTS support (Korean, English, Japanese, Chinese, etc.)
- **AR highlighting** - Visual overlay showing detected menu items
- **Gesture recognition** - Point at items and ask "What's this?"

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  FastAPI        │────▶│  Gemini 3.0     │
│  (Mobile)       │     │  (Cloud Run)    │     │  Flash          │
│                 │◀────│                 │◀────│                 │
│  - Camera       │     │  - REST API     │     │  - Vision       │
│  - TTS          │     │  - WebSocket    │     │  - NLU          │
│  - AR Overlay   │     │  - Grounding    │     │  - Multilingual │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter 3.x |
| Backend | FastAPI (Python 3.11) |
| AI Model | Gemini 3.0 Flash |
| Cloud | Google Cloud Run |
| CI/CD | GitHub Actions |

## Features

### 1. Multilingual Voice Interface
- Automatic language detection
- TTS output in user's native language
- Supports 8+ languages

### 2. Visual Grounding
- Strict hallucination prevention
- Only responds with information visible on screen
- Asks for clarification when uncertain

### 3. Real-time Streaming
- WebSocket-based Live API
- Low-latency responses
- Continuous camera feed processing

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/api/process-kiosk` | Analyze kiosk image (JSON) |
| POST | `/api/process-kiosk/upload` | Analyze kiosk image (multipart) |
| WS | `/ws/live` | Real-time streaming |

### Response Schema

```json
{
  "detected_language": "ko-KR",
  "target_item": "Bacon Tomato Deluxe",
  "confirmation_msg": "Are you asking about the Bacon Tomato Deluxe?",
  "coordinates": {"x": 450, "y": 120, "width": 100, "height": 50},
  "audio_response": "This is the Bacon Tomato Deluxe. It's our most popular item!",
  "status": "success"
}
```

## Quick Start

### Backend

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
cp .env.example .env
# Edit .env and add your GOOGLE_API_KEY

# Run server
uvicorn main:app --reload
```

### Frontend

```bash
cd frontend

# Install dependencies
flutter pub get

# Run app
flutter run
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GOOGLE_API_KEY` | Google AI API Key | Yes |
| `GEMINI_MODEL` | Model name (default: gemini-2.0-flash) | No |
| `HOST` | Server host (default: 0.0.0.0) | No |
| `PORT` | Server port (default: 8000) | No |

## Deployment

### Cloud Run (via GitHub Actions)

#### Step 1: GCP Setup
```bash
# Enable required APIs
gcloud services enable run.googleapis.com artifactregistry.googleapis.com

# Create Artifact Registry repository
gcloud artifacts repositories create glasskiosk \
  --repository-format=docker \
  --location=asia-northeast3

# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions"

# Grant required roles
PROJECT_ID=$(gcloud config get-value project)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Download service account key
gcloud iam service-accounts keys create key.json \
  --iam-account=github-actions@$PROJECT_ID.iam.gserviceaccount.com
```

#### Step 2: GitHub Secrets
Go to **GitHub Repository → Settings → Secrets and variables → Actions**

| Secret Name | Value |
|-------------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_SA_KEY` | Contents of `key.json` (paste entire JSON) |
| `GOOGLE_API_KEY` | Your Gemini API key from [AI Studio](https://aistudio.google.com/apikey) |

#### Step 3: Deploy
Push to `main` branch → GitHub Actions auto-deploys to Cloud Run

## Project Structure

```
├── backend/
│   ├── main.py              # FastAPI app
│   ├── api/
│   │   ├── kiosk.py         # REST endpoints
│   │   └── websocket.py     # WebSocket handler
│   ├── core/
│   │   ├── config.py        # Environment config
│   │   ├── gemini.py        # Gemini API integration
│   │   ├── schemas.py       # Pydantic models
│   │   └── exceptions.py    # Error handling
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/         # UI screens
│   │   ├── services/        # API & TTS services
│   │   ├── widgets/         # AR overlay
│   │   └── providers/       # State management
│   └── pubspec.yaml
└── .github/workflows/
    └── deploy.yml           # CI/CD pipeline
```

## License

MIT License

## Acknowledgments

- Built with [Gemini 3.0 Flash](https://ai.google.dev/)
- Powered by [Google Cloud Run](https://cloud.google.com/run)
