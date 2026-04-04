import 'package:flutter/material.dart';

void main() {
  runApp(const RichBusinessCardApp());
}

class RichBusinessCardApp extends StatelessWidget {
  const RichBusinessCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 雖然顏色是固定的，但在名片內加上一點漸層背景會高級很多
    const cardGradient = LinearGradient(
      colors: [Colors.white, Color(0xFFF3F3F3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        // 給一個漂亮的深藍灰色背景
        backgroundColor: const Color(0xFF2B3D4F),
        body: Center(
          child: Container(
            // --- 名片主體樣式 (Container) ---
            width: 320, // 固定寬度，看起來更像名片
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: cardGradient, // 加上剛設定的微漸層
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              // --- 內容垂直排列 (Column) ---
              mainAxisSize: MainAxisSize.min, // 高度自適應內容
              children: [
                // 1. 頭像區域 (CircleAvatar)
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF4A90E2), // 頭像外圈顏色
                  child: CircleAvatar(
                    radius: 46,
                    // 提示：如果要使用自訂圖片，可以改用 backgroundImage: AssetImage('assets/your_avatar.jpg'),
                    // 這裡我們暫時用一個 Icon 代替圖片
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Color(0xFF2B3D4F)),
                  ),
                ),
                const SizedBox(height: 20), // 間距

                // 2. 姓名區域 (Text)
                const Text(
                  '周承寬 (Mizuki)',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3D4F),
                    letterSpacing: 1.0,
                  ),
                ),
                const Text(
                  'AI & 嵌入式系統工程師',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
                
                const SizedBox(height: 15),
                // 3. 分隔線 (Divider) - 也是很基礎好用的元件
                const Divider(color: Colors.grey, thickness: 0.5),
                const SizedBox(height: 15),

                // 4. 聯絡資訊區域 (自訂的 IconTextRow)
                // 這裡我們使用自訂的函式來重複建立「圖示+文字」的水平列，保持程式碼整潔
                _buildInfoRow(Icons.email_outlined, 'zhouchengkuan6@gmail.com'),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.code_outlined, 'github.com/mizuki-cho'),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.location_on_outlined, 'Taiwan, Changhua'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 關鍵步驟：自訂一個建立「圖示+文字」水平排列的函式 ---
  // 這是一個非常有用的重構技巧
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      // --- 水平排列 (Row) ---
      mainAxisAlignment: MainAxisAlignment.center, // 整列置中
      children: [
        // 使用 Icon 元件顯示內建圖示
        Icon(icon, size: 20, color: const Color(0xFF4A90E2)),
        const SizedBox(width: 12), // 圖示和文字之間的間距
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF2B3D4F),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}