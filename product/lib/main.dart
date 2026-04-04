import 'package:flutter/material.dart';

void main() {
  runApp(const ProductDisplayApp());
}

class ProductDisplayApp extends StatelessWidget {
  const ProductDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 隱藏 Debug 標籤
      home: Scaffold(
        backgroundColor: Colors.grey[100], // 給一個淡灰色背景
        appBar: AppBar(
          title: const Text('商品展示'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
        ),
        body: const Center(
          // Center：讓卡片在螢幕置中
          child: ProductCard(),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    // 這裡我們定義卡片的寬度，避免在平板上看起來太寬
    return Container(
      width: 320,
      // 使用 Container 製作圓角、陰影白色卡片
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        // --- 主垂直排列 (Column) ---
        mainAxisSize: MainAxisSize.min, // 高度自適應內容
        crossAxisAlignment: CrossAxisAlignment.start, // 內容全部靠左對齊
        children: [
          // 1. 商品圖片 (Image)
          // 我們用 ClipRRect 來切出圖片的上半部圓角，配合卡片形狀
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
            child: Image.asset(
              // **【重點】這裡請填寫你在第一步設定的路徑**
              'assets/product.jpg',
              height: 200, // 固定高度
              width: double.infinity, // 寬度撐滿卡片
              fit: BoxFit.cover, // BoxFit.cover：圖片會裁切並填滿區域，不變形
            ),
          ),

          // 2. 文字資訊區域 (Padded Column)
          // 使用 Padding 讓文字不要緊貼著圖片或邊緣
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 商品名稱
                const Text(
                  '極致降噪無線耳機 Pulse Pro',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8), // 間距
                
                // 商品簡述
                Text(
                  '原音重現 | 40小時續航 | 智慧偵測',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20), // 價格前的較大間距
                
                // 3. 價格與購物車按鈕區域 (Row)
                // --- 水平排列 (Row) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // 讓價格在左，按鈕在右
                  children: [
                    // 價格
                    const Text(
                      '\$8,990',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.deepOrange, // 使用顯眼的顏色標示價格
                      ),
                    ),
                    
                    // 模擬購物車按鈕 (Container + Icon)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_shopping_cart_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}