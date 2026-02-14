import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  String id;
  String sellerId;
  String name;
  String category; // ผู้หญิง, ผู้ชาย, เด็ก
  String type; // เสื้อ, กางเกง, รองเท้า
  double price;
  String size;
  String brand;
  String condition; // มือหนึ่ง, มือสอง
  String description;
  List<String> images;
  Timestamp createdAt;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.category,
    required this.type,
    required this.price,
    required this.size,
    required this.brand,
    required this.condition,
    required this.description,
    required this.images,
    required this.createdAt,
  });

  // แปลงข้อมูลจาก Firestore มาเป็น Object
  factory ProductModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ProductModel(
      id: documentId,
      sellerId: data['sellerId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      type: data['type'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      size: data['size'] ?? '',
      brand: data['brand'] ?? '',
      condition: data['condition'] ?? '',
      description: data['description'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // แปลง Object ไปเป็น Map เพื่อลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'name': name,
      'category': category,
      'type': type,
      'price': price,
      'size': size,
      'brand': brand,
      'condition': condition,
      'description': description,
      'images': images,
      'createdAt': createdAt,
    };
  }
}
