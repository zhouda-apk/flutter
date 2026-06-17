# OCR Notes App

OCR Notes App 是一個使用 Flutter 開發的 OCR 掃描筆記 App。它可以從相機拍照或相簿匯入圖片，進行裁切、影像前處理、OCR 辨識、人工校對，再透過後端 API 呼叫 Google Gemini 將文字整理成筆記。

這個專案的目標不是只有「辨識圖片文字」，而是完成一條可實際使用的筆記流程：

```text
拍照/匯入圖片
  -> 裁切
  -> 影像前處理
  -> OCR 辨識
  -> 掃描結果總覽
  -> 低信心校對
  -> AI 整理
  -> 編輯筆記
  -> 儲存與搜尋
```

## 專案狀態

目前已完成：

- Flutter OCR 筆記 App 主流程
- 相機拍照與相簿匯入
- OCR 前裁切
- 多頁掃描
- 影像前處理
- Google ML Kit OCR
- 直排中文 OCR 排序優化
- 掃描結果總覽頁
- 單頁重拍/替換
- 低信心校對模式
- AI 整理選項
- 翻譯功能選項
- 筆記編輯與儲存
- 筆記列表搜尋
- 下拉刷新
- 設定頁
- SQLite 本機資料庫
- Gemini LLM 後端串接
- Figma UI 輔助文件與 AI 呼叫報告

目前仍需強化：

- AI 呼叫 retry 機制
- 後端正式部署
- 帳號登入與雲端同步
- 匯出 Markdown / PDF
- 更完整的 OCR 區塊視覺標註
- 更細緻的 OCR 錯字偵測

## 主要功能

### 1. 掃描與圖片匯入

使用者可以：

- 使用相機拍照
- 從相簿選擇單張圖片
- 從相簿選擇多張圖片
- 對圖片先裁切再辨識
- 直接使用原圖辨識
- 在掃描結果頁替換單頁圖片
- 在校對頁替換目前頁面

相關檔案：

```text
lib/screens/camera_screen.dart
lib/screens/album_picker_screen.dart
lib/services/image_crop_service.dart
lib/screens/loading_screen.dart
lib/services/scan_pipeline_service.dart
```

### 2. 圖片裁切

目前已整合 `image_cropper`。

裁切出現位置：

- 拍照完成後
- 相簿匯入後
- 掃描結果頁替換頁面時
- 校對頁替換頁面時

目的：

- 裁掉旁邊另一頁
- 裁掉桌面背景
- 裁掉頁腳、手寫註記或非本文區域
- 提高 OCR 順序與準確度

Android 原生設定：

```text
android/app/src/main/AndroidManifest.xml
android/app/src/main/res/values/styles.xml
android/app/src/main/res/values-v35/styles.xml
```

### 3. 影像前處理

影像前處理由 `ImagePreprocessService` 負責。

相關檔案：

```text
lib/services/image_preprocess_service.dart
lib/models/image_preprocess.dart
```

處理內容包含：

- 自動修正圖片方向
- 限制最大尺寸
- 灰階處理
- 亮度與對比調整
- 銳化
- threshold
- 失敗時 fallback 使用原圖

### 4. OCR 辨識

OCR 使用 Google ML Kit Text Recognition。

相關檔案：

```text
lib/services/ocr_service.dart
lib/models/ocr_block_record.dart
```

目前功能：

- 優先使用中文辨識模型
- 中文模型不可用時 fallback 到預設 recognizer
- 儲存 OCR 區塊文字
- 儲存 bounding box
- 儲存 confidence
- 標記低信心區塊
- 清理多餘空白
- 支援直排中文排序

直排中文排序的目的，是改善書本直排文字常見的辨識順序錯亂問題。

### 5. 掃描結果總覽

掃描完成後會進入掃描結果總覽頁。

相關檔案：

```text
lib/screens/scan_review_screen.dart
```

提供：

- 總頁數
- 成功頁數
- 失敗頁數
- 低信心頁數
- 每頁 OCR 摘要
- 每頁信心資訊
- 單頁替換
- 進入校對

### 6. 校對模式

校對頁讓使用者在 AI 整理前修正 OCR 文字。

相關檔案：

```text
lib/screens/proofreading_screen.dart
```

功能：

- 多頁切換
- 顯示原圖或處理後圖片
- 編輯 OCR 文字
- 低信心內容提示
- 低信心校對模式
- 單頁替換
- AI 整理選項
- AI 結果預覽
- 套用 AI 結果到筆記編輯器

### 7. AI 筆記整理

App 不直接呼叫 Gemini，也不在 App 內保存 Gemini API key。AI 整理由獨立後端負責。

```text
Flutter App
  -> FastAPI LLM Backend
  -> Google Gemini
  -> 回傳 JSON
  -> App 套用為筆記
```

App 端相關檔案：

```text
lib/services/note_ai_service.dart
lib/services/llm_backend_client.dart
lib/config/llm_backend_settings.dart
lib/models/llm_note_result.dart
```

後端相關檔案：

```text
C:/Users/usr88/Desktop/MobileApp/ocr_llm_backend/main.py
C:/Users/usr88/Desktop/MobileApp/ocr_llm_backend/services.py
C:/Users/usr88/Desktop/MobileApp/ocr_llm_backend/config.py
C:/Users/usr88/Desktop/MobileApp/ocr_llm_backend/schemas.py
```

AI 整理支援：

- 一般筆記
- 考試複習
- 會議紀錄
- 條列摘要
- 表格整理
- 待辦事項
- 翻譯

AI 回傳欄位：

```json
{
  "title": "筆記標題",
  "summary": "摘要",
  "organized_content": "Markdown 筆記內容",
  "tags": ["標籤1", "標籤2"],
  "warnings": [],
  "model_name": "gemini-2.5-flash",
  "prompt_version": "v1.2"
}
```

目前已處理模型回傳 JSON 被截斷的問題：後端會嘗試解析完整 JSON；若 JSON 被截斷，會擷取可用欄位；若完全無法解析，會回錯誤，不會把原始 JSON 直接塞進筆記內容。

詳細 AI 呼叫流程請看：

```text
AI_CALL_REPORT.md
```

### 8. 筆記編輯與管理

相關檔案：

```text
lib/screens/dashboard_screen.dart
lib/screens/editor_screen.dart
lib/widgets/note_card.dart
lib/controllers/note_controller.dart
lib/repositories/note_repository.dart
```

功能：

- 筆記列表
- 搜尋筆記
- Grid/List 檢視切換
- 下拉刷新
- 編輯標題
- 編輯內容
- 新增標籤
- 儲存筆記
- 刪除筆記
- 已儲存筆記再次 AI 整理

### 9. 設定頁

相關檔案：

```text
lib/screens/settings_screen.dart
```

目前用途：

- 顯示 App 設定
- 顯示 OCR/AI 相關狀態
- 清理暫存圖片
- 提供後續放置模型、後端 URL、timeout 等設定的位置

## 專案架構

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
    image_crop_service.dart
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

| 目錄 | 說明 |
| --- | --- |
| `screens/` | UI 畫面 |
| `services/` | OCR、裁切、影像處理、AI 呼叫、掃描流程 |
| `repositories/` | 資料存取層 |
| `database/` | SQLite schema 與 migration |
| `models/` | 資料模型 |
| `controllers/` | UI 與資料層協調 |
| `theme/` | App 主題與顏色 |
| `widgets/` | 共用 UI 元件 |

## 資料流程

```text
Camera / Gallery
  -> ImageCropService
  -> ImagePreprocessService
  -> OcrService
  -> ScanPipelineService
  -> ScanReviewScreen
  -> ProofreadingScreen
  -> NoteAiService
  -> LlmBackendClient
  -> FastAPI Backend
  -> Google Gemini
  -> EditorScreen
  -> NoteRepository
  -> SQLite
```

## 本機資料庫

資料庫使用 SQLite。

相關檔案：

```text
lib/database/database_helper.dart
```

資料庫名稱：

```text
ocr_notes.db
```

主要資料表：

| Table | 用途 |
| --- | --- |
| `notes` | 最終保存的筆記 |
| `scan_sessions` | 一次掃描任務 |
| `scan_pages` | 每頁圖片與 OCR 結果 |
| `ocr_blocks` | OCR 區塊、信心分數與座標 |
| `llm_outputs` | AI 整理結果與錯誤紀錄 |

## 使用技術

| 技術 | 用途 |
| --- | --- |
| Flutter | App 開發 |
| Material 3 | UI |
| camera | 相機 |
| image_picker | 相簿匯入 |
| image_cropper | 圖片裁切 |
| image | 影像前處理 |
| google_mlkit_text_recognition | OCR |
| sqflite | App SQLite |
| sqflite_common_ffi | 測試環境 SQLite |
| http | 呼叫後端 API |
| crypto | input hash |
| path_provider | App 檔案路徑 |
| FastAPI | LLM 後端 |
| Google Gemini | AI 整理模型 |

## App 安裝與啟動

### 1. 安裝 Flutter 依賴

在 App 專案目錄執行：

```powershell
cd C:\Users\usr88\Desktop\MobileApp\ocr_app
flutter pub get
```

### 2. 啟動 App

```powershell
flutter run
```

### 3. 指定後端 URL 啟動

Android 模擬器連電腦本機後端：

```powershell
flutter run --dart-define=LLM_BACKEND_BASE_URL=http://10.0.2.2:5000 --dart-define=LLM_MOCK_MODE=false
```

實體手機連同一個 Wi-Fi 的電腦後端：

```powershell
flutter run --dart-define=LLM_BACKEND_BASE_URL=http://你的電腦IP:5000 --dart-define=LLM_MOCK_MODE=false
```

離線測試 UI：

```powershell
flutter run --dart-define=LLM_MOCK_MODE=true
```

## LLM 後端啟動

後端專案位置：

```text
C:\Users\usr88\Desktop\MobileApp\ocr_llm_backend
```

### 1. 建立虛擬環境

```powershell
cd C:\Users\usr88\Desktop\MobileApp\ocr_llm_backend
python -m venv venv
```

### 2. 啟用虛擬環境

```powershell
venv\Scripts\Activate.ps1
```

如果 PowerShell 顯示指令碼執行被停用，可以用：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
venv\Scripts\Activate.ps1
```

這只會影響目前 PowerShell 視窗。

### 3. 安裝依賴

```powershell
pip install -r requirements.txt
```

### 4. 設定 `.env`

可參考：

```text
C:\Users\usr88\Desktop\MobileApp\ocr_llm_backend\.env.example
```

範例：

```env
LLM_PROVIDER=gemini

GOOGLE_API_KEY=your-google-gemini-api-key-here
GOOGLE_MODEL=gemini-2.5-flash
GOOGLE_MAX_TOKENS=4096

HOST=0.0.0.0
PORT=5000
DEBUG=True
```

注意：不要把真正的 API key commit 到公開 repo。

### 5. 啟動後端

```powershell
python main.py
```

看到後端啟動後，可測試：

```text
http://127.0.0.1:5000/health
```

實體手機要連後端時，請使用電腦的區網 IP：

```text
http://你的電腦IP:5000/health
```

手機與電腦通常需要在同一個 Wi-Fi 或同一個熱點網路下。

## 後端 API

### Health Check

```http
GET /health
```

範例回應：

```json
{
  "status": "ok",
  "service": "OCR LLM Backend",
  "provider": "google",
  "model": "gemini-2.5-flash"
}
```

### AI 整理

```http
POST /v1/notes/organize
```

Request：

```json
{
  "ocr_text": "第 1 頁\nOCR 文字內容...",
  "pages": [
    {
      "page_index": 0,
      "page_number": 1,
      "text": "OCR 文字內容",
      "summary": "OCR 文字摘要",
      "average_confidence": 0.86,
      "low_confidence_count": 2
    }
  ],
  "language": "zh-TW",
  "task": "organize_note",
  "options": {
    "format": "markdown",
    "generate_tags": true,
    "organize_mode": "general_note",
    "organize_label": "一般筆記",
    "organize_instruction": "請將 OCR 內容整理成繁體中文筆記。",
    "translate_enabled": false
  },
  "client_request_id": "scan_1_123456789"
}
```

Response：

```json
{
  "title": "筆記標題",
  "summary": "摘要內容",
  "organized_content": "## 整理內容\n\n- 重點一\n- 重點二",
  "tags": ["OCR", "AI整理"],
  "warnings": [],
  "model_name": "gemini-2.5-flash",
  "prompt_version": "v1.2"
}
```

## AI 提示詞位置

App 端整理模式與快速選項：

```text
lib/screens/proofreading_screen.dart
```

已儲存筆記的預設整理提示：

```text
lib/services/note_ai_service.dart
```

後端最終 prompt 組裝：

```text
C:\Users\usr88\Desktop\MobileApp\ocr_llm_backend\services.py
```

後端會把 App 傳來的 `organize_label`、`organize_instruction`、翻譯設定與 OCR 文字組成完整 prompt，再送給 Gemini。

## 測試與驗證

### 靜態分析

```powershell
flutter analyze
```

### 單元測試

```powershell
flutter test
```

### Android debug build

```powershell
flutter build apk --debug
```

目前測試檔案：

```text
test/fixtures/scan_image_fixtures.dart
test/repositories/note_repository_test.dart
test/screens/loading_screen_test.dart
test/screens/proofreading_screen_test.dart
test/services/image_preprocess_service_test.dart
test/services/llm_backend_client_test.dart
test/services/note_ai_service_test.dart
test/services/scan_pipeline_service_test.dart
```

測試涵蓋：

- SQLite repository
- 掃描流程
- 影像前處理
- LLM backend client
- AI 結果保存
- Loading screen
- Proofreading screen AI 流程

## 常見問題

### 1. 手機連不上 API

請確認：

- 手機與電腦在同一個 Wi-Fi 或同一個熱點
- 後端使用 `HOST=0.0.0.0`
- App 的 `backendBaseUrl` 是電腦的區網 IP
- Windows 防火牆允許 port 5000
- 可以在手機瀏覽器打開 `http://電腦IP:5000/health`

### 2. PowerShell 無法執行 `run.ps1`

可在目前視窗暫時允許：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\run.ps1
```

或直接使用：

```powershell
venv\Scripts\python.exe main.py
```

### 3. AI 回傳 JSON 顯示在筆記裡

這通常是模型回傳 JSON 被截斷或格式錯誤。後端目前已補強解析邏輯，請確認後端已重新啟動。

重新啟動：

```powershell
cd C:\Users\usr88\Desktop\MobileApp\ocr_llm_backend
venv\Scripts\python.exe main.py
```

### 4. Gemini 顯示 503 或 high demand

代表模型暫時高流量。可以：

- 稍後重試
- 降低輸入文字長度
- 改用更快或更穩定的模型
- 後續加入 retry 機制

### 5. OCR 順序錯亂

可能原因：

- 圖片包含雙頁
- 文字是直排
- 拍攝角度傾斜
- 背景或手寫註記干擾

建議：

- 使用裁切功能，只保留本文區域
- 盡量拍正
- 避免一次拍到左右兩頁
- 在校對頁手動修正重要內容

## 建議展示流程

1. 開啟 App 首頁。
2. 使用相機拍一頁文件，或從相簿匯入。
3. 使用裁切功能裁掉非本文區域。
4. 等待 OCR 完成。
5. 在掃描結果總覽檢查頁面品質。
6. 進入校對頁，展示低信心校對模式。
7. 選擇 AI 整理模式，例如「考試複習」。
8. 預覽 AI 產生的標題、摘要、標籤與內容。
9. 套用到編輯器。
10. 儲存筆記。
11. 回到首頁搜尋剛剛的筆記。

## 相關文件

```text
AI_CALL_REPORT.md
report/OCR_CRASH_FIX.md
report/MLKIT_CRASH_FIX.md
report/ANR_AND_OCR_FIX.md
report/DEVELOPMENT_PLAN_LLM_IMAGE_PIPELINE.md
```

Figma 相關：

```text
figma-plugin/
```

## 後續開發建議

優先順序建議：

1. 加入 AI retry 與更清楚的錯誤訊息。
2. 將 prompt 設定集中管理。
3. 加入 OCR 區塊視覺標註。
4. 加入 Markdown / PDF 匯出。
5. 加入後端 API token。
6. 將後端部署到固定網址。
7. 加入雲端同步與帳號系統。

## License

目前尚未指定正式授權條款。若要公開此專案，建議補上 LICENSE 檔案。
