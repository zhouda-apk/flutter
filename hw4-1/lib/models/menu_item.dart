class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  static List<MenuItem> get sampleItems => [
        MenuItem(
          id: '1',
          name: '義大利麵',
          description: '傳統番茄義大利麵',
          price: 120,
           imageUrl: '/assets/images/pasta.jpg',
        ),
        MenuItem(
          id: '2',
          name: '漢堡',
          description: '牛肉漢堡配薯條',
          price: 150,
           imageUrl: '/assets/images/burger.jpg',
        ),
        MenuItem(
          id: '3',
          name: '沙拉',
          description: '新鮮蔬菜沙拉',
          price: 100,
           imageUrl: '/assets/images/salad.jpg',
        ),
        MenuItem(
          id: '4',
          name: '披薩',
          description: '義大利香腸披薩',
          price: 180,
           imageUrl: '/assets/images/pizza.jpg',
        ),
        MenuItem(
          id: '5',
          name: '飲料',
          description: '可樂或果汁',
          price: 35,
          imageUrl: '/assets/images/drink.jpg',
        ),
      ];
}