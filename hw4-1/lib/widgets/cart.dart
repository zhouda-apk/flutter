import 'package:flutter/material.dart';
import '../models/menu_item.dart';

class Cart extends StatelessWidget {
  final List<MenuItem> cartItems;
  final Function(MenuItem) onRemove;

  const Cart({
    super.key,
    required this.cartItems,
    required this.onRemove,
  });

  double get total => cartItems.fold(0.0, (sum, item) => sum + item.price);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('購物車'),
      ),
      body: cartItems.isEmpty
          ? const Center(child: Text('購物車是空的'))
          : ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return ListTile(
                  leading: Image.asset(item.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                  title: Text(item.name),
                  subtitle: Text('NT\$ ${item.price.toStringAsFixed(0)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => onRemove(item),
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('訂單已送出'),
                content: Text('總金額：NT\$ ${total.toStringAsFixed(0)}\n感謝您的購買！'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text('確定'),
                  ),
                ],
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          child: Text('結帳 (NT\$ ${total.toStringAsFixed(0)})'),
        ),
      ),
    );
  }
}