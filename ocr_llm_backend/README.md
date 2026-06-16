# OCR LLM Backend

FastAPI backend for the Flutter OCR app. The Flutter app sends OCR text to this
service, and this service calls the configured LLM provider to return structured
note data.

Default provider: Google Gemini.

## Setup

```powershell
cd C:\Users\usr88\Desktop\MobileApp\ocr_llm_backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
```

Edit `.env`:

```env
LLM_PROVIDER=google
GOOGLE_API_KEY=your-google-gemini-api-key
GOOGLE_MODEL=gemini-2.5-flash
GOOGLE_MAX_TOKENS=2000
HOST=0.0.0.0
PORT=5000
DEBUG=True
```

Start the backend:

```powershell
python main.py
```

Or use the helper script:

```powershell
.\run.ps1
```

## Flutter App

The Flutter app does not need a provider API key. Keep the key only in this
backend.

```powershell
cd C:\Users\usr88\Desktop\MobileApp\ocr_app
flutter run --dart-define=LLM_BACKEND_BASE_URL=http://192.168.1.103:5000 --dart-define=LLM_MOCK_MODE=false
```

Use `http://127.0.0.1:5000` only when the Flutter app runs on the same
computer. Use your computer LAN IP, for example `http://192.168.1.103:5000`,
when testing on a physical phone.

## API

Health check:

```powershell
curl http://127.0.0.1:5000/health
```

Organize note:

```powershell
curl -X POST http://127.0.0.1:5000/v1/notes/organize `
  -H "Content-Type: application/json" `
  -d '{
    "ocr_text": "Flutter is a UI toolkit from Google. Dart is the language used by Flutter.",
    "pages": [
      {
        "page_index": 0,
        "page_number": 1,
        "text": "Flutter is a UI toolkit from Google.",
        "summary": "Flutter intro",
        "average_confidence": 0.95,
        "low_confidence_count": 0
      },
      {
        "page_index": 1,
        "page_number": 2,
        "text": "Dart is the language used by Flutter.",
        "summary": "Dart intro",
        "average_confidence": 0.92,
        "low_confidence_count": 1
      }
    ],
    "language": "zh-TW",
    "task": "organize_note",
    "options": {
      "format": "markdown",
      "generate_tags": true
    },
    "client_request_id": "test-001"
  }'
```

Response contract:

```json
{
  "title": "Flutter notes",
  "summary": "Brief organized summary.",
  "organized_content": "# Markdown note content",
  "tags": ["Flutter", "Dart"],
  "warnings": [],
  "model_name": "gemini-2.5-flash",
  "prompt_version": "v1.1"
}
```

## Provider Options

Gemini:

```env
LLM_PROVIDER=google
GOOGLE_API_KEY=your-google-gemini-api-key
GOOGLE_MODEL=gemini-2.5-flash
GOOGLE_MAX_TOKENS=2000
```

OpenAI fallback:

```env
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-your-openai-key
OPENAI_MODEL=gpt-4o
OPENAI_MAX_TOKENS=2000
```

Notes:

- The backend accepts both `LLM_PROVIDER=google` and `LLM_PROVIDER=gemini`.
- The `/v1/notes/organize` response remains compatible with the current Flutter client.
- For production, set `DEBUG=False` and restrict CORS origins in `main.py`.
