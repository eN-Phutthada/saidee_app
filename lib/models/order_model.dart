import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String buyerId;
  final String sellerId;
  final List<Map<String, dynamic>> items;
  final String status;
  final double grandTotal;
  final double itemsTotal;
  final double shippingFee;
  final double discountAmount;
  final String paymentMethod;
  final Map<String, dynamic>? shippingAddress;
  final String? trackingNumber;
  final String? shippingCompany;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.items,
    required this.status,
    required this.grandTotal,
    this.itemsTotal = 0.0,
    this.shippingFee = 0.0,
    this.discountAmount = 0.0,
    this.paymentMethod = 'wallet',
    this.shippingAddress,
    this.trackingNumber,
    this.shippingCompany,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderModel(
      id: documentId,
      buyerId: map['buyerId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      status: map['status'] ?? 'pending',
      grandTotal: (map['grandTotal'] ?? map['total'] ?? 0).toDouble(),
      itemsTotal: (map['itemsTotal'] ?? 0).toDouble(),
      shippingFee: (map['shippingFee'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'wallet',
      shippingAddress: map['shippingAddress'] != null
          ? Map<String, dynamic>.from(map['shippingAddress'] as Map)
          : null,
      trackingNumber: map['trackingNumber'],
      shippingCompany: map['shippingCompany'],
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] : null,
      updatedAt: map['updatedAt'] is Timestamp ? map['updatedAt'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'buyerId': buyerId,
      'sellerId': sellerId,
      'items': items,
      'status': status,
      'grandTotal': grandTotal,
      'itemsTotal': itemsTotal,
      'shippingFee': shippingFee,
      'discountAmount': discountAmount,
      'paymentMethod': paymentMethod,
      if (shippingAddress != null) 'shippingAddress': shippingAddress,
      if (trackingNumber != null) 'trackingNumber': trackingNumber,
      if (shippingCompany != null) 'shippingCompany': shippingCompany,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}
