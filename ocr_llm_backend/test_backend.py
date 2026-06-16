"""快速測試後端的簡單腳本"""

import requests
import json
from datetime import datetime


def test_health():
    """測試健康檢查端點"""
    print("=" * 60)
    print("📋 測試 1: 健康檢查")
    print("=" * 60)
    
    try:
        response = requests.get("http://127.0.0.1:5000/health", timeout=5)
        print(f"✅ 狀態碼: {response.status_code}")
        print(f"✅ 回應: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
        return True
    except Exception as e:
        print(f"❌ 錯誤: {e}")
        print("\n💡 提示: 確認後端服務已啟動: python main.py")
        return False


def test_organize_note():
    """測試筆記整理端點"""
    print("\n" + "=" * 60)
    print("📋 測試 2: 筆記整理")
    print("=" * 60)
    
    payload = {
        "ocr_text": """Flutter 是 Google 推出的跨平台 UI 框架。
Dart 是 Flutter 的程式語言，具有高效能和易上手的特點。
使用 Flutter 可以快速開發 iOS、Android、Web 和 Desktop 應用。""",
        "pages": [
            {
                "page_index": 0,
                "page_number": 1,
                "text": "Flutter 是 Google 推出的跨平台 UI 框架。",
                "summary": "介紹 Flutter",
                "average_confidence": 0.95,
                "low_confidence_count": 0,
            },
            {
                "page_index": 1,
                "page_number": 2,
                "text": "Dart 是 Flutter 的程式語言，具有高效能和易上手的特點。\n使用 Flutter 可以快速開發 iOS、Android、Web 和 Desktop 應用。",
                "summary": "Dart 語言和跨平台應用開發",
                "average_confidence": 0.92,
                "low_confidence_count": 1,
            },
        ],
        "language": "zh-TW",
        "task": "organize_note",
        "options": {"format": "markdown", "generate_tags": True},
        "client_request_id": f"test-{datetime.now().isoformat()}",
    }
    
    print(f"📝 請求:")
    print(f"  - OCR 文本長度: {len(payload['ocr_text'])} 字")
    print(f"  - 頁數: {len(payload['pages'])}")
    print(f"  - 語言: {payload['language']}")
    print(f"  - 請求 ID: {payload['client_request_id']}")
    
    try:
        response = requests.post(
            "http://127.0.0.1:5000/v1/notes/organize",
            json=payload,
            timeout=30,
        )
        
        print(f"\n✅ 狀態碼: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"\n✅ 生成結果:")
            print(f"  📌 標題: {result.get('title', 'N/A')}")
            print(f"  📝 摘要: {result.get('summary', 'N/A')[:100]}...")
            print(f"  🏷️  標籤: {', '.join(result.get('tags', []))}")
            print(f"  🤖 模型: {result.get('model_name', 'unknown')}")
            print(f"\n📄 整理內容 (前 200 字):")
            print(f"  {result.get('organized_content', '')[:200]}...")
            
            if result.get('warnings'):
                print(f"\n⚠️  警告: {', '.join(result.get('warnings', []))}")
        else:
            print(f"❌ 回應: {response.text}")
            
    except requests.Timeout:
        print(f"❌ 錯誤: 請求超時 (> 30 秒)")
        print("💡 提示: GPT API 可能需要較長時間")
    except Exception as e:
        print(f"❌ 錯誤: {e}")


def main():
    print("\n🚀 OCR LLM 後端測試工具")
    print("=" * 60)
    
    # 測試健康檢查
    if not test_health():
        return
    
    # 測試筆記整理
    test_organize_note()
    
    print("\n" + "=" * 60)
    print("✅ 測試完成！")
    print("=" * 60)


if __name__ == "__main__":
    main()
