import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  String id;
  String sellerId;
  String name;
  String category;
  String type;
  String description;
  double price;
  String size;
  String brand;
  String condition;
  double weight;
  List<String> images;
  String video;
  String status;
  Timestamp createdAt;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.category,
    required this.type,
    required this.description,
    required this.price,
    required this.size,
    required this.brand,
    required this.condition,
    required this.weight,
    required this.images,
    required this.video,
    required this.status,
    required this.createdAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ProductModel(
      id: documentId,
      sellerId: data['sellerId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      size: data['size'] ?? '',
      brand: data['brand'] ?? '',
      condition: data['condition'] ?? '',
      weight: (data['weight'] ?? 0.0).toDouble(),
      images: List<String>.from(data['images'] ?? []),
      video: data['video'] ?? '',
      status: data['status'] ?? 'active',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'name': name,
      'category': category,
      'type': type,
      'description': description,
      'price': price,
      'size': size,
      'brand': brand,
      'condition': condition,
      'weight': weight,
      'images': images,
      'video': video,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
