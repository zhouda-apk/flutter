import 'package:flutter/material.dart';
import 'models/menu_item.dart';
import 'widgets/menu_list.dart';
import 'widgets/cart.dart';
import 'widgets/item_detail.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '點餐 App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<MenuItem> _cart = [];

  void _addToCart(MenuItem item) {
    setState(() {
      _cart.add(item);
    });
  }

  void _removeFromCart(MenuItem item) {
    setState(() {
      _cart.remove(item);
    });
  }

  void _showItemDetail(MenuItem item, BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ItemDetailPage(item: item, onAddToCart: _addToCart),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('點餐 App'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text(_cart.length.toString()),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CartPage(cartItems: _cart, onRemove: _removeFromCart),
              ));
            },
          ),
        ],
      ),
      body: MenuList(
        items: MenuItem.sampleItems,
        onItemTap: _showItemDetail,
      ),
    );
  }
}

class CartPage extends StatelessWidget {
  final List<MenuItem> cartItems;
  final Function(MenuItem) onRemove;

  const CartPage({super.key, required this.cartItems, required this.onRemove});

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
                  subtitle: Text('NT$ ${item.price.toStringAsFixed(0)}'),
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
                content: Text('總金額：NT$ ${total.toStringAsFixed(0)}\n感謝您的購買！'),
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
          child: Text('結帳 (NT$ ${total.toStringAsFixed(0)})'),
        ),
      ),
    );
  }
}