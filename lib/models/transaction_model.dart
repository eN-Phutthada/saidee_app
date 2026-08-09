import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String type;
  final double amount;
  final String status;
  final String? slipUrl;
  final String? note;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final Timestamp? createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.status,
    this.slipUrl,
    this.note,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.createdAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TransactionModel(
      id: documentId,
      userId: map['userId'] ?? map['uid'] ?? '',
      type: map['type'] ?? 'topup',
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      slipUrl: map['slipUrl'] ?? map['slip_url'],
      note: map['note'],
      bankName: map['bankName'] ?? map['bank_name'],
      accountNumber: map['accountNumber'] ?? map['account_number'],
      accountName: map['accountName'] ?? map['account_name'],
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'amount': amount,
      'status': status,
      if (slipUrl != null) 'slipUrl': slipUrl,
      if (note != null) 'note': note,
      if (bankName != null) 'bankName': bankName,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (accountName != null) 'accountName': accountName,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
