# GlassKiosk Copilot - API Specification

## Base URL

- **Local:** `http://localhost:8000`
- **Production:** `https://glasskiosk-copilot-xxxxx.run.app`

---

## Endpoints

### 1. Health Check

Check server status.

```
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "glasskiosk-copilot",
  "version": "1.0.0"
}
```

---

### 2. Process Kiosk Image (JSON)

Analyze a kiosk screen image with optional user query.

```
POST /api/process-kiosk
Content-Type: application/json
```

**Request Body:**
```json
{
  "image_base64": "base64_encoded_image_string",
  "user_query": "이거 뭐야?",
  "language_hint": "ko-KR"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image_base64` | string | Yes | Base64 encoded image (JPEG/PNG) |
| `user_query` | string | No | User's question or command |
| `language_hint` | string | No | Preferred language (e.g., "ko-KR", "en-US") |

**Response:**
```json
{
  "detected_language": "ko-KR",
  "target_item": "Bacon Tomato Deluxe",
  "confirmation_msg": "베이컨 토마토 디럭스 메뉴를 말씀하시는 건가요?",
  "coordinates": {
    "x": 450,
    "y": 120,
    "width": 100,
    "height": 50
  },
  "audio_response": "네, 가리키신 메뉴는 베이컨 토마토 디럭스입니다. 현재 가장 인기 있어요!",
  "status": "success"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `detected_language` | string | Detected language code |
| `target_item` | string \| null | Identified menu item name |
| `confirmation_msg` | string \| null | Confirmation message for user |
| `coordinates` | object \| null | Bounding box for AR highlight |
| `audio_response` | string | Text for TTS output |
| `status` | string | "success", "error", or "need_clarification" |

---

### 3. Process Kiosk Image (Upload)

Analyze a kiosk screen image via file upload.

```
POST /api/process-kiosk/upload
Content-Type: multipart/form-data
```

**Form Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image` | file | Yes | Image file (JPEG/PNG) |
| `user_query` | string | No | User's question |
| `language_hint` | string | No | Preferred language |

**Response:** Same as JSON endpoint.

---

### 4. WebSocket Live Streaming

Real-time bidirectional communication for continuous analysis.

```
WS /ws/live
```

**Client → Server Messages:**

1. **Image Frame**
```json
{
  "type": "image",
  "data": "base64_encoded_image",
  "mime_type": "image/jpeg"
}
```

2. **Text Message**
```json
{
  "type": "text",
  "data": "이거 뭐야?"
}
```

3. **Audio Data**
```json
{
  "type": "audio",
  "data": "base64_encoded_audio",
  "mime_type": "audio/pcm"
}
```

4. **End Session**
```json
{
  "type": "end"
}
```

**Server → Client Messages:**

1. **Connected**
```json
{
  "type": "connected",
  "message": "GlassKiosk Live API 연결됨"
}
```

2. **Response**
```json
{
  "type": "response",
  "data": {
    "detected_language": "ko-KR",
    "target_item": "...",
    "coordinates": {...},
    "audio_response": "...",
    "status": "success"
  }
}
```

3. **Turn Complete**
```json
{
  "type": "turn_complete"
}
```

4. **Error**
```json
{
  "type": "error",
  "message": "Error description"
}
```

---

## Error Responses

All error responses follow this format:

```json
{
  "status": "error",
  "message": "Error description",
  "detected_language": "en-US",
  "audio_response": "User-friendly error message for TTS"
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad Request (invalid input) |
| 422 | Validation Error |
| 429 | Rate Limit Exceeded |
| 500 | Internal Server Error |
| 504 | Gateway Timeout |

### Multilingual Error Messages

The API returns error messages in the detected language:

| Language | Example |
|----------|---------|
| Korean | "이미지를 처리할 수 없습니다. 더 가까이 비춰주세요." |
| English | "Unable to process image. Please move closer." |
| Japanese | "画像を処理できません。もっと近づけてください。" |

---

## Example Usage

### cURL - JSON Request

```bash
curl -X POST http://localhost:8000/api/process-kiosk \
  -H "Content-Type: application/json" \
  -d '{
    "image_base64": "'$(base64 -w0 kiosk.jpg)'",
    "user_query": "이거 뭐야?"
  }'
```

### cURL - File Upload

```bash
curl -X POST http://localhost:8000/api/process-kiosk/upload \
  -F "image=@kiosk.jpg" \
  -F "user_query=What is this?"
```

### Python

```python
import requests
import base64

with open("kiosk.jpg", "rb") as f:
    image_base64 = base64.b64encode(f.read()).decode()

response = requests.post(
    "http://localhost:8000/api/process-kiosk",
    json={
        "image_base64": image_base64,
        "user_query": "이거 뭐야?"
    }
)
print(response.json())
```

### WebSocket (JavaScript)

```javascript
const ws = new WebSocket("ws://localhost:8000/ws/live");

ws.onopen = () => {
  console.log("Connected");

  // Send image frame
  ws.send(JSON.stringify({
    type: "image",
    data: base64Image,
    mime_type: "image/jpeg"
  }));

  // Send question
  ws.send(JSON.stringify({
    type: "text",
    data: "이거 뭐야?"
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log(data);
};
```
