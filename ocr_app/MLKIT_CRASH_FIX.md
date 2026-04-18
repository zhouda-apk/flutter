# ML Kit 模型缺失問題 - 修復指南

## 🔴 問題原因

`ClassNotFoundException: Didn't find class "com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder"`

**根本原因**：
- Google ML Kit 的中文模型依賴未被正確包含到 APK
- 需要明確聲明 `text-recognition-chinese` 依賴

---

## ✅ 已實施的修復

### 1. 更新 Dart 依賴版本
```yaml
# pubspec.yaml
google_mlkit_text_recognition: ^0.14.0  # 從 0.13.0 升級
```

### 2. 添加完整的 ML Kit Android 依賴
```kotlin
// build.gradle.kts
dependencies {
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.0")
    implementation("com.google.mlkit:text-recognition:16.0.0")          // ← 新增
    implementation("com.google.mlkit:text-recognition-chinese:16.0.0")  // ← 新增
}
```

### 3. 添加自動降級機制 (OCR Service)
```dart
// 首先嘗試中文模型 → 失敗時自動使用通用模型
try {
    _recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
} catch (e) {
    // 自動降級到通用文字識別
    _recognizer = TextRecognizer(); // 預設語言
}
```

---

## 🚀 恢復步驟

### 步驟 1：清潔構建快取
```bash
cd c:\Users\usr88\Desktop\MobileApp\ocr_app

# 清除 Flutter 構建快取
flutter clean

# 清除 Gradle 快取
cd android
./gradlew clean
cd ..
```

### 步驟 2：再次獲取依賴
```bash
flutter pub get
```

### 步驟 3：重新構建並運行
```bash
# 開發模式
flutter run

# 或發佈模式
flutter build apk --release
```

---

## 🔧 故障診斷

### 若仍然崩潰，檢查以下項目：

**1. 檢查 APK 的大小**
```bash
flutter build apk
# 查看 build/app/outputs/apk/debug/app-debug.apk 的大小
# 應該 > 100MB（包含 ML Kit 模型）
```

**2. 查看詳細的 Gradle 依賴**
```bash
cd android
./gradlew dependencies
cd ..
# 查看是否包含 mlkit 相關依賴
```

**3. 檢查設備日誌中的 ML Kit 初始化過程**
```bash
adb logcat | grep -i "mlkit\|textrecognition\|chinesescrip"
```

**4. 檢查設備儲存空間**
```bash
adb shell df /data
# 需要至少 500MB 可用空間用於模型下載和緩存
```

---

## 📊 ML Kit 模型信息

- **中文模型大小**: ~60MB
- **首次登載時間**: 30-60 秒
- **後續使用時間**: 3-8 秒
- **緩存位置**: `/data/data/com.example.ocr_notes_app/cache/ml-kit`

---

## 🎯 預期行為

1. **首次運行 OCR**
   - 加載進度：0% → 20% (1 秒) → 50% (模型下載) → 100%
   - 如果無網絡會報錯

2. **後續 OCR**
   - 使用已快取的模型
   - 處理速度：3-8 秒

3. **故障時自動降級**
   - 若中文模型失敗，自動使用通用 Latin 識別
   - 仍可識別英文和數字

---

## 📝 日誌示例

**成功的初始化日誌**:
```
D/MLKit: Loading Chinese text recognizer model
D/MLKit: Model loaded successfully from cache
I/OCRService: Chinese model initialized
```

**失敗並自動降級的日誌**:
```
E/MLKit: Failed to load Chinese model: ...
I/OCRService: 中文模型初始化失敗：...，嘗試通用模型...
I/OCRService: Fallback to generic text recognizer
```

---

## ⚠️ 常見問題

**Q: 為什麼首次 OCR 這麼慢？**
A: ML Kit 首次使用需要從 Google 服務器下載 ~60MB 的模型，後續就會快很多。

**Q: 能否離線使用？**
A: 不行。ML Kit 首次必須連接網絡下載模型。下次就可以離線使用。

**Q: 如何確保使用中文模型？**
A: 檢查日誌輸出中是否有 "Chinese model initialized"。

---

如果執行上述步驟後仍然崩潰，請提供：
1. `adb logcat` 的完整日誌
2. 運行 `flutter doctor -v` 的輸出
3. 設備的 Android 版本和可用儲存空間
