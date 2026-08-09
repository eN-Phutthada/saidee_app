class CartItemModel {
  final String id;
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String sellerId;
  final String image;
  final String? size;
  final String? condition;
  final String? brand;
  final double weight;

  CartItemModel({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
    required this.sellerId,
    required this.image,
    this.size,
    this.condition,
    this.brand,
    this.weight = 0.0,
  });

  factory CartItemModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CartItemModel(
      id: documentId,
      productId: map['productId'] ?? map['product_id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: (map['quantity'] ?? 1) is int
          ? (map['quantity'] ?? 1)
          : ((map['quantity'] ?? 1) as num).toInt(),
      sellerId: map['sellerId'] ?? '',
      image: map['image'] ?? (map['images'] != null && (map['images'] as List).isNotEmpty ? map['images'][0] : ''),
      size: map['size'],
      condition: map['condition'],
      brand: map['brand'],
      weight: (map['weight'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'sellerId': sellerId,
      'image': image,
      if (size != null) 'size': size,
      if (condition != null) 'condition': condition,
      if (brand != null) 'brand': brand,
      'weight': weight,
    };
  }
}
