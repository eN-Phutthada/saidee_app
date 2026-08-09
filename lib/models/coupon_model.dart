import 'package:cloud_firestore/cloud_firestore.dart';

class CouponModel {
  final String id;
  final String code;
  final double discountValue;
  final double minOrderAmount;
  final bool isActive;
  final String type; // 'fixed' or 'percent'
  final Timestamp? startDate;
  final Timestamp? endDate;
  final Timestamp? createdAt;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountValue,
    this.minOrderAmount = 0.0,
    this.isActive = true,
    this.type = 'fixed',
    this.startDate,
    this.endDate,
    this.createdAt,
  });

  factory CouponModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CouponModel(
      id: documentId,
      code: map['code'] ?? '',
      discountValue: (map['discountValue'] ?? map['value'] ?? 0).toDouble(),
      minOrderAmount: (map['minOrderAmount'] ?? map['min_order'] ?? 0).toDouble(),
      isActive: map['isActive'] ?? (map['status'] == 'active'),
      type: map['type'] ?? 'fixed',
      startDate: map['startDate'] is Timestamp ? map['startDate'] : null,
      endDate: map['endDate'] is Timestamp ? map['endDate'] : null,
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'discountValue': discountValue,
      'minOrderAmount': minOrderAmount,
      'isActive': isActive,
      'type': type,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
