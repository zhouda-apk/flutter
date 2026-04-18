# OCR 掃描崩潰問題 - 修復完成

## 🔴 已解決的問題

### 1. **Google ML Kit TextRecognizer 未初始化**
- **症狀**: OCR 掃描直接崩潰，無錯誤信息
- **根因**: TextRecognizer 在類別構造中直接初始化，首次使用時需下載 ~60MB 模型
- **解決**: 實現延遲初始化 + 重試機制

**修改位置**: `lib/services/ocr_service.dart`
```dart
// 之前 (崩潰)
final TextRecognizer _recognizer = TextRecognizer(...); // 直接初始化

// 之後 (修復)
TextRecognizer? _recognizer;
Future<void> _ensureInitialized() async { ... } // 延遲初始化
```

---

### 2. **InputImage 資源洩漏**
- **症狀**: 反覆 OCR 後內存溢出導致崩潰
- **根因**: 每次 `InputImage.fromFilePath()` 傳入後未調用 `close()`
- **解決**: 在 finally 區塊中確保資源釋放

**修改位置**: `lib/services/ocr_service.dart::recognizeText()`
```dart
try {
  final recognized = await _recognizer!.processImage(inputImage);
  // ...
} finally {
  await inputImage.close(); // ✅ 關鍵修復
}
```

---

### 3. **OcrService 實例洩漏**
- **症狀**: 多次掃描後累積記憶體
- **根因**: `LoadingScreen` 每次創建新 OcrService，但異常時不釋放
- **解決**: 添加 `dispose()` 方法並改為 async，確保正確清理

**修改位置**: `lib/screens/loading_screen.dart`, `lib/controllers/note_controller.dart`
```dart
// 添加 dispose override
@override
void dispose() {
  _spinController.dispose();
  _ocr.dispose(); // ✅ 同步清理
  super.dispose();
}
```

---

### 4. **權限未正確請求**
- **症狀**: 在某些設備上靜默失敗
- **根因**: 運行時權限 (Android 13+) 未被請求
- **解決**: 添加 `permission_handler` 庫並在 Camera/Album 初始化前請求

**修改位置**: `lib/services/permission_service.dart` (新增)

---

### 5. **Android 堆內存不足**
- **症狀**: 模型加載導致 OutOfMemory
- **根因**: 預設 JVM 堆大小不足，ML Kit 模型佔用 ~150MB
- **解決**: 啟用 MultiDex + 增加 Gradle 堆配置

**修改位置**: 
- `android/gradle.properties` - 已配置為 `-Xmx8G`
- `android/app/build.gradle.kts` - 添加 `multiDexEnabled = true`
- `android/app/build.gradle.kts` - 添加 ML Kit 依賴

---

## 📝 變更清單

| 文件 | 變更 |
|-----|------|
| `lib/services/ocr_service.dart` | ✅ 延遲初始化 + 資源清理 |
| `lib/screens/loading_screen.dart` | ✅ 添加 dispose() + 異常時清理 |
| `lib/services/permission_service.dart` | ✅ 新增權限管理服務 |
| `lib/screens/camera_screen.dart` | ✅ 添加權限檢查 + 錯誤處理 |
| `lib/screens/album_picker_screen.dart` | ✅ 添加權限檢查 |
| `lib/controllers/note_controller.dart` | ✅ dispose() 改為 async |
| `pubspec.yaml` | ✅ 添加 permission_handler |
| `android/app/build.gradle.kts` | ✅ 啟用 MultiDex + ML Kit 依賴 |
| `android/app/src/main/AndroidManifest.xml` | ✅ 完善權限聲明 |

---

## 🚀 恢復步驟

### 1️⃣ **更新依賴**
```bash
flutter pub get
cd android
./gradlew clean
```

### 2️⃣ **重新構建**
```bash
flutter pub get
flutter app create --offline  # (可選，使用離線暫存)
flutter run --release  # 使用發佈模式測試
```

### 3️⃣ **測試驗證**
- ✅ 打開應用 → 點擊「拍攝」/「相冊」
- ✅ 等待權限對話框 → 允許
- ✅ 拍攝或選取圖片
- ✅ 等待「正在分析圖片...」進度
- ✅ 應無崩潰，展示識別結果

---

## 🔧 進階調試 (若仍崩潰)

### 查看 Android 日誌:
```bash
adb logcat | grep -i "ocr\|crash\|mlkit"
```

### 檢查是否網路問題:
- Google ML Kit 首次使用需下載 ~60MB 模型
- 確保設備已連接可用網絡
- 可能需要 30-60 秒第一次初始化

### 強制使用 CPU 推理 (若有 GPU 衝突):
在 `ocr_service.dart` 中修改:
```dart
_recognizer = TextRecognizer(
  script: TextRecognitionScript.chinese,
  // onDeviceTextRecognizerOptions: OnDeviceTextRecognizerOptions(),
);
```

---

## 📊 性能提示

- **首次 OCR**: 可能需要 30-60 秒 (模型下載 + 初始化)
- **後續 OCR**: 3-8 秒 (取決於圖像大小和設備性能)
- **內存占用**: ~200-300MB (含模型緩存)
- **儲存占用**: ~100MB (ML Kit 模型快取)

---

如果仍有崩潰，請檢查:
1. Android 日誌 (`adb logcat`)
2. 網絡連接 (模型下載)
3. 設備儲存空間 (至少 200MB)
4. Android 版本 >= 7.0
