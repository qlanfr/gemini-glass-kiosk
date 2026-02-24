# GlassKiosk Copilot - Demo Script

## Video Requirements
- Duration: **4 minutes or less**
- English subtitles: **Required**
- Content: Real working demonstration

---

## Demo Outline (3:30)

### 1. Introduction (0:00 - 0:30)

**[Screen: App logo + title slide]**

> "GlassKiosk Copilot is an AI-powered kiosk navigation assistant that helps anyone use kiosks easily, regardless of language or digital literacy."

**Key Points:**
- Problem: Kiosks are difficult for elderly, foreigners, and people with disabilities
- Solution: Real-time AI guidance in your native language

---

### 2. App Overview (0:30 - 1:00)

**[Screen: Flutter app home screen]**

> "The app connects to our backend server powered by Gemini 3.0 Flash."

**Show:**
- Home screen with server URL input
- Connection test button
- "Start Camera" button

---

### 3. Korean Language Demo (1:00 - 1:45)

**[Screen: Camera pointed at kiosk]**

> "Let me show you how it works with a Korean speaker."

**Scenario:**
1. Point camera at fast-food kiosk menu
2. Point finger at a menu item
3. Ask: **"이거 뭐야?"** (What's this?)
4. Show AR highlight on the menu item
5. AI responds in Korean: **"베이컨 토마토 디럭스입니다. 현재 가장 인기 있는 메뉴예요!"**

**Highlight:**
- Automatic Korean language detection
- Korean TTS output
- AR bounding box overlay

---

### 4. English Language Demo (1:45 - 2:30)

**[Screen: Same kiosk, different interaction]**

> "Now let's try with an English speaker."

**Scenario:**
1. Ask: **"What's the cheapest item?"**
2. AI detects English
3. AI responds in English: **"The cheapest item is the Basic Burger at $3.99. It's highlighted on your screen."**
4. AR highlights the cheapest menu item

**Highlight:**
- Seamless language switching
- English TTS output
- Visual grounding (no hallucination)

---

### 5. Gesture Recognition (2:30 - 3:00)

**[Screen: Close-up of finger pointing]**

> "The app can also detect what you're pointing at."

**Scenario:**
1. Point at a specific button
2. Ask: **"How do I press this?"**
3. AI provides step-by-step guidance

**Highlight:**
- Finger/gesture detection
- Contextual guidance
- Clarification requests when uncertain

---

### 6. Technical Architecture (3:00 - 3:20)

**[Screen: Architecture diagram]**

> "Here's how it works under the hood."

**Show:**
- Flutter mobile app → FastAPI backend → Gemini 3.0 Flash
- WebSocket for real-time streaming
- Cloud Run deployment with GitHub Actions CI/CD

---

### 7. Conclusion (3:20 - 3:30)

**[Screen: Summary slide]**

> "GlassKiosk Copilot breaks down barriers and makes kiosks accessible to everyone. Thank you!"

**Key Takeaways:**
- Multilingual support (8+ languages)
- Real-time AI guidance
- Visual grounding prevents hallucinations
- Cloud-native architecture

---

## Shooting Checklist

### Equipment
- [ ] Smartphone with Flutter app installed
- [ ] Real kiosk (or printed kiosk screen)
- [ ] Stable camera mount/tripod
- [ ] Good lighting

### Test Before Recording
- [ ] Backend server running
- [ ] API key configured
- [ ] TTS working for Korean and English
- [ ] Camera permissions granted

### Post-Production
- [ ] Add English subtitles
- [ ] Add transitions between sections
- [ ] Include screen recordings with app UI
- [ ] Keep total duration under 4 minutes

---

## Sample Dialogues

### Korean
| User | AI Response |
|------|-------------|
| "이거 뭐야?" | "베이컨 토마토 디럭스입니다." |
| "추천해줘" | "지금 가장 인기 있는 건 치즈버거 세트예요." |
| "얼마야?" | "6,900원입니다." |

### English
| User | AI Response |
|------|-------------|
| "What's this?" | "This is the Bacon Tomato Deluxe." |
| "Recommend something" | "I recommend the Cheese Burger Set. It's our best seller." |
| "How much?" | "$6.90 for the set." |

### Japanese
| User | AI Response |
|------|-------------|
| "これは何?" | "ベーコントマトデラックスです。" |
| "おすすめは?" | "チーズバーガーセットがおすすめです。" |

---

## Fallback Responses

If recognition fails:
- Korean: "더 가까이 비춰주세요"
- English: "Please move closer"
- Japanese: "もっと近づけてください"
