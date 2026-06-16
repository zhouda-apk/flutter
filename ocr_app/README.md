# OCR Notes App

OCR Notes App 是一個以 Flutter 開發的「OCR 掃描筆記」行動應用程式。專案目標是把紙本講義、白板照片、手寫/印刷資料或相簿圖片，轉換成可校對、可搜尋、可由 AI 整理的數位筆記。

這個專案不是只有單純呼叫 OCR，而是把「拍照或匯入圖片 -> 影像前處理 -> OCR 辨識 -> 人工校對 -> AI 整理 -> 編輯保存 -> 搜尋管理」串成完整流程，並使用 SQLite 保存掃描任務、頁面、OCR 區塊、AI 輸出與筆記資料。

## 專案特色

- 使用 Flutter / Material 3 建立跨平台 App UI。
- 支援相機拍照與相簿匯入圖片。
- 支援單頁與多頁掃描流程。
- 影像前處理包含旋轉校正、縮放、灰階、亮度/對比調整、銳化與 threshold。
- 使用 Google ML Kit Text Recognition 進行 OCR 文字辨識。
- 記錄 OCR block、confidence、bounding box 與低信心區塊。
- 提供校對畫面，讓使用者在 AI 整理前修正辨識結果。
- 透過後端 API 呼叫 LLM，產生標題、摘要、整理後內容、標籤與警告。
- 使用 SQLite 保存 notes、scan sessions、scan pages、OCR blocks、LLM outputs。
- 提供搜尋、格狀/列表切換、編輯、刪除與設定頁。
- 有 repository、service、screen 層級的單元測試與 widget 測試。

## 使用情境

適合下列情境：

- 學生拍攝課堂白板、講義或考前重點，整理成複習筆記。
- 上班族掃描會議白板或紙本資料，轉成會議紀錄與待辦事項。
- 自學者把書本、手寫草稿或圖片文字轉成可搜尋的筆記。
- 使用者需要保留原始 OCR 內容、人工校對版本與 AI 整理版本的追蹤資料。

## 主要流程

```text
Camera / Gallery
      |
      v
ImagePreprocessService
      |
      v
OcrService (Google ML Kit)
      |
      v
ScanReviewScreen / ProofreadingScreen
      |
      v
NoteAiService -> LLM Backend API
      |
      v
EditorScreen
      |
      v
SQLite local database
```

完整使用流程：

1. 使用者在 Dashboard 點擊新增掃描。
2. 從相機拍照或相簿選取圖片。
3. `LoadingScreen` 執行掃描 pipeline 並顯示進度。
4. `ImagePreprocessService` 產生處理後圖片。
5. `OcrService` 使用 ML Kit 進行文字辨識。
6. `ScanReviewScreen` 顯示每頁成功/失敗、低信心數量與頁面預覽。
7. `ProofreadingScreen` 讓使用者切換原圖/處理圖、修正 OCR 文字、篩選低信心內容。
8. 使用者可選擇 AI 整理模式，呼叫 LLM 後端產生筆記。
9. `EditorScreen` 編輯標題、內容、標籤與摘要。
10. `NoteRepository` 將資料寫入 SQLite。
11. 回到 Dashboard 後可搜尋、瀏覽、編輯或刪除筆記。

## 功能模組

### 1. 掃描與匯入

相關檔案：

- `lib/screens/camera_screen.dart`
- `lib/screens/album_picker_screen.dart`
- `lib/screens/loading_screen.dart`
- `lib/services/scan_pipeline_service.dart`

功能：

- 使用 `camera` 套件啟動相機。
- 使用 `image_picker` 從相簿匯入圖片。
- 支援多張圖片建立同一個 scan session。
- 掃描過程會回傳 `ScanPipelineProgress`，供 UI 顯示進度與目前階段。

### 2. 影像前處理

相關檔案：

- `lib/services/image_preprocess_service.dart`
- `lib/models/image_preprocess.dart`

功能：

- 自動修正圖片方向。
- 限制最大尺寸，避免影像過大造成效能問題。
- 根據亮度與對比自動調整影像。
- 轉為灰階並進行銳化。
- 在低對比或指定條件下套用 threshold。
- 將處理後圖片輸出到 `preprocessed` 目錄。
- 若處理失敗，會 fallback 使用原圖，避免整個流程直接中斷。

### 3. OCR 辨識

相關檔案：

- `lib/services/ocr_service.dart`
- `lib/models/ocr_block_record.dart`

功能：

- 使用 `google_mlkit_text_recognition`。
- 優先使用中文辨識模型 `TextRecognitionScript.chinese`。
- 若中文模型不可用，會 fallback 到預設 recognizer。
- 依照文字區塊座標排序，盡量符合閱讀順序。
- 清理多餘空白與空行。
- 產生：
  - OCR 完整文字
  - OCR block list
  - 平均 confidence
  - 低信心 block 數量
  - bounding box JSON
  - fragment confidence

### 4. 校對與頁面檢查

相關檔案：

- `lib/screens/scan_review_screen.dart`
- `lib/screens/proofreading_screen.dart`

功能：

- 顯示掃描頁數、成功頁數、失敗頁數與低信心頁數。
- 可針對失敗或不清楚的頁面重新拍照/重新選圖。
- 支援多頁切換。
- 可切換原始圖片與前處理圖片。
- 可篩選低信心 OCR 內容，方便人工檢查。
- AI 整理前保留人工修正步驟，避免錯誤 OCR 直接進入筆記。

### 5. AI 筆記整理

相關檔案：

- `lib/services/note_ai_service.dart`
- `lib/services/llm_backend_client.dart`
- `lib/models/llm_note_result.dart`
- `lib/config/llm_backend_settings.dart`

App 端不直接保存 LLM provider API key，而是呼叫自己的後端 API：

```text
Flutter App -> LLM Backend API -> LLM Provider
```

目前後端 API contract：

```text
POST /v1/notes/organize
```

Request 主要欄位：

- `ocr_text`
- `pages`
- `language`
- `task`
- `options`
- `client_request_id`

Response 主要欄位：

- `title`
- `summary`
- `organized_content`
- `tags`
- `warnings`
- `model_name`
- `prompt_version`

支援的 AI 整理方向包含：

- 一般筆記整理
- 考試複習筆記
- 會議紀錄
- 條列摘要
- 表格摘要
- 待辦事項萃取
- 翻譯選項

`LlmBackendClient` 會處理：

- timeout
- HTTP 4xx
- HTTP 5xx
- network error
- invalid response schema
- mock mode

### 6. 筆記編輯與管理

相關檔案：

- `lib/screens/dashboard_screen.dart`
- `lib/screens/editor_screen.dart`
- `lib/widgets/note_card.dart`
- `lib/controllers/note_controller.dart`
- `lib/repositories/note_repository.dart`

功能：

- Dashboard 顯示所有筆記。
- 支援搜尋 title、content、tags。
- 支援 grid/list 檢視切換。
- 可新增、編輯、刪除筆記。
- Editor 可編輯標題、內容與 tags。
- 已有筆記可再次呼叫 AI 重新整理。

### 7. 本機資料庫

相關檔案：

- `lib/database/database_helper.dart`
- `lib/models/note.dart`
- `lib/models/scan_session.dart`
- `lib/models/scan_page.dart`
- `lib/models/ocr_block_record.dart`
- `lib/models/llm_note_result.dart`

資料庫檔案：

```text
ocr_notes.db
```

目前 database version：

```text
3
```

資料表：

| Table | 用途 |
| --- | --- |
| `notes` | 最終保存的筆記內容、原始 OCR、tags、summary、來源類型、LLM 狀態 |
| `scan_sessions` | 一次掃描任務的狀態、來源、頁數與錯誤訊息 |
| `scan_pages` | 每頁原圖、處理後圖片、OCR 文字、confidence 與 metadata |
| `ocr_blocks` | 每頁 OCR 區塊、confidence、bounding box、低信心標記 |
| `llm_outputs` | LLM 輸出結果、prompt version、model name、input hash、warnings |

桌面測試環境使用 `sqflite_common_ffi` 初始化 SQLite FFI；Android/iOS 則使用一般 `sqflite`。

## 系統架構

```text
lib/
  config/
    llm_backend_settings.dart
  controllers/
    note_controller.dart
  database/
    database_helper.dart
  models/
    image_preprocess.dart
    llm_note_result.dart
    note.dart
    ocr_block_record.dart
    scan_page.dart
    scan_session.dart
  repositories/
    note_repository.dart
  screens/
    album_picker_screen.dart
    camera_screen.dart
    dashboard_screen.dart
    editor_screen.dart
    loading_screen.dart
    proofreading_screen.dart
    scan_review_screen.dart
    settings_screen.dart
  services/
    image_preprocess_service.dart
    image_service.dart
    llm_backend_client.dart
    note_ai_service.dart
    ocr_service.dart
    scan_pipeline_service.dart
  theme/
    app_theme.dart
  widgets/
    note_card.dart
```

分層說明：

- `screens/`：Flutter UI 畫面與使用者互動。
- `services/`：OCR、影像處理、AI 後端、掃描流程等核心邏輯。
- `repositories/`：資料存取抽象層。
- `database/`：SQLite schema、migration 與 CRUD。
- `models/`：資料模型與序列化。
- `controllers/`：畫面與 repository/service 之間的協調。
- `theme/`：App 顏色與 Material theme。

### 架構分層圖

```text
┌──────────────────────────────────────────────────────────────┐
│                          Flutter UI                          │
│ Dashboard / Camera / Loading / Review / Proofreading / Editor│
└───────────────────────────────┬──────────────────────────────┘
                                │
                                v
┌──────────────────────────────────────────────────────────────┐
│                         Controller                           │
│                     NoteController                           │
└───────────────────────────────┬──────────────────────────────┘
                                │
                                v
┌──────────────────────────────────────────────────────────────┐
│                          Services                            │
│ ImagePreprocessService / OcrService / ScanPipelineService    │
│ NoteAiService / LlmBackendClient / ImageService              │
└───────────────┬───────────────────────────────┬──────────────┘
                │                               │
                v                               v
┌──────────────────────────────┐   ┌───────────────────────────┐
│       Local Repository        │   │      LLM Backend API       │
│       NoteRepository          │   │   POST /v1/notes/organize  │
└───────────────┬──────────────┘   └──────────────┬────────────┘
                │                                 │
                v                                 v
┌──────────────────────────────┐   ┌───────────────────────────┐
│        SQLite Database        │   │        LLM Provider        │
│ notes / sessions / pages      │   │ ChatGPT or other models    │
│ ocr_blocks / llm_outputs      │   └───────────────────────────┘
└──────────────────────────────┘
```

### 掃描資料流

```text
image path
  -> ImagePreprocessRequest
  -> ImagePreprocessResult
  -> OcrResult
  -> ScanPage + OcrBlockRecord
  -> Proofreading edited text
  -> LlmOrganizeNoteRequest
  -> LlmNoteResult
  -> Note
```

每次掃描會先建立 `ScanSession`，再逐頁建立 `ScanPage`。每一頁的 OCR 區塊會存成 `OcrBlockRecord`，AI 回傳結果則存成 `LlmNoteResult`。最後使用者在 editor 保存後，才形成正式的 `Note`。

### 前端畫面責任

| 畫面 | 責任 |
| --- | --- |
| `DashboardScreen` | 筆記列表、搜尋、grid/list 切換、新增掃描入口 |
| `CameraScreen` | 相機預覽、拍照、閃光燈、相簿入口 |
| `AlbumPickerScreen` | 從相簿選取單張或多張圖片 |
| `LoadingScreen` | 執行 scan pipeline，顯示 OCR 進度 |
| `ScanReviewScreen` | 檢查每頁結果，顯示成功、失敗、低信心數量 |
| `ProofreadingScreen` | OCR 校對、低信心篩選、AI 整理選項與預覽 |
| `EditorScreen` | 編輯標題、內容、tags、summary 並保存 |
| `SettingsScreen` | 顯示 OCR/後端設定與清理暫存圖片 |

### 後端與資料庫邊界

App 端負責拍照、OCR、校對、筆記編輯與 SQLite 保存；LLM 後端只負責把 OCR 文字整理成結構化筆記。這樣設計的原因是：

- App 不需要保存 LLM provider API key。
- 後端可以統一管理 prompt、model、rate limit 與安全策略。
- App 可以在 mock mode 下不依賴後端測試 UI。
- SQLite 保留掃描過程資料，方便 debug OCR/AI 結果。

## 主要技術

| 技術 | 用途 |
| --- | --- |
| Flutter | App UI 與跨平台開發 |
| Material 3 | UI 元件與主題風格 |
| camera | 相機拍照 |
| image_picker | 相簿選圖與多圖匯入 |
| image | 影像前處理 |
| google_mlkit_text_recognition | OCR 文字辨識 |
| sqflite / sqflite_common_ffi | SQLite 本機資料庫與測試 |
| http | 呼叫 LLM 後端 API |
| crypto | 計算 LLM input hash |
| path / path_provider | 檔案路徑與 App documents 目錄 |
| flutter_test | 單元測試與 widget 測試 |

## LLM Backend 設定

預設設定在：

```text
lib/config/llm_backend_settings.dart
```

目前內容：

```dart
class LlmBackendSettings {
  // Android emulator: http://10.0.2.2:5000
  // Windows/macOS/Chrome app: http://127.0.0.1:5000
  // Physical phone: http://YOUR_COMPUTER_LAN_IP:5000
  static const backendBaseUrl = 'http://172.20.10.2:5000';

  static const mockMode = false;
  static const timeoutSeconds = 90;
}
```

常見環境：

- Android emulator 連本機後端：`http://10.0.2.2:5000`
- Windows/macOS/Chrome app 連本機後端：`http://127.0.0.1:5000`
- 實體手機連同一 Wi-Fi 電腦：`http://YOUR_COMPUTER_LAN_IP:5000`

也可以用 `--dart-define` 覆蓋：

```bash
flutter run \
  --dart-define=LLM_BACKEND_BASE_URL=https://your-backend.example.com \
  --dart-define=LLM_MOCK_MODE=false
```

若沒有後端或想離線測試 UI，可以打開 mock mode：

```bash
flutter run --dart-define=LLM_MOCK_MODE=true
```

## API 規格

目前 App 端只定義一個主要 AI API：將 OCR 文字整理成筆記。

### Endpoint

```text
POST /v1/notes/organize
```

### 呼叫位置

相關程式：

- `lib/services/llm_backend_client.dart`
- `lib/services/note_ai_service.dart`
- `lib/screens/proofreading_screen.dart`
- `lib/screens/editor_screen.dart`

呼叫流程：

```text
ProofreadingScreen / EditorScreen
  -> NoteAiService
  -> LlmBackendClient
  -> POST /v1/notes/organize
  -> LlmOrganizeNoteResult
  -> LlmNoteResult
  -> SQLite llm_outputs / EditorScreen
```

### Request JSON

```json
{
  "ocr_text": "第 1 頁\\n這裡是 OCR 後的文字內容...",
  "pages": [
    {
      "page_index": 0,
      "page_number": 1,
      "text": "這裡是第 1 頁 OCR 文字",
      "summary": "這裡是第 1 頁文字摘要",
      "average_confidence": 0.86,
      "low_confidence_count": 2
    }
  ],
  "language": "zh-TW",
  "task": "organize_note",
  "options": {
    "format": "markdown",
    "generate_tags": true,
    "organize_mode": "exam_review",
    "organize_label": "考試複習",
    "organize_instruction": "Organize the content as exam review notes with key terms, likely test points, and confusing concepts.",
    "translate_enabled": false
  },
  "client_request_id": "scan_12_1710000000000000"
}
```

### Request 欄位說明

| 欄位 | 型別 | 說明 |
| --- | --- | --- |
| `ocr_text` | string | 合併後的 OCR 文字，通常包含多頁內容 |
| `pages` | array | 每一頁的 OCR 文字與品質資訊 |
| `pages[].page_index` | number | 0-based 頁面索引 |
| `pages[].page_number` | number | 1-based 顯示頁碼 |
| `pages[].text` | string | 該頁校對後文字 |
| `pages[].summary` | string | App 端先截取的簡短頁面摘要 |
| `pages[].average_confidence` | number | 該頁 OCR 平均信心分數 |
| `pages[].low_confidence_count` | number | 該頁低信心 OCR 區塊數 |
| `language` | string | 目標語言，目前預設 `zh-TW` |
| `task` | string | 任務類型，目前為 `organize_note` |
| `options` | object | AI 整理選項 |
| `client_request_id` | string | App 端產生的 request id，方便追蹤與除錯 |

### `options.organize_mode`

目前 UI 會送出的整理模式包含：

| mode | 用途 |
| --- | --- |
| `general_note` | 一般筆記整理 |
| `exam_review` | 考試複習筆記 |
| `meeting_notes` | 會議紀錄 |
| `bullet_summary` | 條列摘要 |
| `table_summary` | 表格摘要 |
| `action_items` | 待辦事項萃取 |

若啟用翻譯，`options` 會額外帶：

```json
{
  "translate_enabled": true,
  "target_language": "英文",
  "target_language_code": "en"
}
```

### Success Response JSON

```json
{
  "title": "資料庫正規化重點整理",
  "summary": "本筆記整理資料庫正規化、主鍵、外鍵與常見考點。",
  "organized_content": "## 重點整理\\n\\n- 第一正規化要求欄位不可再分割...\\n\\n## 考試提醒\\n\\n- 注意 1NF、2NF、3NF 的差異。",
  "tags": ["資料庫", "正規化", "考試複習"],
  "warnings": ["第 1 頁有 2 個低信心 OCR 區塊，建議人工確認。"],
  "model_name": "gpt-4.1-mini",
  "prompt_version": "organize-note-v1"
}
```

### Response 欄位說明

| 欄位 | 型別 | 說明 |
| --- | --- | --- |
| `title` | string | AI 建議筆記標題 |
| `summary` | string | 短摘要 |
| `organized_content` | string | Markdown 格式整理內容 |
| `tags` | string[] | AI 建議標籤 |
| `warnings` | string[] | OCR 品質、內容不完整或模型限制提醒 |
| `model_name` | string | 後端實際使用的模型名稱 |
| `prompt_version` | string | 後端 prompt 版本 |

### 錯誤處理

`LlmBackendClient` 會把錯誤分類成下列類型：

| 類型 | 來源 | 是否可重試 |
| --- | --- | --- |
| `timeout` | 請求超過 timeout 秒數 | 是 |
| `backend4xx` | 後端回傳 HTTP 400-499 | 否，通常是 request 或授權問題 |
| `backend5xx` | 後端回傳 HTTP 500-599 | 是 |
| `invalidResponse` | 回傳 JSON 結構不符合 App 期待 | 否，需要修後端 schema |
| `cancelled` | 使用者取消或流程被中止 | 視情況 |
| `network` | 網路連線失敗 | 是 |

當 AI 整理失敗時，`NoteAiService` 會將失敗輸出寫入 `llm_outputs`，保存：

- `task_type`
- `input_hash`
- `status = failed`
- `error_message`
- `created_at`

這樣即使後端失敗，也能保留錯誤紀錄，方便 debug。

### 後端實作注意事項

後端需要保證：

- 不把 provider API key 回傳給 App。
- Response 必須符合 App 端 schema。
- `tags` 與 `warnings` 必須是 string array。
- `organized_content` 建議輸出 Markdown。
- 錯誤時應使用合理 HTTP status code。
- 可記錄 `client_request_id` 方便追蹤同一次 App 請求。

一個最小後端流程可以是：

```text
receive request
  -> validate schema
  -> build prompt from ocr_text/pages/options
  -> call LLM provider
  -> parse model output
  -> normalize title/summary/content/tags/warnings
  -> return JSON response
```

## 安裝與執行

前置需求：

- Flutter SDK
- Android Studio 或 VS Code Flutter extension
- Android emulator 或實體 Android 裝置
- 若要使用 AI 整理，需要啟動對應的 LLM backend

安裝依賴：

```bash
flutter pub get
```

執行 App：

```bash
flutter run
```

指定後端 URL 執行：

```bash
flutter run \
  --dart-define=LLM_BACKEND_BASE_URL=http://10.0.2.2:5000 \
  --dart-define=LLM_MOCK_MODE=false
```

## 測試

靜態分析：

```bash
flutter analyze
```

執行測試：

```bash
flutter test
```

目前測試涵蓋：

- SQLite migration 與 repository CRUD
- 影像前處理成功、fallback、resize 與 fixture
- scan pipeline 的多頁流程、進度與失敗處理
- LLM backend mock、timeout、4xx、5xx、invalid response
- LLM output 保存與錯誤狀態保存
- Loading screen 進度與導頁
- Proofreading screen AI 流程、取消、預覽與套用

測試檔案位於：

```text
test/
  fixtures/
  repositories/
  screens/
  services/
```

## Demo 建議流程

期末展示時可以依照下列步驟：

1. 開啟 Dashboard，展示搜尋、grid/list 切換與新增掃描入口。
2. 使用 Camera 或 Album 匯入一張文件圖片。
3. 展示 Loading OCR 進度。
4. 在 Scan Review 檢查頁面品質與低信心數量。
5. 進入 Proofreading，切換原圖/處理後圖片並修正 OCR 文字。
6. 選擇 AI 整理模式，例如「考試複習」或「條列摘要」。
7. 預覽 AI 產生的標題、摘要、tags、warnings。
8. 套用結果到 Editor。
9. 保存筆記並回到 Dashboard 搜尋剛建立的筆記。
10. 展示 Settings 中的後端 URL、timeout 與暫存圖片清理。

## 已知限制與後續改善

目前專案已完成核心 OCR 筆記流程，但仍有下列可改善項目：

- 部分 UI 顯示文字目前有編碼亂碼，建議統一修正為 UTF-8 繁體中文。
- 尚未加入登入、雲端同步與跨裝置備份。
- 尚未加入 Firebase 或正式雲端資料庫。
- OCR 品質仍受拍攝角度、模糊、光線與手寫字影響。
- AI 整理品質取決於後端模型、prompt 與 OCR 原文品質。
- LLM backend 需要另行部署與保護 provider API key。
- 尚未實作 OCR 區塊在圖片上的視覺框選標註。
- 尚未加入匯出 Markdown / PDF / 分享功能。
- 尚未加入正式觀測紀錄、crash reporting 與使用者行為分析。

## 相關文件

`report/` 目錄包含開發過程中的修復與規劃文件：

- `report/OCR_CRASH_FIX.md`
- `report/MLKIT_CRASH_FIX.md`
- `report/ANR_AND_OCR_FIX.md`
- `report/DEVELOPMENT_PLAN_LLM_IMAGE_PIPELINE.md`

期末簡報輸出位置：

```text
report/presentation/output/output.pptx
```

## 專案狀態摘要

已完成：

- Flutter OCR 掃描筆記 App 主流程
- 相機/相簿匯入
- 影像前處理
- ML Kit OCR
- 多頁 scan session
- 校對與低信心提示
- AI 整理後端串接
- SQLite 本機資料保存
- 筆記搜尋、編輯與刪除
- 多個 service/repository/screen 測試

尚待強化：

- UI 文案編碼修復
- 實機測試與 UI 細節整理
- 後端正式部署
- 帳號與雲端同步
- 匯出與分享功能
- 更完整的 OCR/AI 品質評估
