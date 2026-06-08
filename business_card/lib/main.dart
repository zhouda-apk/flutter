import 'package:flutter/material.dart';

void main() {
  runApp(const RichBusinessCardApp());
}

class RichBusinessCardApp extends StatelessWidget {
  const RichBusinessCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        // 極簡風格：淡灰色背景
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: Container(
            // --- 極簡名片設計 ---
            width: 300,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. 頭像 - 簡潔的灰色圓形
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFF0F0F0),
                  child: Icon(Icons.person, size: 45, color: Color(0xFF999999)),
                ),
                const SizedBox(height: 24),

                // 2. 姓名 - 簡潔的標題
                const Text(
                  '周承寬 (Mizuki)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),

                // 3. 職位 - 簡潔的副標題
                const Text(
                  'AI & 嵌入式系統工程師',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                
                const SizedBox(height: 20),

                // 4. 聯絡資訊 - 簡潔的排列
                _buildSimpleInfoRow('zhouchengkuan6@gmail.com'),
                const SizedBox(height: 8),
                _buildSimpleInfoRow('github.com/mizuki-cho'),
                const SizedBox(height: 8),
                _buildSimpleInfoRow('Taiwan, Changhua'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 極簡資訊列 ---
  Widget _buildSimpleInfoRow(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF555555),
        fontWeight: FontWeight.normal,
      ),
      textAlign: TextAlign.center,
    );
  }
}